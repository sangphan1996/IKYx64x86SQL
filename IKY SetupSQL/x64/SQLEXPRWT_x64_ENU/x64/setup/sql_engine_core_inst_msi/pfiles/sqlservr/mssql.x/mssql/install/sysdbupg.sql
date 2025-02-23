/*------------------------------------------------------------------------------

SYSDBUPG.SQL

This script upgrades the system database stored procs from the RTM level.
It is used only for system databases which are upgraded in post-RTM servicing.

The script is also run during mkmastr to produce upgraded refresh databases
for inclusion in the Express skus.

Databases which may be updated by this script:
	master
	model
	msdb

Databases not updated by this script:
	mssqlsystemresource
	distmdl
	adventureworks
	adventureworksdw
	user databases

Any changes to the following scripts are made here instead:
	U_TABLES.SQL
	PROCSYST.SQL
	XPSTAR.SQL
	INSTMSDB.SQL
	REPL_MASTER.SQL

Note:
  This script does not apply any sysmessages changes.
  Such changes are delivered via an updated SQLEVN70.RLL instead.


** Copyright (c) Microsoft Corporation.  All rights reserved.

------------------------------------------------------------------------------*/

/**************************************************************/
/* Record time of start of creates                            */
/**************************************************************/
SELECT start = getdate() INTO #sysdbupg
go

--------------------------------------------------------------------------------
--	U_TABLES.SQL
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--	PROCSYST.SQL
--------------------------------------------------------------------------------

-- Grant SELECT on Shiloh views to PUBLIC (only if they were not explicitely denied)
--
use master
go

set nocount on
set implicit_transactions off
set ansi_nulls on	-- default for osql (consistent for suites)
set quoted_identifier on	-- Force all ye devs to do this correctly!
go

-- temporary grant select to QE dmv
GRANT SELECT on sys.dm_exec_query_resource_semaphores TO PUBLIC
GRANT SELECT on sys.dm_exec_query_memory_grants TO PUBLIC
go

if NOT EXISTS (
	SELECT * FROM sys.database_permissions 
	WHERE 	class = 1 and major_id = object_id (N'master.dbo.syscacheobjects') and 
			minor_id = 0 and grantee_principal_id = 0 and type = 'SL' and state = 'D')
	GRANT SELECT ON syscacheobjects TO PUBLIC;

if NOT EXISTS (
	SELECT * FROM sys.database_permissions 
	WHERE 	class = 1 and major_id = object_id (N'master.dbo.sysperfinfo') and 
			minor_id = 0 and grantee_principal_id = 0 and type = 'SL' and state = 'D')
	GRANT SELECT ON sysperfinfo TO PUBLIC;
go


--------------------------------------------------------------------------------
--	XPSTAR.SQL
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--	INSTMSDB.SQL
--------------------------------------------------------------------------------
/*********************************************************************/
/* Create auxilary procedure to enable OBD (Off By Default component */
/*********************************************************************/
CREATE PROCEDURE #sp_enable_component     
   @comp_name     sysname, 
   @advopt_old_value    INT OUT, 
   @comp_old_value   INT OUT 
AS
   BEGIN
   SELECT @advopt_old_value=cast(value_in_use as int) from sys.configurations where name = 'show advanced options';
   SELECT @comp_old_value=cast(value_in_use as int) from sys.configurations where name = @comp_name; 
   EXEC sp_configure 'show advanced options',1;
   RECONFIGURE WITH OVERRIDE;
   EXEC sp_configure @comp_name, 1; 
   RECONFIGURE WITH OVERRIDE;
   END
go

CREATE PROCEDURE #sp_restore_component_state 
   @comp_name     sysname, 
   @advopt_old_value    INT, 
   @comp_old_value   INT 
AS
   BEGIN
   EXEC sp_configure @comp_name, @comp_old_value; 
   RECONFIGURE WITH OVERRIDE;
   EXEC sp_configure 'show advanced options',@advopt_old_value;
   RECONFIGURE WITH OVERRIDE;
   END
go

USE msdb
go

-- Change growth type to 10% for MSDB log and data files
declare @growth bigint
declare @is_percent_growth int

SET @growth = (SELECT growth FROM sys.database_files WHERE name = N'MSDBData')
SET @is_percent_growth = (SELECT is_percent_growth FROM sys.database_files WHERE name = N'MSDBData')

-- If data file grows by 256k (this is the RTM setting) change that to 10% 
IF( (@growth IS NOT NULL) AND (@growth = 32) AND 
	(@is_percent_growth IS NOT NULL) AND (@is_percent_growth = 0 ))
BEGIN
	PRINT 'Update [msdb] data file growth to 10%.'
	ALTER DATABASE [msdb] MODIFY FILE (NAME=N'MSDBData', FILEGROWTH=10%)
END


SET @growth = (SELECT growth FROM sys.database_files WHERE name = N'MSDBLog')
SET @is_percent_growth = (SELECT is_percent_growth FROM sys.database_files WHERE name = N'MSDBLog')

-- If log file grows by 256k (this is the RTM setting) change that to 10% 
IF( (@growth IS NOT NULL) AND (@growth = 32) AND 
	(@is_percent_growth IS NOT NULL) AND (@is_percent_growth = 0 ))
BEGIN
	PRINT 'Update [msdb] log file growth to 10%.'
	ALTER DATABASE [msdb] MODIFY FILE (NAME=N'MSDBLog', FILEGROWTH=10%)
END

GO
-- end 'Change growth type ...'

-- Updating the sysjobsteps.command column that was missed while upgrading Shiloh --> Yukon
IF ((SELECT max_length FROM sys.columns WHERE object_id = OBJECT_ID (N'dbo.sysjobsteps') AND name = N'command') <> -1)
BEGIN
	PRINT ''
	PRINT 'Updating sys.jobsteps.command to nvarchar(max)'  
	ALTER TABLE dbo.sysjobsteps ALTER COLUMN command NVARCHAR (MAX)
END
GO
-- end 'Update the sysjobsteps.command...


/**************************************************************/
/* drop certificate signature from Agent signed sps           */
/**************************************************************/

BEGIN TRANSACTION
declare @sp sysname
declare @exec_str nvarchar(1024)
declare ms_crs_sps cursor global for select object_name(crypts.major_id) 
   from sys.crypt_properties crypts, sys.certificates certs
   where crypts.thumbprint = certs.thumbprint
   and crypts.class = 1
   and certs.name = '##MS_AgentSigningCertificate##'
open ms_crs_sps
fetch next from ms_crs_sps into @sp
while @@fetch_status = 0
begin
   if exists(select * from sys.objects where name = @sp)
   begin
      print 'Dropping signature from: ' + @sp
      set @exec_str = N'drop signature from ' + quotename(@sp) + N' by certificate [##MS_AgentSigningCertificate##]'
      Execute(@exec_str)
      if (@@error <> 0)
      begin
         declare @err_str nvarchar(1024)
         set @err_str = 'Cannot drop signature from ' + quotename(@sp) + '. Terminating.'
         close ms_crs_sps
         deallocate ms_crs_sps
         ROLLBACK TRANSACTION
         RAISERROR(@err_str, 20, 127) WITH LOG
         return
      end
   end
   fetch next from ms_crs_sps into @sp
end
close ms_crs_sps
deallocate ms_crs_sps
COMMIT TRANSACTION
go

/**************************************************************/
/* sp_verify_subsystems                                       */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_verify_subsystems...'
go
ALTER PROCEDURE dbo.sp_verify_subsystems
   @syssubsytems_refresh_needed BIT = 0
AS
BEGIN
  SET NOCOUNT ON
   
  DECLARE @retval         INT
  DECLARE @InstRootPath nvarchar(512)
  DECLARE @ComRootPath nvarchar(512)
  DECLARE @DtsRootPath nvarchar(512)
  DECLARE @DTExec nvarchar(512)
  DECLARE @DTExecExists INT

  IF ( (@syssubsytems_refresh_needed=1) OR (NOT EXISTS(select * from syssubsystems)) )
  BEGIN
     EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\Setup', N'SQLPath', @InstRootPath OUTPUT
     IF @InstRootPath IS NULL
     BEGIN
       RAISERROR(14658, -1, -1) WITH LOG
       RETURN (1)
     END
     SELECT @InstRootPath = @InstRootPath + N'\binn\'

     EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\Microsoft Sql Server\90', N'VerSpecificRootDir', @ComRootPath OUTPUT
     IF @ComRootPath IS NULL
     BEGIN
       RAISERROR(14659, -1, -1) WITH LOG
       RETURN(1)
     END

     EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSDTS\Setup\DTSPath', N'', @DtsRootPath OUTPUT, N'no_output'
     IF (@DtsRootPath IS NOT NULL)
     BEGIN
       SELECT @DtsRootPath  = @DtsRootPath  + N'Binn\'
       SELECT @DTExec = @DtsRootPath + N'DTExec.exe'
       CREATE TABLE #t (file_exists int, is_directory int, parent_directory_exists int)
	   INSERT #t EXEC xp_fileexist @DTExec
       SELECT TOP 1 @DTExecExists=file_exists from #t
       DROP TABLE #t
       IF ((@DTExecExists IS NULL) OR (@DTExecExists = 0))
         SET @DtsRootPath = NULL
     END

     SELECT @ComRootPath  = @ComRootPath  + N'COM\'

     -- Procedure must start its own transaction if we don't have one already.
     DECLARE @TranCounter INT;
     SET @TranCounter = @@TRANCOUNT;
     IF @TranCounter = 0
     BEGIN
        BEGIN TRANSACTION;
     END

     -- Obtain processor count to determine maximum number of threads per subsystem
     DECLARE @xp_results TABLE
     (
     id              INT           NOT NULL,
     name            NVARCHAR(30)  COLLATE database_default NOT NULL,
     internal_value  INT           NULL,
     character_value NVARCHAR(212) COLLATE database_default NULL
     )
     INSERT INTO @xp_results
     EXECUTE master.dbo.xp_msver

     DECLARE @processor_count INT
     SELECT @processor_count = internal_value from @xp_results where id=16 -- ProcessorCount

     -- Modify database.
     BEGIN TRY

       --create subsystems
       --TSQL subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'TSQL')
       INSERT syssubsystems
       VALUES
       (
          1, N'TSQL',14556, FORMATMESSAGE(14557), FORMATMESSAGE(14557), FORMATMESSAGE(14557), FORMATMESSAGE(14557), FORMATMESSAGE(14557), 20 * @processor_count
       )
       --ActiveScripting subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'ActiveScripting')
       INSERT syssubsystems
       VALUES
       (
          2, N'ActiveScripting',  14555, @InstRootPath + N'SQLATXSS90.DLL',NULL,N'ActiveScriptStart',N'ActiveScriptEvent',N'ActiveScriptStop', 10 * @processor_count
       )

       --CmdExec subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'CmdExec')
       INSERT syssubsystems
       VALUES
       (
          3, N'CmdExec', 14550, @InstRootPath + N'SQLCMDSS90.DLL',NULL,N'CmdExecStart',N'CmdEvent',N'CmdExecStop', 10 * @processor_count
       )

       --Snapshot subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'Snapshot')
       INSERT syssubsystems
       VALUES
       (
          4, N'Snapshot',   14551, @InstRootPath + N'SQLREPSS90.DLL', @ComRootPath + N'SNAPSHOT.EXE', N'ReplStart',N'ReplEvent',N'ReplStop',100 * @processor_count
       )

       --LogReader subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'LogReader')
       INSERT syssubsystems
       VALUES
       (
          5, N'LogReader',  14552, @InstRootPath + N'SQLREPSS90.DLL', @ComRootPath + N'logread.exe',N'ReplStart',N'ReplEvent',N'ReplStop',25 * @processor_count
       )

       --Distribution subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'Distribution')
       INSERT syssubsystems
       VALUES
       (
          6, N'Distribution',  14553, @InstRootPath + N'SQLREPSS90.DLL', @ComRootPath + N'DISTRIB.EXE',N'ReplStart',N'ReplEvent',N'ReplStop',100 * @processor_count
       )

       --Merge subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'Merge')
       INSERT syssubsystems
       VALUES
       (
          7, N'Merge',   14554, @InstRootPath + N'SQLREPSS90.DLL',@ComRootPath + N'REPLMERG.EXE',N'ReplStart',N'ReplEvent',N'ReplStop',100 * @processor_count
       )

       --QueueReader subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'QueueReader')
       INSERT syssubsystems
       VALUES
       (
          8, N'QueueReader',   14581, @InstRootPath + N'sqlrepss90.dll',@ComRootPath + N'qrdrsvc.exe',N'ReplStart',N'ReplEvent',N'ReplStop',100 * @processor_count
       )

       --ANALYSISQUERY subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'ANALYSISQUERY')
       INSERT syssubsystems
       VALUES
       (
          9, N'ANALYSISQUERY', 14513, @InstRootPath + N'SQLOLAPSS90.DLL',NULL,N'OlapStart',N'OlapQueryEvent',N'OlapStop',100 * @processor_count
       )

       --ANALYSISCOMMAND subsystem
       IF NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'ANALYSISCOMMAND')
       INSERT syssubsystems
       VALUES
       (
          10, N'ANALYSISCOMMAND', 14514, @InstRootPath + N'SQLOLAPSS90.DLL',NULL,N'OlapStart',N'OlapCommandEvent',N'OlapStop',100 * @processor_count
       )

       IF(@DtsRootPath IS NOT NULL)
       BEGIN
          --DTS subsystem
          IF (NOT EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'SSIS') )
             INSERT syssubsystems
             VALUES
             (
                11, N'SSIS', 14538, @InstRootPath + N'SQLDTSSS90.DLL',@DtsRootPath + N'DTExec.exe',N'DtsStart',N'DtsEvent',N'DtsStop',100 * @processor_count
             )
          ELSE
             UPDATE syssubsystems SET agent_exe = @DtsRootPath + N'DTExec.exe' WHERE subsystem = N'SSIS'
       END
       ELSE
       BEGIN
          IF EXISTS(SELECT * FROM syssubsystems WHERE subsystem = N'SSIS')
            DELETE FROM syssubsystems WHERE subsystem = N'SSIS' 
       END

   END TRY
   BEGIN CATCH

       DECLARE @ErrorMessage NVARCHAR(400)
       DECLARE @ErrorSeverity INT
       DECLARE @ErrorState INT

       SELECT @ErrorMessage = ERROR_MESSAGE()
       SELECT @ErrorSeverity = ERROR_SEVERITY()
       SELECT @ErrorState = ERROR_STATE()

       -- Roll back the transaction that we started if we are not nested
       IF @TranCounter = 0
       BEGIN
         ROLLBACK TRANSACTION;
       END
       -- if we are nested inside another transaction just raise the 
       -- error and let the outer transaction do the rollback
       RAISERROR (@ErrorMessage, -- Message text.
                   @ErrorSeverity, -- Severity.
                   @ErrorState -- State.
                   )
       RETURN (1)                  
     END CATCH
  END --(NOT EXISTS(select * from syssubsystems))
  
  -- commit the transaction we started
  IF @TranCounter = 0
  BEGIN
    COMMIT TRANSACTION;
  END
  
  RETURN(0) -- Success
END
go

/**************************************************************/
/* SP_VERIFY_SCHEDULE                                         */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_verify_schedule...'
go
ALTER PROCEDURE sp_verify_schedule
  @schedule_id            INT,
  @name                   sysname,
  @enabled                TINYINT,
  @freq_type              INT,          
  @freq_interval          INT OUTPUT,   -- Output because we may set it to 0 if Frequency Type is one-time or auto-start
  @freq_subday_type       INT OUTPUT,   -- As above
  @freq_subday_interval   INT OUTPUT,   -- As above
  @freq_relative_interval INT OUTPUT,   -- As above
  @freq_recurrence_factor INT OUTPUT,   -- As above
  @active_start_date      INT OUTPUT,
  @active_start_time      INT OUTPUT,
  @active_end_date        INT OUTPUT,
  @active_end_time        INT OUTPUT,
  @owner_sid              VARBINARY(85) --Must be a valid sid. Will fail if this is NULL
AS
BEGIN
  DECLARE @return_code             INT
  DECLARE @res_valid_range         NVARCHAR(100)
  DECLARE @reason                  NVARCHAR(200)
  DECLARE @isAdmin                 INT
  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @name = LTRIM(RTRIM(@name))

  -- Make sure that NULL input/output parameters - if NULL - are initialized to 0
  SELECT @freq_interval          = ISNULL(@freq_interval, 0)
  SELECT @freq_subday_type       = ISNULL(@freq_subday_type, 0)
  SELECT @freq_subday_interval   = ISNULL(@freq_subday_interval, 0)
  SELECT @freq_relative_interval = ISNULL(@freq_relative_interval, 0)
  SELECT @freq_recurrence_factor = ISNULL(@freq_recurrence_factor, 0)
  SELECT @active_start_date      = ISNULL(@active_start_date, 0)
  SELECT @active_start_time      = ISNULL(@active_start_time, 0)
  SELECT @active_end_date        = ISNULL(@active_end_date, 0)
  SELECT @active_end_time        = ISNULL(@active_end_time, 0)


  -- Check owner 
  IF(ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 1)
    SELECT @isAdmin = 1
  ELSE
    SELECT @isAdmin = 0


  -- If a non-sa is [illegally] trying to create a schedule for another user then raise an error
  IF ((@isAdmin <> 1) AND 
      (ISNULL(IS_MEMBER('SQLAgentOperatorRole'),0) <> 1 AND @schedule_id IS NULL) AND
      (@owner_sid <> SUSER_SID()))
  BEGIN
     RAISERROR(14366, -1, -1)
     RETURN(1) -- Failure
  END


  -- Now just check that the login id is valid (ie. it exists and isn't an NT group)
  IF (@owner_sid <> 0x010100000000000512000000) AND -- NT AUTHORITY\SYSTEM sid
     (@owner_sid <> 0x010100000000000514000000)     -- NT AUTHORITY\NETWORK SERVICE sid
  BEGIN
     IF (@owner_sid IS NULL) OR (EXISTS (SELECT *
                                      FROM master.dbo.syslogins
                                      WHERE (sid = @owner_sid)
                                      AND (isntgroup <> 0)))
     BEGIN
       -- NOTE: In the following message we quote @owner_login_name instead of @owner_sid
       --       since this is the parameter the user passed to the calling SP (ie. either
       --       sp_add_schedule, sp_add_job and sp_update_job)
       SELECT @res_valid_range = FORMATMESSAGE(14203)
       RAISERROR(14234, -1, -1, '@owner_login_name', @res_valid_range)
       RETURN(1) -- Failure
     END
  END
  
  -- Verify name (we disallow schedules called 'ALL' since this has special meaning in sp_delete_jobschedules)
  IF (UPPER(@name collate SQL_Latin1_General_CP1_CS_AS) = N'ALL')
  BEGIN
    RAISERROR(14200, -1, -1, '@name')
    RETURN(1) -- Failure
  END

  -- Verify enabled state
  IF (@enabled <> 0) AND (@enabled <> 1)
  BEGIN
    RAISERROR(14266, -1, -1, '@enabled', '0, 1')
    RETURN(1) -- Failure
  END

  -- Verify frequency type
  IF (@freq_type = 0x2) -- OnDemand is no longer supported
  BEGIN
    RAISERROR(14295, -1, -1)
    RETURN(1) -- Failure
  END
  IF (@freq_type NOT IN (0x1, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80))
  BEGIN
    RAISERROR(14266, -1, -1, '@freq_type', '0x1, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80')
    RETURN(1) -- Failure
  END

  -- Verify frequency sub-day type
  IF (@freq_subday_type <> 0) AND (@freq_subday_type NOT IN (0x1, 0x2, 0x4, 0x8))
  BEGIN
    RAISERROR(14266, -1, -1, '@freq_subday_type', '0x1, 0x2, 0x4, 0x8')
    RETURN(1) -- Failure
  END

  -- Default active start/end date/times (if not supplied, or supplied as NULLs or 0)
  IF (@active_start_date = 0)
    SELECT @active_start_date = DATEPART(yy, GETDATE()) * 10000 +
                                DATEPART(mm, GETDATE()) * 100 +
                                DATEPART(dd, GETDATE()) -- This is an ISO format: "yyyymmdd"
  IF (@active_end_date = 0)
    SELECT @active_end_date = 99991231  -- December 31st 9999
  IF (@active_start_time = 0)
    SELECT @active_start_time = 000000  -- 12:00:00 am
  IF (@active_end_time = 0)
    SELECT @active_end_time = 235959    -- 11:59:59 pm

  -- Verify active start/end dates
  IF (@active_end_date = 0)
    SELECT @active_end_date = 99991231

  EXECUTE @return_code = sp_verify_job_date @active_end_date, '@active_end_date'
  IF (@return_code <> 0)
    RETURN(1) -- Failure

  EXECUTE @return_code = sp_verify_job_date @active_start_date, '@active_start_date'
  IF (@return_code <> 0)
    RETURN(1) -- Failure

  IF (@active_end_date < @active_start_date)
  BEGIN
    RAISERROR(14288, -1, -1, '@active_end_date', '@active_start_date')
    RETURN(1) -- Failure
  END

  EXECUTE @return_code = sp_verify_job_time @active_end_time, '@active_end_time'
  IF (@return_code <> 0)
    RETURN(1) -- Failure

  EXECUTE @return_code = sp_verify_job_time @active_start_time, '@active_start_time'
  IF (@return_code <> 0)
    RETURN(1) -- Failure

  -- NOTE: It's valid for active_end_time to be less than active_start_time since in this
  --       case we assume that the user wants the active time zone to span midnight.
  --       But it's not valid for active_start_date and active_end_date to be the same for recurring sec/hour/minute schedules

  IF (@active_start_time = @active_end_time and (@freq_subday_type in (0x2, 0x4, 0x8)))
  BEGIN
    SELECT @res_valid_range = FORMATMESSAGE(14202)
    RAISERROR(14266, -1, -1, '@active_end_time', @res_valid_range)
    RETURN(1) -- Failure
  END

  -- NOTE: The rest of this procedure is a SQL implementation of VerifySchedule in job.c

  IF ((@freq_type = 0x1) OR  -- FREQTYPE_ONETIME
      (@freq_type = 0x40) OR -- FREQTYPE_AUTOSTART
      (@freq_type = 0x80))   -- FREQTYPE_ONIDLE
  BEGIN
    -- Set standard defaults for non-required parameters
    SELECT @freq_interval          = 0
    SELECT @freq_subday_type       = 0
    SELECT @freq_subday_interval   = 0
    SELECT @freq_relative_interval = 0
    SELECT @freq_recurrence_factor = 0

    -- Check that a one-time schedule isn't already in the past
    -- Bug 442883: let the creation of the one-time schedule succeed but leave a disabled schedule
    /*
    IF (@freq_type = 0x1) -- FREQTYPE_ONETIME
    BEGIN
      DECLARE @current_date INT
      DECLARE @current_time INT

      -- This is an ISO format: "yyyymmdd"
      SELECT @current_date = CONVERT(INT, CONVERT(VARCHAR, GETDATE(), 112))
      SELECT @current_time = (DATEPART(hh, GETDATE()) * 10000) + (DATEPART(mi, GETDATE()) * 100) + DATEPART(ss, GETDATE())
      IF (@active_start_date < @current_date) OR ((@active_start_date = @current_date) AND (@active_start_time <= @current_time))
      BEGIN
        SELECT @res_valid_range = '> ' + CONVERT(VARCHAR, @current_date) + ' / ' + CONVERT(VARCHAR, @current_time)
        SELECT @reason = '@active_start_date = ' + CONVERT(VARCHAR, @active_start_date) + ' / @active_start_time = ' + CONVERT(VARCHAR, @active_start_time)
        RAISERROR(14266, -1, -1, @reason, @res_valid_range)
        RETURN(1) -- Failure
      END
    END
    */

    GOTO ExitProc
  END

  -- Safety net: If the sub-day-type is 0 (and we know that the schedule is not a one-time or
  --             auto-start) then set it to 1 (FREQSUBTYPE_ONCE).  If the user wanted something
  --             other than ONCE then they should have explicitly set @freq_subday_type.
  IF (@freq_subday_type = 0)
    SELECT @freq_subday_type = 0x1 -- FREQSUBTYPE_ONCE

  IF ((@freq_subday_type <> 0x1) AND  -- FREQSUBTYPE_ONCE   (see qsched.h)
      (@freq_subday_type <> 0x2) AND  -- FREQSUBTYPE_SECOND (see qsched.h)
      (@freq_subday_type <> 0x4) AND  -- FREQSUBTYPE_MINUTE (see qsched.h)
      (@freq_subday_type <> 0x8))     -- FREQSUBTYPE_HOUR   (see qsched.h)
  BEGIN
    SELECT @reason = FORMATMESSAGE(14266, '@freq_subday_type', '0x1, 0x2, 0x4, 0x8')
    RAISERROR(14278, -1, -1, @reason)
    RETURN(1) -- Failure
  END
  IF ((@freq_subday_type <> 0x1) AND (@freq_subday_interval < 1))
     OR
     ((@freq_subday_type = 0x2) AND (@freq_subday_interval < 10))
  BEGIN
    SELECT @reason = FORMATMESSAGE(14200, '@freq_subday_interval')
    RAISERROR(14278, -1, -1, @reason)
    RETURN(1) -- Failure
  END

  IF (@freq_type = 0x4)      -- FREQTYPE_DAILY
  BEGIN
    SELECT @freq_recurrence_factor = 0
    IF (@freq_interval < 1)
    BEGIN
      SELECT @reason = FORMATMESSAGE(14572)
      RAISERROR(14278, -1, -1, @reason)
      RETURN(1) -- Failure
    END
  END

  IF (@freq_type = 0x8)      -- FREQTYPE_WEEKLY
  BEGIN
    IF (@freq_interval < 1)   OR
       (@freq_interval > 127) -- (2^7)-1 [freq_interval is a bitmap (Sun=1..Sat=64)]
    BEGIN
      SELECT @reason = FORMATMESSAGE(14573)
      RAISERROR(14278, -1, -1, @reason)
      RETURN(1) -- Failure
    END
  END

  IF (@freq_type = 0x10)    -- FREQTYPE_MONTHLY
  BEGIN
    IF (@freq_interval < 1)  OR
       (@freq_interval > 31)
    BEGIN
      SELECT @reason = FORMATMESSAGE(14574)
      RAISERROR(14278, -1, -1, @reason)
      RETURN(1) -- Failure
    END
  END

  IF (@freq_type = 0x20)     -- FREQTYPE_MONTHLYRELATIVE
  BEGIN
    IF (@freq_relative_interval <> 0x01) AND  -- RELINT_1ST
       (@freq_relative_interval <> 0x02) AND  -- RELINT_2ND
       (@freq_relative_interval <> 0x04) AND  -- RELINT_3RD
       (@freq_relative_interval <> 0x08) AND  -- RELINT_4TH
       (@freq_relative_interval <> 0x10)      -- RELINT_LAST
    BEGIN
      SELECT @reason = FORMATMESSAGE(14575)
      RAISERROR(14278, -1, -1, @reason)
      RETURN(1) -- Failure
    END
  END

  IF (@freq_type = 0x20)     -- FREQTYPE_MONTHLYRELATIVE
  BEGIN
    IF (@freq_interval <> 01) AND -- RELATIVE_SUN
       (@freq_interval <> 02) AND -- RELATIVE_MON
       (@freq_interval <> 03) AND -- RELATIVE_TUE
       (@freq_interval <> 04) AND -- RELATIVE_WED
       (@freq_interval <> 05) AND -- RELATIVE_THU
       (@freq_interval <> 06) AND -- RELATIVE_FRI
       (@freq_interval <> 07) AND -- RELATIVE_SAT
       (@freq_interval <> 08) AND -- RELATIVE_DAY
       (@freq_interval <> 09) AND -- RELATIVE_WEEKDAY
       (@freq_interval <> 10)     -- RELATIVE_WEEKENDDAY
    BEGIN
      SELECT @reason = FORMATMESSAGE(14576)
      RAISERROR(14278, -1, -1, @reason)
      RETURN(1) -- Failure
    END
  END

  IF ((@freq_type = 0x08)  OR   -- FREQTYPE_WEEKLY
      (@freq_type = 0x10)  OR   -- FREQTYPE_MONTHLY
      (@freq_type = 0x20)) AND  -- FREQTYPE_MONTHLYRELATIVE
      (@freq_recurrence_factor < 1)
  BEGIN
    SELECT @reason = FORMATMESSAGE(14577)
    RAISERROR(14278, -1, -1, @reason)
    RETURN(1) -- Failure
  END

ExitProc:
  -- If we made it this far the schedule is good
  RETURN(0) -- Success

END
go


/**************************************************************/
/* SP_ATTACH_SCHEDULE                                         */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_attach_schedule ...'
go
ALTER PROCEDURE sp_attach_schedule
(
  @job_id               UNIQUEIDENTIFIER    = NULL,     -- Must provide either this or job_name
  @job_name             sysname             = NULL,     -- Must provide either this or job_id
  @schedule_id          INT                 = NULL,     -- Must provide either this or schedule_name
  @schedule_name        sysname             = NULL,     -- Must provide either this or schedule_id
  @automatic_post       BIT                 = 1         -- If 1 will post notifications to all tsx servers to that run this job
)   
AS
BEGIN
  DECLARE @retval           INT
  DECLARE @sched_owner_sid  VARBINARY(85)
  DECLARE @job_owner_sid    VARBINARY(85)

  
  SET NOCOUNT ON

  -- Check that we can uniquely identify the job
  EXECUTE @retval = msdb.dbo.sp_verify_job_identifiers '@job_name',
                                                       '@job_id',
                                                        @job_name                   OUTPUT,
                                                        @job_id                     OUTPUT,
                                                        @owner_sid = @job_owner_sid OUTPUT
    IF (@retval <> 0)
        RETURN(1) -- Failure

  -- Check authority (only SQLServerAgent can add a schedule to a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)
        
  -- Check that we can uniquely identify the schedule
  EXECUTE @retval = msdb.dbo.sp_verify_schedule_identifiers @name_of_name_parameter = '@schedule_name',
                                                            @name_of_id_parameter   = '@schedule_id',
                                                            @schedule_name          = @schedule_name    OUTPUT,
                                                            @schedule_id            = @schedule_id      OUTPUT,
                                                            @owner_sid              = @sched_owner_sid  OUTPUT,
                                                            @orig_server_id         = NULL
  IF (@retval <> 0)
      RETURN(1) -- Failure     

  --Schedules can only be attached to a job if the job and schedule have the 
  --same owner or the caller is a sysadmin
  IF ((@sched_owner_sid <> @job_owner_sid) AND 
     ((@sched_owner_sid <> SUSER_SID()) OR (@job_owner_sid <> SUSER_SID())) AND
      (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1))
  BEGIN
     RAISERROR(14377, -1, -1)
     RETURN(1) -- Failure
  END

  -- If the record doesn't already exist create it
  IF( NOT EXISTS(SELECT *  
                 FROM msdb.dbo.sysjobschedules
                 WHERE (schedule_id = @schedule_id)
                   AND (job_id = @job_id)) )
  BEGIN
    INSERT INTO msdb.dbo.sysjobschedules (schedule_id, job_id)
    SELECT @schedule_id, @job_id
    
    SELECT @retval = @@ERROR

    -- Notify SQLServerAgent of the change, but only if we know the job has been cached
    IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobservers
                WHERE (job_id = @job_id)
                    AND (server_id = 0)))
    BEGIN
        EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                            @job_id      = @job_id,
                                            @schedule_id = @schedule_id,
                                            @action_type = N'I'
    END
    
    -- For a multi-server job, remind the user that they need to call sp_post_msx_operation
    IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobservers
                WHERE (job_id = @job_id)
                    AND (server_id <> 0)))
      -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
      IF (@automatic_post = 1)
        EXECUTE sp_post_msx_operation @operation = 'INSERT', @object_type = 'JOB', @job_id = @job_id
      ELSE
        RAISERROR(14547, 0, 1, N'INSERT', N'sp_post_msx_operation')

	-- update this job's subplan to point to this schedule
	UPDATE msdb.dbo.sysmaintplan_subplans
	  SET schedule_id = @schedule_id
	WHERE (job_id = @job_id)
	  AND (schedule_id IS NULL)
  END
  
  RETURN(@retval) -- 0 means success
END
GO


/**************************************************************/
/* SP_DETACH_SCHEDULE                                         */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_detach_schedule ...'
go
ALTER PROCEDURE sp_detach_schedule
(
  @job_id               UNIQUEIDENTIFIER    = NULL,     -- Must provide either this or job_name
  @job_name             sysname             = NULL,     -- Must provide either this or job_id
  @schedule_id          INT                 = NULL,     -- Must provide either this or schedule_name
  @schedule_name        sysname             = NULL,     -- Must provide either this or schedule_id
  @delete_unused_schedule BIT               = 0,        -- Can optionally delete schedule if it isn't referenced.
                                                        -- The default is to keep schedules 
  @automatic_post       BIT                 = 1         -- If 1 will post notifications to all tsx servers to that run this job
)   
AS
BEGIN
  DECLARE @retval   INT
  DECLARE @sched_owner_sid VARBINARY(85)
  DECLARE @job_owner_sid    VARBINARY(85)
  
  SET NOCOUNT ON

  -- Check that we can uniquely identify the job
  EXECUTE @retval = msdb.dbo.sp_verify_job_identifiers '@job_name',
                                                       '@job_id',
                                                        @job_name OUTPUT,
                                                        @job_id   OUTPUT,
                                                        @owner_sid = @job_owner_sid OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- Check authority (only SQLServerAgent can add a schedule to a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)
        
  -- Check that we can uniquely identify the schedule
  EXECUTE @retval = msdb.dbo.sp_verify_schedule_identifiers @name_of_name_parameter = '@schedule_name',
                                                            @name_of_id_parameter   = '@schedule_id',
                                                            @schedule_name          = @schedule_name OUTPUT,
                                                            @schedule_id            = @schedule_id   OUTPUT,
                                                            @owner_sid              = @sched_owner_sid OUTPUT,
                                                            @orig_server_id         = NULL,
                                                            @job_id_filter          = @job_id
  IF (@retval <> 0)
      RETURN(1) -- Failure
 
  -- If the record doesn't exist raise an error
  IF( NOT EXISTS(SELECT *  
                 FROM msdb.dbo.sysjobschedules
                 WHERE (schedule_id = @schedule_id)
                   AND (job_id = @job_id)) )
  BEGIN
    RAISERROR(14374, 0, 1, @schedule_name, @job_name)    
    RETURN(1) -- Failure   
  END
  ELSE
  BEGIN
  
    -- Only sysadmin can detach schedules from jobs they do not own
   IF (((@sched_owner_sid <> SUSER_SID()) OR (@job_owner_sid <> SUSER_SID())) AND
        (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1))
    BEGIN
      RAISERROR(14391, -1, -1)
      RETURN(1) -- Failure
    END

    DELETE FROM msdb.dbo.sysjobschedules
    WHERE (job_id = @job_id)
      AND (schedule_id = @schedule_id)
    
    SELECT @retval = @@ERROR
    
    --delete the schedule if requested and it isn't referenced
    IF(@retval = 0 AND @delete_unused_schedule = 1)
    BEGIN
        IF(NOT EXISTS(SELECT * 
                      FROM msdb.dbo.sysjobschedules
                      WHERE (schedule_id = @schedule_id)))
        BEGIN
            DELETE FROM msdb.dbo.sysschedules
            WHERE (schedule_id = @schedule_id)
        END
    END

    -- Update the job's version/last-modified information
    UPDATE msdb.dbo.sysjobs
    SET version_number = version_number + 1,
        date_modified = GETDATE()
    WHERE (job_id = @job_id)

    -- Notify SQLServerAgent of the change, but only if we know the job has been cached
    IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobservers
                WHERE (job_id = @job_id)
                    AND (server_id = 0)))
    BEGIN
        EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                            @job_id      = @job_id,
                                            @schedule_id = @schedule_id,
                                            @action_type = N'D'
    END

    -- For a multi-server job, remind the user that they need to call sp_post_msx_operation
    IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobservers
                WHERE (job_id = @job_id)
                    AND (server_id <> 0)))
      -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
      IF (@automatic_post = 1)
        EXECUTE sp_post_msx_operation @operation = 'INSERT', @object_type = 'JOB', @job_id = @job_id
      ELSE
        RAISERROR(14547, 0, 1, N'INSERT', N'sp_post_msx_operation')
    
	-- set this job's subplan to the first schedule in sysjobschedules or NULL if there is none 
	UPDATE msdb.dbo.sysmaintplan_subplans
	SET schedule_id = (	SELECT TOP(1) schedule_id
						FROM msdb.dbo.sysjobschedules
						WHERE (job_id = @job_id) )
	WHERE (job_id = @job_id)
	  AND (schedule_id = @schedule_id)
  END
  
  RETURN(@retval) -- 0 means success
END
GO

/**************************************************************/
/* SP_UPDATE_SCHEDULE                                         */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_update_schedule ...'
go
ALTER PROCEDURE sp_update_schedule
(
  @schedule_id              INT             = NULL,     -- Must provide either this or schedule_name
  @name                     sysname         = NULL,     -- Must provide either this or schedule_id
  @new_name                 sysname         = NULL,
  @enabled                  TINYINT         = NULL,
  @freq_type                INT             = NULL,
  @freq_interval            INT             = NULL,
  @freq_subday_type         INT             = NULL,
  @freq_subday_interval     INT             = NULL,
  @freq_relative_interval   INT             = NULL,
  @freq_recurrence_factor   INT             = NULL,
  @active_start_date        INT             = NULL, 
  @active_end_date          INT             = NULL,
  @active_start_time        INT             = NULL,
  @active_end_time          INT             = NULL,
  @owner_login_name         sysname         = NULL,
  @automatic_post           BIT             = 1         -- If 1 will post notifications to all tsx servers to 
                                                        -- update all jobs that use this schedule
)
AS
BEGIN
  DECLARE @retval                   INT
  DECLARE @owner_sid                VARBINARY(85)
  DECLARE @cur_owner_sid            VARBINARY(85)
  DECLARE @x_name                   sysname
  DECLARE @enable_only_used         INT

  DECLARE @x_enabled                TINYINT
  DECLARE @x_freq_type              INT
  DECLARE @x_freq_interval          INT
  DECLARE @x_freq_subday_type       INT
  DECLARE @x_freq_subday_interval   INT
  DECLARE @x_freq_relative_interval INT
  DECLARE @x_freq_recurrence_factor INT
  DECLARE @x_active_start_date      INT
  DECLARE @x_active_end_date        INT
  DECLARE @x_active_start_time      INT
  DECLARE @x_active_end_time        INT
  DECLARE @schedule_uid             UNIQUEIDENTIFIER

  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @name              = LTRIM(RTRIM(@name))
  SELECT @new_name          = LTRIM(RTRIM(@new_name))
  SELECT @owner_login_name  = LTRIM(RTRIM(@owner_login_name))
  -- Turn [nullable] empty string parameters into NULLs
  IF (@new_name = N'') SELECT @new_name = NULL

   -- If the owner is supplied get the sid and check it
  IF(@owner_login_name IS NOT NULL AND @owner_login_name <> '')
  BEGIN
      -- Get the sid for @owner_login_name SID 
      --force case insensitive comparation for NT users
      SELECT @owner_sid = dbo.SQLAGENT_SUSER_SID(@owner_login_name)
    -- Cannot proceed if @owner_login_name doesn't exist
    IF(@owner_sid IS NULL)
    BEGIN
      RAISERROR(14262, -1, -1, '@owner_login_name', @owner_login_name)
      RETURN(1) -- Failure
    END
  END

  -- Check that we can uniquely identify the schedule. This only returns a schedule that is visible to this user
  EXECUTE @retval = msdb.dbo.sp_verify_schedule_identifiers @name_of_name_parameter = '@name',
                                                            @name_of_id_parameter   = '@schedule_id',
                                                            @schedule_name          = @name             OUTPUT,
                                                            @schedule_id            = @schedule_id      OUTPUT,
                                                            @owner_sid              = @cur_owner_sid    OUTPUT,
                                                            @orig_server_id         = NULL
  IF (@retval <> 0)
      RETURN(1) -- Failure   

  -- Is @enable the only parameter used beside jobname and jobid?
  IF ((@enabled                   IS NOT NULL) AND
       (@new_name                 IS NULL) AND
      (@freq_type                 IS NULL) AND
      (@freq_interval             IS NULL) AND
      (@freq_subday_type          IS NULL) AND
      (@freq_subday_interval      IS NULL) AND
      (@freq_relative_interval    IS NULL) AND
      (@freq_recurrence_factor    IS NULL) AND
      (@active_start_date         IS NULL) AND
      (@active_end_date           IS NULL) AND
      (@active_start_time         IS NULL) AND
      (@active_end_time           IS NULL) AND
      (@owner_login_name          IS NULL))
    SELECT @enable_only_used = 1
  ELSE
    SELECT @enable_only_used = 0
      
  -- Non-sysadmins can only update jobs schedules they own. 
  -- Members of SQLAgentReaderRole and SQLAgentOperatorRole can view job schedules, 
  -- but they should not be able to delete them
  IF ((@cur_owner_sid <> SUSER_SID())
       AND (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'),0) <> 1)
      AND (@enable_only_used <> 1 OR ISNULL(IS_MEMBER(N'SQLAgentOperatorRole'), 0) <> 1))
  BEGIN
   RAISERROR(14394, -1, -1)
   RETURN(1) -- Failure
  END
  
  -- If the param @owner_login_name is null or doesn't get resolved by SUSER_SID() set it to the current owner of the schedule
  if(@owner_sid IS NULL)
      SELECT @owner_sid = @cur_owner_sid
       
   -- Set the x_ (existing) variables
  SELECT @x_name                   = name,
         @x_enabled                = enabled,
         @x_freq_type              = freq_type,
         @x_freq_interval          = freq_interval,
         @x_freq_subday_type       = freq_subday_type,
         @x_freq_subday_interval   = freq_subday_interval,
         @x_freq_relative_interval = freq_relative_interval,
         @x_freq_recurrence_factor = freq_recurrence_factor,
         @x_active_start_date      = active_start_date,
         @x_active_end_date        = active_end_date,
         @x_active_start_time      = active_start_time,
         @x_active_end_time        = active_end_time
  FROM msdb.dbo.sysschedules
  WHERE (schedule_id = @schedule_id )     
  
  
    -- Fill out the values for all non-supplied parameters from the existing values
  IF (@new_name               IS NULL) SELECT @new_name               = @x_name
  IF (@enabled                IS NULL) SELECT @enabled                = @x_enabled
  IF (@freq_type              IS NULL) SELECT @freq_type              = @x_freq_type
  IF (@freq_interval          IS NULL) SELECT @freq_interval          = @x_freq_interval
  IF (@freq_subday_type       IS NULL) SELECT @freq_subday_type       = @x_freq_subday_type
  IF (@freq_subday_interval   IS NULL) SELECT @freq_subday_interval   = @x_freq_subday_interval
  IF (@freq_relative_interval IS NULL) SELECT @freq_relative_interval = @x_freq_relative_interval
  IF (@freq_recurrence_factor IS NULL) SELECT @freq_recurrence_factor = @x_freq_recurrence_factor
  IF (@active_start_date      IS NULL) SELECT @active_start_date      = @x_active_start_date
  IF (@active_end_date        IS NULL) SELECT @active_end_date        = @x_active_end_date
  IF (@active_start_time      IS NULL) SELECT @active_start_time      = @x_active_start_time
  IF (@active_end_time        IS NULL) SELECT @active_end_time        = @x_active_end_time
      
  -- Check schedule (frequency and owner) parameters
  EXECUTE @retval = sp_verify_schedule @schedule_id             = @schedule_id,
                                       @name                    = @new_name,
                                       @enabled                 = @enabled,
                                       @freq_type               = @freq_type,
                                       @freq_interval           = @freq_interval            OUTPUT,
                                       @freq_subday_type        = @freq_subday_type         OUTPUT,
                                       @freq_subday_interval    = @freq_subday_interval     OUTPUT,
                                       @freq_relative_interval  = @freq_relative_interval   OUTPUT,
                                       @freq_recurrence_factor  = @freq_recurrence_factor   OUTPUT,
                                       @active_start_date       = @active_start_date        OUTPUT,
                                       @active_start_time       = @active_start_time        OUTPUT,
                                       @active_end_date         = @active_end_date          OUTPUT,
                                       @active_end_time         = @active_end_time          OUTPUT,
                                       @owner_sid               = @owner_sid
  IF (@retval <> 0)
    RETURN(1) -- Failure  

  -- Update the sysschedules table
  UPDATE msdb.dbo.sysschedules
  SET name                   = @new_name,
      owner_sid              = @owner_sid,
      enabled                = @enabled,
      freq_type              = @freq_type,
      freq_interval          = @freq_interval,
      freq_subday_type       = @freq_subday_type,
      freq_subday_interval   = @freq_subday_interval,
      freq_relative_interval = @freq_relative_interval,
      freq_recurrence_factor = @freq_recurrence_factor,
      active_start_date      = @active_start_date,
      active_end_date        = @active_end_date,
      active_start_time      = @active_start_time,
      active_end_time        = @active_end_time,
      date_modified          = GETDATE(),
      version_number         = version_number + 1
  WHERE (schedule_id = @schedule_id)

  SELECT @retval = @@error

 -- update any job that has repl steps
  DECLARE @job_id UNIQUEIDENTIFIER
  DECLARE jobsschedule_cursor CURSOR LOCAL FOR
  SELECT job_id
  FROM msdb.dbo.sysjobschedules
  WHERE (schedule_id = @schedule_id)
  
  IF @x_freq_type <> @freq_type
  BEGIN
    OPEN jobsschedule_cursor
    FETCH NEXT FROM jobsschedule_cursor INTO @job_id

    WHILE (@@FETCH_STATUS = 0)
    BEGIN 
      EXEC  sp_update_replication_job_parameter @job_id = @job_id,
                                                @old_freq_type = @x_freq_type,
                                                @new_freq_type = @freq_type
      FETCH NEXT FROM jobsschedule_cursor INTO @job_id
    END
    CLOSE jobsschedule_cursor
  END
  DEALLOCATE jobsschedule_cursor
  
  -- Notify SQLServerAgent of the change if this is attached to a local job
  IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobschedules AS jsched 
              JOIN msdb.dbo.sysjobservers AS jsvr
                    ON jsched.job_id = jsvr.job_id
                WHERE (jsched.schedule_id = @schedule_id)
                  AND (jsvr.server_id = 0)) )
  BEGIN 
      EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                          @schedule_id = @schedule_id,
                                          @action_type = N'U'              
  END


  -- Instruct the tsx servers to pick up the altered schedule
  IF (@automatic_post = 1)
  BEGIN
      SELECT @schedule_uid = schedule_uid 
      FROM sysschedules 
      WHERE schedule_id = @schedule_id

      IF(NOT @schedule_uid IS NULL)
      BEGIN
          -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
          EXECUTE @retval = sp_post_msx_operation @operation = 'INSERT', @object_type = 'SCHEDULE', @schedule_uid = @schedule_uid
      END
  END  

  RETURN(@retval) -- 0 means success
END
GO


/**************************************************************/
/* SP_DELETE_SCHEDULE                                         */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_delete_schedule ...'
go

ALTER PROCEDURE sp_delete_schedule
(
  @schedule_id          INT                 = NULL,     -- Must provide either this or schedule_name
  @schedule_name        sysname             = NULL,     -- Must provide either this or schedule_id
  @force_delete         bit                 = 0,
  @automatic_post       BIT                 = 1         -- If 1 will post notifications to all tsx servers to that run this schedule
)   
AS
BEGIN
  DECLARE @retval           INT
  DECLARE @owner_sid        VARBINARY(85)
  DECLARE @job_count        INT
  DECLARE @targ_server_id   INT

  SET NOCOUNT ON
  --Get the owners sid       
  SELECT @job_count = 0

  -- Check that we can uniquely identify the schedule. This only returns a schedule that is visible to this user
  EXECUTE @retval = msdb.dbo.sp_verify_schedule_identifiers @name_of_name_parameter = '@schedule_name',
                                                            @name_of_id_parameter   = '@schedule_id',
                                                            @schedule_name          = @schedule_name    OUTPUT,
                                                            @schedule_id            = @schedule_id      OUTPUT,
                                                            @owner_sid              = @owner_sid        OUTPUT,
                                                            @orig_server_id         = NULL
  IF (@retval <> 0)
    RETURN(1) -- Failure 

  -- Non-sysadmins can only update jobs schedules they own. 
  -- Members of SQLAgentReaderRole and SQLAgentOperatorRole can view job schedules, 
  -- but they should not be able to delete them
  IF ((@owner_sid <> SUSER_SID()) AND
     (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'),0) <> 1))
  BEGIN
   RAISERROR(14394, -1, -1)
   RETURN(1) -- Failure
  END
    
  --check if there are jobs using this schedule
  SELECT @job_count = count(*)
  FROM sysjobschedules 
  WHERE (schedule_id = @schedule_id)   
  
  -- If we aren't force deleting the schedule make sure no jobs are using it
  IF ((@force_delete = 0) AND (@job_count > 0))
  BEGIN 
    RAISERROR(14372, -1, -1)
    RETURN (1) -- Failure 
  END

  -- Get the one of the terget server_id's. 
  -- Getting MIN(jsvr.server_id) works here because we are only interested in this ID
  -- to determine if the schedule ID is for local jobs or MSX jobs. 
  -- Note, an MSX job can't be run on the local server
  SELECT @targ_server_id = MIN(jsvr.server_id)
  FROM msdb.dbo.sysjobschedules AS jsched 
   JOIN msdb.dbo.sysjobservers AS jsvr
      ON jsched.job_id = jsvr.job_id
  WHERE (jsched.schedule_id = @schedule_id)

  --OK to delete the job - schedule link
  DELETE sysjobschedules 
  WHERE schedule_id = @schedule_id

  --OK to delete the schedule 
  DELETE sysschedules 
  WHERE schedule_id = @schedule_id

  -- @targ_server_id would be null if no jobs use this schedule
  IF (@targ_server_id IS NOT NULL)
  BEGIN
   -- Notify SQLServerAgent of the change but only if it the schedule was used by a local job
   IF (@targ_server_id = 0)
   BEGIN 
      -- Only send a notification if the schedule is force deleted. If it isn't force deleted
      -- a notification would have already been sent while detaching the schedule (sp_detach_schedule)
      IF (@force_delete = 1)
      BEGIN
        EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                   @schedule_id = @schedule_id,
                                   @action_type = N'D'
      END                   
   END
   ELSE
   BEGIN
    -- Instruct the tsx servers to pick up the altered schedule
    IF (@automatic_post = 1)
    BEGIN
      DECLARE @schedule_uid UNIQUEIDENTIFIER
      SELECT @schedule_uid = schedule_uid 
      FROM sysschedules 
      WHERE schedule_id = @schedule_id

      IF(NOT @schedule_uid IS NULL)
      BEGIN
        -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
        EXECUTE sp_post_msx_operation @operation = 'INSERT', @object_type = 'SCHEDULE', @schedule_uid = @schedule_uid
      END
    END
    ELSE
      RAISERROR(14547, 0, 1, N'INSERT', N'sp_post_msx_operation')
   END
  END
  
  RETURN(@retval) -- 0 means success
END
GO

/**************************************************************/
/* SP_ADD_JOBSCHEDULE                                         */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_add_jobschedule...'
go
ALTER PROCEDURE sp_add_jobschedule                 -- This SP is deprecated. Use sp_add_schedule and sp_attach_schedule.
  @job_id                 UNIQUEIDENTIFIER = NULL,
  @job_name               sysname          = NULL,
  @name                   sysname,
  @enabled                TINYINT          = 1,
  @freq_type              INT              = 1,
  @freq_interval          INT              = 0,
  @freq_subday_type       INT              = 0,
  @freq_subday_interval   INT              = 0,
  @freq_relative_interval INT              = 0,
  @freq_recurrence_factor INT              = 0,
  @active_start_date      INT              = NULL,     -- sp_verify_schedule assigns a default
  @active_end_date        INT              = 99991231, -- December 31st 9999
  @active_start_time      INT              = 000000,   -- 12:00:00 am
  @active_end_time        INT              = 235959,    -- 11:59:59 pm
  @schedule_id            INT              = NULL  OUTPUT,
  @automatic_post         BIT              = 1         -- If 1 will post notifications to all tsx servers to that run this job
AS
BEGIN
  DECLARE @retval           INT
  DECLARE @owner_login_name sysname

  SET NOCOUNT ON

  -- Check authority (only SQLServerAgent can add a schedule to a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)

  -- Check that we can uniquely identify the job
  EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                              '@job_id',
                                               @job_name OUTPUT,
                                               @job_id   OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- Get the owner of the job. Prior to resusable schedules the job owner also owned the schedule
  SELECT @owner_login_name = dbo.SQLAGENT_SUSER_SNAME(owner_sid)
  FROM   sysjobs
  WHERE  (job_id = @job_id) 

  IF ((ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1) AND
      (SUSER_SNAME() <> @owner_login_name))
  BEGIN
   RAISERROR(14525, -1, -1)
   RETURN(1) -- Failure
  END

  -- Check authority (only SQLServerAgent can add a schedule to a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)

  -- Add the schedule first
  EXECUTE @retval = msdb.dbo.sp_add_schedule @schedule_name          = @name,
                                             @enabled                = @enabled,
                                             @freq_type              = @freq_type,
                                             @freq_interval          = @freq_interval,
                                             @freq_subday_type       = @freq_subday_type,
                                             @freq_subday_interval   = @freq_subday_interval,
                                             @freq_relative_interval = @freq_relative_interval,
                                             @freq_recurrence_factor = @freq_recurrence_factor,
                                             @active_start_date      = @active_start_date,
                                             @active_end_date        = @active_end_date,
                                             @active_start_time      = @active_start_time,
                                             @active_end_time        = @active_end_time,
                                             @owner_login_name       = @owner_login_name,
                                             @schedule_id            = @schedule_id  OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure
 
 
  EXECUTE @retval = msdb.dbo.sp_attach_schedule @job_id           = @job_id, 
                                                @job_name         = NULL,
                                                @schedule_id      = @schedule_id,
                                                @schedule_name    = NULL,
                                                @automatic_post   = @automatic_post
  IF (@retval <> 0)
    RETURN(1) -- Failure
    
    

  RETURN(@retval) -- 0 means success
END
go

/**************************************************************/
/* SP_UPDATE_JOBSCHEDULE                                      */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_update_jobschedule...'
go
ALTER PROCEDURE sp_update_jobschedule              -- This SP is deprecated by sp_update_schedule.
  @job_id                 UNIQUEIDENTIFIER = NULL,
  @job_name               sysname          = NULL,
  @name                   sysname,
  @new_name               sysname          = NULL,
  @enabled                TINYINT          = NULL,
  @freq_type              INT              = NULL,
  @freq_interval          INT              = NULL,
  @freq_subday_type       INT              = NULL,
  @freq_subday_interval   INT              = NULL,
  @freq_relative_interval INT              = NULL,
  @freq_recurrence_factor INT              = NULL,
  @active_start_date      INT              = NULL,
  @active_end_date        INT              = NULL,
  @active_start_time      INT              = NULL,
  @active_end_time        INT              = NULL,
  @automatic_post         BIT              = 1         -- If 1 will post notifications to all tsx servers to that run this job
AS
BEGIN
  DECLARE @retval                   INT
  DECLARE @sched_count              INT
  DECLARE @schedule_id              INT
  DECLARE @job_owner_sid            VARBINARY(85)
  DECLARE @enable_only_used         INT

  DECLARE @x_name                   sysname
  DECLARE @x_enabled                TINYINT
  DECLARE @x_freq_type              INT
  DECLARE @x_freq_interval          INT
  DECLARE @x_freq_subday_type       INT
  DECLARE @x_freq_subday_interval   INT
  DECLARE @x_freq_relative_interval INT
  DECLARE @x_freq_recurrence_factor INT
  DECLARE @x_active_start_date      INT
  DECLARE @x_active_end_date        INT
  DECLARE @x_active_start_time      INT
  DECLARE @x_active_end_time        INT
  DECLARE @owner_sid                VARBINARY(85)

  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @name     = LTRIM(RTRIM(@name))
  SELECT @new_name = LTRIM(RTRIM(@new_name))

  -- Turn [nullable] empty string parameters into NULLs
  IF (@new_name = N'') SELECT @new_name = NULL

  -- Check authority (only SQLServerAgent can modify a schedule of a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = 'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)

  -- Check that we can uniquely identify the job
  EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                              '@job_id',
                                               @job_name OUTPUT,
                                               @job_id   OUTPUT,
                                               @owner_sid = @job_owner_sid OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure
    
  -- Is @enable the only parameter used beside jobname and jobid?
  IF ((@enabled                   IS NOT NULL) AND
     (@name                 IS NULL) AND
     (@new_name                IS NULL) AND
      (@freq_type              IS NULL) AND
      (@freq_interval             IS NULL) AND
      (@freq_subday_type          IS NULL) AND
      (@freq_subday_interval      IS NULL) AND
      (@freq_relative_interval       IS NULL) AND
      (@freq_recurrence_factor       IS NULL) AND
      (@active_start_date         IS NULL) AND
      (@active_end_date           IS NULL) AND
      (@active_start_time         IS NULL) AND
      (@active_end_time           IS NULL))
    SELECT @enable_only_used = 1
  ELSE
    SELECT @enable_only_used = 0
    

  IF ((SUSER_SID() <> @job_owner_sid)
     AND (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1)
      AND (@enable_only_used <> 1 OR ISNULL(IS_MEMBER(N'SQLAgentOperatorRole'), 0) <> 1))
  BEGIN
   RAISERROR(14525, -1, -1)
   RETURN(1) -- Failure
  END

  -- Make sure the schedule_id can be uniquely identified and that it exists
  -- Note: It's safe use the values returned by the MIN() function because the SP errors out if more than 1 record exists
  SELECT @sched_count = COUNT(*),
         @schedule_id = MIN(sched.schedule_id),
         @owner_sid   = MIN(sched.owner_sid)
  FROM msdb.dbo.sysjobschedules as jsched
    JOIN msdb.dbo.sysschedules_localserver_view as sched
      ON jsched.schedule_id = sched.schedule_id
  WHERE (jsched.job_id = @job_id)
    AND (sched.name = @name)

  -- Need to use sp_update_schedule to update this ambiguous schedule name
  IF(@sched_count > 1)
  BEGIN
    RAISERROR(14375, -1, -1, @name, @job_name)
    RETURN(1) -- Failure
  END

  IF (@schedule_id IS NULL)
  BEGIN
   --raise an explicit message if the schedule does exist but isn't attached to this job
   IF EXISTS(SELECT * 
           FROM sysschedules_localserver_view
              WHERE (name = @name))
   BEGIN
      RAISERROR(14374, -1, -1, @name, @job_name)
   END
   ELSE
    BEGIN
      --If the schedule is from an MSX and a sysadmin is calling report a specific 'MSX' message
      IF(PROGRAM_NAME() NOT LIKE N'SQLAgent%' AND
         ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 1 AND
         EXISTS(SELECT * 
                FROM msdb.dbo.sysschedules as sched
                  JOIN msdb.dbo.sysoriginatingservers_view as svr
                    ON sched.originating_server_id = svr.originating_server_id
                  JOIN msdb.dbo.sysjobschedules as js 
                    ON sched.schedule_id = js.schedule_id
                WHERE (svr.master_server = 1) AND
                      (sched.name = @name) AND
                      (js.job_id = @job_id)))
     BEGIN
       RAISERROR(14274, -1, -1)
     END
      ELSE
      BEGIN
        --Generic message that the schedule doesn't exist
        RAISERROR(14262, -1, -1, 'Schedule Name', @name)
      END
   END

   RETURN(1) -- Failure
  END

  -- Set the x_ (existing) variables
  SELECT @x_name                   = name,
         @x_enabled                = enabled,
         @x_freq_type              = freq_type,
         @x_freq_interval          = freq_interval,
         @x_freq_subday_type       = freq_subday_type,
         @x_freq_subday_interval   = freq_subday_interval,
         @x_freq_relative_interval = freq_relative_interval,
         @x_freq_recurrence_factor = freq_recurrence_factor,
         @x_active_start_date      = active_start_date,
         @x_active_end_date        = active_end_date,
         @x_active_start_time      = active_start_time,
         @x_active_end_time        = active_end_time
  FROM msdb.dbo.sysschedules_localserver_view
  WHERE (schedule_id = @schedule_id )

  
  -- Fill out the values for all non-supplied parameters from the existing values
  IF (@new_name               IS NULL) SELECT @new_name               = @x_name
  IF (@enabled                IS NULL) SELECT @enabled                = @x_enabled
  IF (@freq_type              IS NULL) SELECT @freq_type              = @x_freq_type
  IF (@freq_interval          IS NULL) SELECT @freq_interval          = @x_freq_interval
  IF (@freq_subday_type       IS NULL) SELECT @freq_subday_type       = @x_freq_subday_type
  IF (@freq_subday_interval   IS NULL) SELECT @freq_subday_interval   = @x_freq_subday_interval
  IF (@freq_relative_interval IS NULL) SELECT @freq_relative_interval = @x_freq_relative_interval
  IF (@freq_recurrence_factor IS NULL) SELECT @freq_recurrence_factor = @x_freq_recurrence_factor
  IF (@active_start_date      IS NULL) SELECT @active_start_date      = @x_active_start_date
  IF (@active_end_date        IS NULL) SELECT @active_end_date        = @x_active_end_date
  IF (@active_start_time      IS NULL) SELECT @active_start_time      = @x_active_start_time
  IF (@active_end_time        IS NULL) SELECT @active_end_time        = @x_active_end_time

  -- Check schedule (frequency and owner) parameters
  EXECUTE @retval = sp_verify_schedule @schedule_id             = @schedule_id,
                                       @name                    = @new_name,
                                       @enabled                 = @enabled,
                                       @freq_type               = @freq_type,
                                       @freq_interval           = @freq_interval            OUTPUT,
                                       @freq_subday_type        = @freq_subday_type         OUTPUT,
                                       @freq_subday_interval    = @freq_subday_interval     OUTPUT,
                                       @freq_relative_interval  = @freq_relative_interval   OUTPUT,
                                       @freq_recurrence_factor  = @freq_recurrence_factor   OUTPUT,
                                       @active_start_date       = @active_start_date        OUTPUT,
                                       @active_start_time       = @active_start_time        OUTPUT,
                                       @active_end_date         = @active_end_date          OUTPUT,
                                       @active_end_time         = @active_end_time          OUTPUT,
                                       @owner_sid               = @owner_sid
  IF (@retval <> 0)
    RETURN(1) -- Failure


  -- Update the JobSchedule
  UPDATE msdb.dbo.sysschedules
  SET name                   = @new_name,
      enabled                = @enabled,
      freq_type              = @freq_type,
      freq_interval          = @freq_interval,
      freq_subday_type       = @freq_subday_type,
      freq_subday_interval   = @freq_subday_interval,
      freq_relative_interval = @freq_relative_interval,
      freq_recurrence_factor = @freq_recurrence_factor,
      active_start_date      = @active_start_date,
      active_end_date        = @active_end_date,
      active_start_time      = @active_start_time,
      active_end_time        = @active_end_time,
      date_modified          = GETDATE(),
      version_number         = version_number + 1
  WHERE (schedule_id = @schedule_id)

  SELECT @retval = @@error

  -- Update the job's version/last-modified information
  UPDATE msdb.dbo.sysjobs
  SET version_number = version_number + 1,
      date_modified = GETDATE()
  WHERE (job_id = @job_id)

  -- Notify SQLServerAgent of the change, but only if we know the job has been cached
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobservers
              WHERE (job_id = @job_id)
                AND (server_id = 0)))
  BEGIN
    EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                        @job_id      = @job_id,
                                        @schedule_id = @schedule_id,
                                        @action_type = N'U'
  END

  -- For a multi-server job, remind the user that they need to call sp_post_msx_operation
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobservers
              WHERE (job_id = @job_id)
                AND (server_id <> 0)))
    -- Instruct the tsx servers to pick up the altered schedule
    IF (@automatic_post = 1)
    BEGIN
      DECLARE @schedule_uid UNIQUEIDENTIFIER
      SELECT @schedule_uid = schedule_uid 
      FROM sysschedules 
      WHERE schedule_id = @schedule_id

      IF(NOT @schedule_uid IS NULL)
      BEGIN
        -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
        EXECUTE sp_post_msx_operation @operation = 'INSERT', @object_type = 'SCHEDULE', @schedule_uid = @schedule_uid
      END
    END
    ELSE
      RAISERROR(14547, 0, 1, N'INSERT', N'sp_post_msx_operation')

  -- Automatic addition and removal of -Continous parameter for replication agent
  EXECUTE sp_update_replication_job_parameter @job_id = @job_id,
                                              @old_freq_type = @x_freq_type,
                                              @new_freq_type = @freq_type

  RETURN(@retval) -- 0 means success
END
go

/**************************************************************/
/* SP_DELETE_JOBSCHEDULE                                      */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_delete_jobschedule...'
go
ALTER PROCEDURE sp_delete_jobschedule           -- This SP is deprecated. Use sp_detach_schedule and sp_delete_schedule.
  @job_id           UNIQUEIDENTIFIER = NULL,
  @job_name         sysname          = NULL,
  @name             sysname,
  @keep_schedule    int              = 0,
  @automatic_post       BIT          = 1         -- If 1 will post notifications to all tsx servers to that run this schedule
AS
BEGIN
  DECLARE @retval           INT
  DECLARE @sched_count      INT
  DECLARE @schedule_id      INT
  DECLARE @job_owner_sid    VARBINARY(85)

  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @name = LTRIM(RTRIM(@name))

  -- Check authority (only SQLServerAgent can delete a schedule of a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)

  -- Check that we can uniquely identify the job
  EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                              '@job_id',
                                               @job_name OUTPUT,
                                               @job_id   OUTPUT,
                                               @owner_sid = @job_owner_sid OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  IF ((ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1) AND
      (SUSER_SID() <> @job_owner_sid))
  BEGIN
   RAISERROR(14525, -1, -1)
   RETURN(1) -- Failure
  END


  IF (UPPER(@name collate SQL_Latin1_General_CP1_CS_AS) = N'ALL')
  BEGIN
    SELECT @schedule_id = -1  -- We use this in the call to sp_sqlagent_notify
    
    --Delete the schedule(s) if it isn't being used by other jobs
    DECLARE @temp_schedules_to_delete TABLE (schedule_id INT NOT NULL)


    --If user requests that the schedules be removed (the legacy behavoir)
    --make sure it isnt being used by other jobs
    IF (@keep_schedule = 0)
    BEGIN
        --Get the list of schedules to delete
        INSERT INTO @temp_schedules_to_delete
        SELECT DISTINCT schedule_id 
        FROM   msdb.dbo.sysschedules
        WHERE (schedule_id IN 
                (SELECT schedule_id
                FROM msdb.dbo.sysjobschedules
                WHERE (job_id = @job_id)))
            
        --make sure no other jobs use these schedules
        IF( EXISTS(SELECT *
                    FROM msdb.dbo.sysjobschedules 
                    WHERE (job_id <> @job_id)
                    AND (schedule_id in ( SELECT schedule_id 
                                            FROM @temp_schedules_to_delete ))))
        BEGIN
        RAISERROR(14367, -1, -1)   
        RETURN(1) -- Failure
        END
    END

    --OK to delete the jobschedule
    DELETE FROM msdb.dbo.sysjobschedules
    WHERE (job_id = @job_id)
    
    --OK to delete the schedule - temp_schedules_to_delete is empty if @keep_schedule <> 0
    DELETE FROM msdb.dbo.sysschedules
    WHERE schedule_id IN 
    (SELECT schedule_id from @temp_schedules_to_delete)
  END
  ELSE
  BEGIN

    -- Make sure the schedule_id can be uniquely identified and that it exists
    -- Note: It's safe use the values returned by the MIN() function because the SP errors out if more than 1 record exists
    SELECT @sched_count = COUNT(*),
           @schedule_id = MIN(sched.schedule_id)
    FROM msdb.dbo.sysjobschedules as jsched
      JOIN msdb.dbo.sysschedules_localserver_view as sched
        ON jsched.schedule_id = sched.schedule_id
    WHERE (jsched.job_id = @job_id)
      AND (sched.name = @name)
  
    -- Need to use sp_detach_schedule to remove this ambiguous schedule name
    IF(@sched_count > 1)
    BEGIN
      RAISERROR(14376, -1, -1, @name, @job_name)
      RETURN(1) -- Failure
    END

    IF (@schedule_id IS NULL)
    BEGIN    
     --raise an explicit message if the schedule does exist but isn't attached to this job
     IF EXISTS(SELECT * 
             FROM sysschedules_localserver_view
                WHERE (name = @name))
     BEGIN
      RAISERROR(14374, -1, -1, @name, @job_name)
     END
     ELSE
      BEGIN
        --If the schedule is from an MSX and a sysadmin is calling report a specific 'MSX' message
        IF(PROGRAM_NAME() NOT LIKE N'SQLAgent%' AND
           ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 1 AND
           EXISTS(SELECT * 
                  FROM msdb.dbo.sysschedules as sched
                    JOIN msdb.dbo.sysoriginatingservers_view as svr
                      ON sched.originating_server_id = svr.originating_server_id
                    JOIN msdb.dbo.sysjobschedules as js 
                      ON sched.schedule_id = js.schedule_id
                  WHERE (svr.master_server = 1) AND
                        (sched.name = @name) AND
                        (js.job_id = @job_id)))
       BEGIN
         RAISERROR(14274, -1, -1)
       END
        ELSE
        BEGIN
          --Generic message that the schedule doesn't exist
          RAISERROR(14262, -1, -1, '@name', @name)
        END
     END

      RETURN(1) -- Failure
    END

    --If user requests that the schedule be removed (the legacy behavoir)
    --make sure it isnt being used by another job
    IF (@keep_schedule = 0)
    BEGIN
      IF( EXISTS(SELECT * 
                 FROM msdb.dbo.sysjobschedules
                 WHERE (schedule_id = @schedule_id)
                   AND (job_id <> @job_id) ))
      BEGIN
        RAISERROR(14368, -1, -1, @name)
        RETURN(1) -- Failure
      END
    END

    --Delete the job schedule link first
    DELETE FROM msdb.dbo.sysjobschedules
    WHERE (job_id = @job_id)
    AND (schedule_id = @schedule_id)
    --Delete schedule if required
    IF (@keep_schedule = 0)
    BEGIN
      --Now delete the schedule if required
      DELETE FROM msdb.dbo.sysschedules
      WHERE (schedule_id = @schedule_id)   
    END

  END


  -- Update the job's version/last-modified information
  UPDATE msdb.dbo.sysjobs
  SET version_number = version_number + 1,
      date_modified = GETDATE()
  WHERE (job_id = @job_id)

  -- Notify SQLServerAgent of the change, but only if we know the job has been cached
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobservers
              WHERE (job_id = @job_id)
                AND (server_id = 0)))
  BEGIN
    EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'S',
                                        @job_id      = @job_id,
                                        @schedule_id = @schedule_id,
                                        @action_type = N'D'
  END

  -- For a multi-server job, remind the user that they need to call sp_post_msx_operation
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobservers
              WHERE (job_id = @job_id)
                AND (server_id <> 0)))
    -- Instruct the tsx servers to pick up the altered schedule
    IF (@automatic_post = 1)
    BEGIN
      DECLARE @schedule_uid UNIQUEIDENTIFIER
      SELECT @schedule_uid = schedule_uid 
      FROM sysschedules 
      WHERE schedule_id = @schedule_id

      IF(NOT @schedule_uid IS NULL)
      BEGIN
        -- sp_post_msx_operation will do nothing if the schedule isn't assigned to any tsx machines 
        EXECUTE sp_post_msx_operation @operation = 'INSERT', @object_type = 'SCHEDULE', @schedule_uid = @schedule_uid
      END
    END
    ELSE
      RAISERROR(14547, 0, 1, N'INSERT', N'sp_post_msx_operation')

  RETURN(@retval) -- 0 means success
END
go

/**************************************************************/
/* SP_SQLAGENT_HAS_SERVER_ACCESS                              */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_sqlagent_has_server_access...'
go

ALTER PROCEDURE sp_sqlagent_has_server_access
  @login_name         sysname = NULL,
  @is_sysadmin_member INT     = NULL OUTPUT
AS
BEGIN
  DECLARE @has_server_access BIT
  DECLARE @is_sysadmin       BIT
  DECLARE @actual_login_name sysname
  DECLARE @cachedate         DATETIME

  SET NOCOUNT ON

  SELECT @cachedate = NULL

  -- remove expired entries from the cache
  DELETE msdb.dbo.syscachedcredentials
  WHERE  DATEDIFF(MINUTE, cachedate, GETDATE()) >= 29

  -- query the cache
  SELECT  @is_sysadmin = is_sysadmin_member,
          @has_server_access = has_server_access,
          @cachedate = cachedate
  FROM    msdb.dbo.syscachedcredentials
  WHERE   login_name = @login_name
  AND     DATEDIFF(MINUTE, cachedate, GETDATE()) < 29

  IF (@cachedate IS NOT NULL)
  BEGIN
    -- no output variable
    IF (@is_sysadmin_member IS NULL)
    BEGIN
      -- Return result row
      SELECT has_server_access = @has_server_access,
             is_sysadmin       = @is_sysadmin,
             actual_login_name = @login_name
      RETURN
    END
    ELSE
    BEGIN
      SELECT @is_sysadmin_member = @is_sysadmin
      RETURN
    END
  END -- select from cache

  -- Set defaults
  SELECT @has_server_access = 0
  SELECT @is_sysadmin = 0
  SELECT @actual_login_name = FORMATMESSAGE(14205)

  IF (@login_name IS NULL)
  BEGIN
    SELECT has_server_access = 1,
           is_sysadmin       = IS_SRVROLEMEMBER(N'sysadmin'),
           actual_login_name = SUSER_SNAME()
    RETURN
  END

  IF (@login_name LIKE '%\%')
  BEGIN
    -- Handle the LocalSystem account ('NT AUTHORITY\SYSTEM') as a special case
    IF (UPPER(@login_name collate SQL_Latin1_General_CP1_CS_AS) = N'NT AUTHORITY\SYSTEM')
    BEGIN
      IF (EXISTS (SELECT *
                  FROM master.dbo.syslogins
                  WHERE (UPPER(loginname collate SQL_Latin1_General_CP1_CS_AS) = N'BUILTIN\ADMINISTRATORS')))
      BEGIN
        SELECT @has_server_access = hasaccess,
               @is_sysadmin = sysadmin,
               @actual_login_name = loginname
        FROM master.dbo.syslogins
        WHERE (UPPER(loginname collate SQL_Latin1_General_CP1_CS_AS) = N'BUILTIN\ADMINISTRATORS')
      END
    END
    ELSE
    BEGIN
      -- Check if the NT login has been explicitly denied access
      IF (EXISTS (SELECT *
                  FROM master.dbo.syslogins
                  WHERE (loginname = @login_name)
                    AND (denylogin = 1)))
      BEGIN
        SELECT @has_server_access = 0,
               @is_sysadmin = sysadmin,
               @actual_login_name = loginname
        FROM master.dbo.syslogins
        WHERE (loginname = @login_name)
      END
      ELSE
      BEGIN
        -- declare table variable for storing results
        DECLARE @xp_results TABLE
        (
        account_name      sysname      COLLATE database_default NOT NULL PRIMARY KEY,
        type              NVARCHAR(10) COLLATE database_default NOT NULL,
        privilege         NVARCHAR(10) COLLATE database_default NOT NULL,
        mapped_login_name sysname      COLLATE database_default NOT NULL,
        permission_path   sysname      COLLATE database_default NULL
        )

        -- Call xp_logininfo to determine server access
        INSERT INTO @xp_results
        EXECUTE master.dbo.xp_logininfo @login_name

        SELECT @has_server_access = CASE COUNT(*)
                                      WHEN 0 THEN 0
                                      ELSE 1
                                    END
        FROM @xp_results
        SELECT @actual_login_name = mapped_login_name,
               @is_sysadmin = CASE UPPER(privilege collate SQL_Latin1_General_CP1_CS_AS)
                                WHEN 'ADMIN' THEN 1
                                ELSE 0
                             END
        FROM @xp_results
      END
    END
  END
  ELSE
  BEGIN
    -- Standard login
    IF (EXISTS (SELECT *
                FROM master.dbo.syslogins
                WHERE (loginname = @login_name)))
    BEGIN
      SELECT @has_server_access = hasaccess,
             @is_sysadmin = sysadmin,
             @actual_login_name = loginname
      FROM master.dbo.syslogins
      WHERE (loginname = @login_name)
    END
  END

  -- update the cache only if something is found
  IF  (UPPER(@actual_login_name collate SQL_Latin1_General_CP1_CS_AS) <> '(UNKNOWN)')
  BEGIN
    -- Procedure starts its own transaction.
    BEGIN TRANSACTION;
    
    -- Modify database.
    -- use a try catch login to prevent any error when trying 
    -- to insert/update syscachedcredentials table
    -- no need to fail since the job owner has been validated
    BEGIN TRY      
      IF EXISTS (SELECT * FROM msdb.dbo.syscachedcredentials WITH (TABLOCKX) WHERE login_name = @login_name)
      BEGIN
        UPDATE msdb.dbo.syscachedcredentials
        SET    has_server_access = @has_server_access,
              is_sysadmin_member = @is_sysadmin,
              cachedate = GETDATE()
        WHERE  login_name = @login_name
      END
      ELSE
      BEGIN
        INSERT INTO msdb.dbo.syscachedcredentials(login_name, has_server_access, is_sysadmin_member) 
        VALUES(@login_name, @has_server_access, @is_sysadmin)
      END
	  END TRY
	  BEGIN CATCH
		  -- If an error occurred we want to ignore it
	  END CATCH
	  
	  -- The procedure must commit the transaction it started.
	  COMMIT TRANSACTION;  
  END
  
  IF (@is_sysadmin_member IS NULL)
    -- Return result row
    SELECT has_server_access = @has_server_access,
           is_sysadmin       = @is_sysadmin,
           actual_login_name = @actual_login_name
  ELSE
    -- output variable only
    SELECT @is_sysadmin_member = @is_sysadmin
END
go

/**************************************************************/
/* SP_ADD_JOBSTEP_INTERNAL                                    */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_add_jobstep_internal...'
go
ALTER PROCEDURE dbo.sp_add_jobstep_internal
  @job_id                UNIQUEIDENTIFIER = NULL,   -- Must provide either this or job_name
  @job_name              sysname          = NULL,   -- Must provide either this or job_id
  @step_id               INT              = NULL,   -- The proc assigns a default
  @step_name             sysname,
  @subsystem             NVARCHAR(40)     = N'TSQL',
  @command               NVARCHAR(max)    = NULL,
  @additional_parameters NTEXT            = NULL,
  @cmdexec_success_code  INT              = 0,
  @on_success_action     TINYINT          = 1,      -- 1 = Quit With Success, 2 = Quit With Failure, 3 = Goto Next Step, 4 = Goto Step
  @on_success_step_id    INT              = 0,
  @on_fail_action        TINYINT          = 2,      -- 1 = Quit With Success, 2 = Quit With Failure, 3 = Goto Next Step, 4 = Goto Step
  @on_fail_step_id       INT              = 0,
  @server                sysname          = NULL,
  @database_name         sysname          = NULL,
  @database_user_name    sysname          = NULL,
  @retry_attempts        INT              = 0,      -- No retries
  @retry_interval        INT              = 0,      -- 0 minute interval
  @os_run_priority       INT              = 0,      -- -15 = Idle, -1 = Below Normal, 0 = Normal, 1 = Above Normal, 15 = Time Critical)
  @output_file_name      NVARCHAR(200)    = NULL,
  @flags                 INT              = 0,       --  0 = Normal, 
                                                     --  1 = Encrypted command (read only), 
                                                     --  2 = Append output files (if any), 
                                                     --  4 = Write TSQL step output to step history
                                                     --  8 = Write log to table (overwrite existing history)
                                                     -- 16 = Write log to table (append to existing history)
  @proxy_id               int               = NULL,
  @proxy_name              sysname           = NULL,
  -- mutual exclusive; must specify only one of above 2 parameters to 
  -- identify the proxy. 
  @step_uid UNIQUEIDENTIFIER              = NULL OUTPUT
AS
BEGIN
  DECLARE @retval         INT
  DECLARE @max_step_id    INT
  DECLARE @job_owner_sid  VARBINARY(85)
  DECLARE @subsystem_id   INT
  DECLARE @auto_proxy_name sysname
  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @step_name          = LTRIM(RTRIM(@step_name))
  SELECT @subsystem          = LTRIM(RTRIM(@subsystem))
  SELECT @server             = LTRIM(RTRIM(@server))
  SELECT @database_name      = LTRIM(RTRIM(@database_name))
  SELECT @database_user_name = LTRIM(RTRIM(@database_user_name))
  SELECT @output_file_name   = LTRIM(RTRIM(@output_file_name))
  SELECT @proxy_name         = LTRIM(RTRIM(@proxy_name))

  -- Turn [nullable] empty string parameters into NULLs
  IF (@server             = N'') SELECT @server             = NULL
  IF (@database_name      = N'') SELECT @database_name      = NULL
  IF (@database_user_name = N'') SELECT @database_user_name = NULL
  IF (@output_file_name   = N'') SELECT @output_file_name   = NULL
  IF (@proxy_name         = N'') SELECT @proxy_name         = NULL

  -- Check authority (only SQLServerAgent can add a step to a non-local job)
  EXECUTE @retval = sp_verify_jobproc_caller @job_id = @job_id, @program_name = N'SQLAgent%'
  IF (@retval <> 0)
    RETURN(@retval)

  EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                              '@job_id',
                                               @job_name OUTPUT,
                                               @job_id   OUTPUT,
                                               @owner_sid = @job_owner_sid OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  IF ((ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1) AND
      (SUSER_SID() <> @job_owner_sid))
  BEGIN
     RAISERROR(14525, -1, -1)
     RETURN(1) -- Failure
  END
  

  -- check proxy identifiers only if a proxy has been provided
  IF (@proxy_id IS NOT NULL) or (@proxy_name IS NOT NULL)
  BEGIN
    EXECUTE @retval = sp_verify_proxy_identifiers '@proxy_name',
                                                  '@proxy_id',
                                                   @proxy_name OUTPUT,
                                                   @proxy_id   OUTPUT
    IF (@retval <> 0)
      RETURN(1) -- Failure
   END

  -- Default step id (if not supplied)
  IF (@step_id IS NULL)
  BEGIN
    SELECT @step_id = ISNULL(MAX(step_id), 0) + 1
    FROM msdb.dbo.sysjobsteps
    WHERE (job_id = @job_id)
  END

  -- Check parameters
  EXECUTE @retval = sp_verify_jobstep @job_id,
                                      @step_id,
                                      @step_name,
                                      @subsystem,
                                      @command,
                                      @server,
                                      @on_success_action,
                                      @on_success_step_id,
                                      @on_fail_action,
                                      @on_fail_step_id,
                                      @os_run_priority,
                                      @database_name      OUTPUT,
                                      @database_user_name OUTPUT,
                                      @flags,
                                      @output_file_name,
                                               @proxy_id

  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- Get current maximum step id
  SELECT @max_step_id = ISNULL(MAX(step_id), 0)
  FROM msdb.dbo.sysjobsteps
  WHERE (job_id = @job_id)

  DECLARE @TranCounter INT;
  SET @TranCounter = @@TRANCOUNT;
  IF @TranCounter = 0
  BEGIN
	  -- start our own transaction if there is no outer transaction
      BEGIN TRANSACTION;
  END
  
  -- Modify database.
  BEGIN TRY
    -- Update the job's version/last-modified information
    UPDATE msdb.dbo.sysjobs
    SET version_number = version_number + 1,
        date_modified = GETDATE()
    WHERE (job_id = @job_id)

    -- Adjust step id's (unless the new step is being inserted at the 'end')
    -- NOTE: We MUST do this before inserting the step.
    IF (@step_id <= @max_step_id)
    BEGIN
      UPDATE msdb.dbo.sysjobsteps
      SET step_id = step_id + 1
      WHERE (step_id >= @step_id)
        AND (job_id = @job_id)

      -- Clean up OnSuccess/OnFail references
      UPDATE msdb.dbo.sysjobsteps
      SET on_success_step_id = on_success_step_id + 1
      WHERE (on_success_step_id >= @step_id)
        AND (job_id = @job_id)

      UPDATE msdb.dbo.sysjobsteps
      SET on_fail_step_id = on_fail_step_id + 1
      WHERE (on_fail_step_id >= @step_id)
        AND (job_id = @job_id)

      UPDATE msdb.dbo.sysjobsteps
      SET on_success_step_id = 0,
          on_success_action = 1  -- Quit With Success
      WHERE (on_success_step_id = @step_id)
        AND (job_id = @job_id)

      UPDATE msdb.dbo.sysjobsteps
      SET on_fail_step_id = 0,
          on_fail_action = 2     -- Quit With Failure
      WHERE (on_fail_step_id = @step_id)
        AND (job_id = @job_id)
    END

    SELECT @step_uid = NEWID()

    -- Insert the step
    INSERT INTO msdb.dbo.sysjobsteps
           (job_id,
            step_id,
            step_name,
            subsystem,
            command,
            flags,
            additional_parameters,
            cmdexec_success_code,
            on_success_action,
            on_success_step_id,
            on_fail_action,
            on_fail_step_id,
            server,
            database_name,
            database_user_name,
            retry_attempts,
            retry_interval,
            os_run_priority,
            output_file_name,
            last_run_outcome,
            last_run_duration,
            last_run_retries,
            last_run_date,
            last_run_time,
            proxy_id,
         step_uid)
    VALUES (@job_id,
            @step_id,
            @step_name,
            @subsystem,
            @command,
            @flags,
            @additional_parameters,
            @cmdexec_success_code,
            @on_success_action,
            @on_success_step_id,
            @on_fail_action,
            @on_fail_step_id,
            @server,
            @database_name,
            @database_user_name,
            @retry_attempts,
            @retry_interval,
            @os_run_priority,
            @output_file_name,
            0,
            0,
            0,
            0,
            0,
         @proxy_id,
         @step_uid)
         
  IF @TranCounter = 0
  BEGIN
	  -- start our own transaction if there is no outer transaction
      COMMIT TRANSACTION;
  END

  END TRY
  BEGIN CATCH

      -- Prepare tp echo error information to the caller.
      DECLARE @ErrorMessage NVARCHAR(400)
      DECLARE @ErrorSeverity INT
      DECLARE @ErrorState INT

      SELECT @ErrorMessage = ERROR_MESSAGE()
      SELECT @ErrorSeverity = ERROR_SEVERITY()
      SELECT @ErrorState = ERROR_STATE()
      
      IF @TranCounter = 0
      BEGIN
          -- Transaction started in procedure.
          -- Roll back complete transaction.
          ROLLBACK TRANSACTION;
      END
      RAISERROR (@ErrorMessage, -- Message text.
                  @ErrorSeverity, -- Severity.
                  @ErrorState -- State.
                  )
      RETURN (1)                  
  END CATCH
  
  -- Make sure that SQLServerAgent refreshes the job if the 'Has Steps' property has changed
  IF ((SELECT COUNT(*)
       FROM msdb.dbo.sysjobsteps
       WHERE (job_id = @job_id)) = 1)
  BEGIN
    -- NOTE: We only notify SQLServerAgent if we know the job has been cached
    IF (EXISTS (SELECT *
                FROM msdb.dbo.sysjobservers
                WHERE (job_id = @job_id)
                  AND (server_id = 0)))
      EXECUTE msdb.dbo.sp_sqlagent_notify @op_type       = N'J',
                                            @job_id      = @job_id,
                                            @action_type = N'U'
  END

  -- For a multi-server job, push changes to the target servers
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobservers
              WHERE (job_id = @job_id)
                AND (server_id <> 0)))
  BEGIN
    EXECUTE msdb.dbo.sp_post_msx_operation 'INSERT', 'JOB', @job_id
  END

  RETURN(0) -- Success
END
go

/**************************************************************/
/* SP_SQLAGENT_REFRESH_JOB                                    */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_sqlagent_refresh_job...'
go
ALTER PROCEDURE sp_sqlagent_refresh_job
  @job_id      UNIQUEIDENTIFIER = NULL,
  @server_name sysname          = NULL -- This parameter allows a TSX to use this SP when updating a job
AS
BEGIN
  DECLARE @server_id INT

  SET NOCOUNT ON

  IF (@server_name IS NULL) OR (UPPER(@server_name collate SQL_Latin1_General_CP1_CS_AS) = '(LOCAL)')
    SELECT @server_name = CONVERT(sysname, SERVERPROPERTY('ServerName'))

  SELECT @server_name = UPPER(@server_name)

  SELECT @server_id = server_id
  FROM msdb.dbo.systargetservers_view
  WHERE (UPPER(server_name) = ISNULL(@server_name, UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))))

  SELECT @server_id = ISNULL(@server_id, 0)

  SELECT sjv.job_id,
         sjv.name,
         sjv.enabled,
         sjv.start_step_id,
         owner = dbo.SQLAGENT_SUSER_SNAME(sjv.owner_sid),
         sjv.notify_level_eventlog,
         sjv.notify_level_email,
         sjv.notify_level_netsend,
         sjv.notify_level_page,
         sjv.notify_email_operator_id,
         sjv.notify_netsend_operator_id,
         sjv.notify_page_operator_id,
         sjv.delete_level,
         has_step = (SELECT COUNT(*)
                     FROM msdb.dbo.sysjobsteps sjst
                     WHERE (sjst.job_id = sjv.job_id)),
         sjv.version_number,
         last_run_date = ISNULL(sjs.last_run_date, 0),
         last_run_time = ISNULL(sjs.last_run_time, 0),
         sjv.originating_server,
         sjv.description,
         agent_account = CASE sjv.owner_sid
              WHEN 0xFFFFFFFF THEN 1
              ELSE                 0
         END
  FROM msdb.dbo.sysjobservers sjs,
	   msdb.dbo.sysjobs_view  sjv
           
  WHERE ((@job_id IS NULL) OR (@job_id = sjv.job_id))
    AND (sjv.job_id = sjs.job_id)
    AND (sjs.server_id = @server_id)
  ORDER BY sjv.job_id
  OPTION (FORCE ORDER)

  RETURN(@@error) -- 0 means success
END
go
	
/**************************************************************/
/* SP_DELETE_JOB                                              */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_delete_job...'
go

ALTER PROCEDURE sp_delete_job
  @job_id               UNIQUEIDENTIFIER = NULL, -- If provided should NOT also provide job_name
  @job_name             sysname          = NULL, -- If provided should NOT also provide job_id
  @originating_server      sysname         = NULL, -- Reserved (used by SQLAgent)
  @delete_history       BIT              = 1,    -- Reserved (used by SQLAgent)
  @delete_unused_schedule   BIT              = 1     -- For backward compatibility schedules are deleted by default if they are not 
                                        -- being used by another job. With the introduction of reusable schedules in V9 
                                        -- callers should set this to 0 so the schedule will be preserved for reuse.
AS
BEGIN
  DECLARE @current_msx_server sysname
  DECLARE @bMSX_job           BIT
  DECLARE @retval             INT
  DECLARE @local_machine_name sysname
  DECLARE @category_id        INT
  DECLARE @job_owner_sid      VARBINARY(85)
  
  SET NOCOUNT ON
  -- Remove any leading/trailing spaces from parameters
  SELECT @originating_server = UPPER(LTRIM(RTRIM(@originating_server)))

  -- Turn [nullable] empty string parameters into NULLs
  IF (@originating_server = N'') SELECT @originating_server = NULL

  -- Change server name to always reflect real servername or servername\instancename
  IF (@originating_server IS NOT NULL AND @originating_server = '(LOCAL)')
    SELECT @originating_server = UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))

  IF ((@job_id IS NOT NULL) OR (@job_name IS NOT NULL))
  BEGIN
    EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                                '@job_id',
                                                 @job_name OUTPUT,
                                                 @job_id   OUTPUT,
                                                 @owner_sid = @job_owner_sid OUTPUT
    IF (@retval <> 0)
      RETURN(1) -- Failure

  END

  -- We need either a job name or a server name, not both
  IF ((@job_name IS NULL)     AND (@originating_server IS NULL)) OR
     ((@job_name IS NOT NULL) AND (@originating_server IS NOT NULL))
  BEGIN
    RAISERROR(14279, -1, -1)
    RETURN(1) -- Failure
  END

  -- Get category to see if it is a misc. replication agent. @category_id will be
  -- NULL if there is no @job_id.
  select @category_id = category_id from msdb.dbo.sysjobs where job_id = @job_id

  -- If job name was given, determine if the job is from an MSX
  IF (@job_id IS NOT NULL)
  BEGIN
    SELECT @bMSX_job = CASE UPPER(originating_server)
                         WHEN UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName'))) THEN 0
                         ELSE 1
                       END
    FROM msdb.dbo.sysjobs_view
    WHERE (job_id = @job_id)
  END

  -- If server name was given, warn user if different from current MSX
  IF (@originating_server IS NOT NULL)
  BEGIN
    EXECUTE @retval = master.dbo.xp_getnetname @local_machine_name OUTPUT
    IF (@retval <> 0)
      RETURN(1) -- Failure

    IF ((@originating_server = UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))) OR (@originating_server = UPPER(@local_machine_name)))
      SELECT @originating_server = UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))

    EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                           N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                           N'MSXServerName',
                                           @current_msx_server OUTPUT,
                                           N'no_output'

    SELECT @current_msx_server = UPPER(@current_msx_server)
    -- If server name was given but it's not the current MSX, print a warning
    SELECT @current_msx_server = LTRIM(RTRIM(@current_msx_server))
    IF ((@current_msx_server IS NOT NULL) AND (@current_msx_server <> N'') AND (@originating_server <> @current_msx_server))
      RAISERROR(14224, 0, 1, @current_msx_server)
  END

  -- Check authority (only SQLServerAgent can delete a non-local job)
  IF (((@originating_server IS NOT NULL) AND (@originating_server <> UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName'))))) OR (@bMSX_job = 1)) AND
     (PROGRAM_NAME() NOT LIKE N'SQLAgent%')
  BEGIN
    RAISERROR(14274, -1, -1)
    RETURN(1) -- Failure
  END
  
  -- Check permissions beyond what's checked by the sysjobs_view
  -- SQLAgentReader and SQLAgentOperator roles that can see all jobs
  -- cannot delete jobs they do not own
  IF (@job_id IS NOT NULL)
  BEGIN
   IF (@job_owner_sid <> SUSER_SID()                     -- does not own the job
       AND (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1)) -- is not sysadmin
   BEGIN
     RAISERROR(14525, -1, -1);
     RETURN(1) -- Failure
    END
  END

  -- Do the delete (for a specific job)
  IF (@job_id IS NOT NULL)
  BEGIN
    -- Note: This temp table is referenced by msdb.dbo.sp_delete_job_references
    CREATE TABLE #temp_jobs_to_delete (job_id UNIQUEIDENTIFIER NOT NULL, job_is_cached INT NOT NULL)

    DECLARE @temp_schedules_to_delete TABLE (schedule_id INT NOT NULL)  

    INSERT INTO #temp_jobs_to_delete
    SELECT job_id, (SELECT COUNT(*)
                    FROM msdb.dbo.sysjobservers
                    WHERE (job_id = @job_id)
                      AND (server_id = 0))
    FROM msdb.dbo.sysjobs_view
    WHERE (job_id = @job_id)

    -- Check if we have any work to do
    IF (NOT EXISTS (SELECT *
                    FROM #temp_jobs_to_delete))
    BEGIN
      DROP TABLE #temp_jobs_to_delete
      RETURN(0) -- Success
    END

    -- Post the delete to any target servers (need to do this BEFORE
    -- deleting the job itself, but AFTER clearing all all pending
    -- download instructions).  Note that if the job is NOT a
    -- multi-server job then sp_post_msx_operation will catch this and
    -- will do nothing. Since it will do nothing that is why we need
    -- to NOT delete any pending delete requests, because that delete
    -- request might have been for the last target server and thus
    -- this job isn't a multi-server job anymore so posting the global
    -- delete would do nothing.
    DELETE FROM msdb.dbo.sysdownloadlist
    WHERE (object_id = @job_id)
      and (operation_code != 3) -- Delete
    EXECUTE msdb.dbo.sp_post_msx_operation 'DELETE', 'JOB', @job_id

    -- Must do this before deleting the job itself since sp_sqlagent_notify does a lookup on sysjobs_view
    -- Note: Don't notify agent in this call. It is done after the transaction is committed
    --       just in case this job is in the process of deleting itself
    EXECUTE msdb.dbo.sp_delete_job_references @notify_sqlagent = 0

    -- Delete all traces of the job
    BEGIN TRANSACTION

   --Get the schedules to delete before deleting records from sysjobschedules
    IF(@delete_unused_schedule = 1)
    BEGIN
        --Get the list of schedules to delete
        INSERT INTO @temp_schedules_to_delete
        SELECT DISTINCT schedule_id 
        FROM   msdb.dbo.sysschedules
        WHERE (schedule_id IN 
                (SELECT schedule_id
                FROM msdb.dbo.sysjobschedules
                WHERE (job_id = @job_id)))
    END


    DELETE FROM msdb.dbo.sysjobschedules
    WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)
    
    DELETE FROM msdb.dbo.sysjobservers
    WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)

    DELETE FROM msdb.dbo.sysjobsteps
    WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)

    DELETE FROM msdb.dbo.sysjobs
    WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)
    
    --Delete the schedule(s) if requested to and it isn't being used by other jobs
    IF(@delete_unused_schedule = 1)
    BEGIN
      --Now OK to delete the schedule
      DELETE FROM msdb.dbo.sysschedules
      WHERE schedule_id IN 
        (SELECT schedule_id
         FROM @temp_schedules_to_delete as sdel
         WHERE NOT EXISTS(SELECT * 
                          FROM msdb.dbo.sysjobschedules AS js
                          WHERE (js.schedule_id = sdel.schedule_id)))
    END


    -- Delete the job history if requested    
    IF (@delete_history = 1)
    BEGIN
      DELETE FROM msdb.dbo.sysjobhistory
      WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)
    END
    -- All done
    COMMIT TRANSACTION

    -- Now notify agent to delete the job.
    IF(EXISTS(SELECT * FROM #temp_jobs_to_delete WHERE job_is_cached > 0))
    BEGIN
      DECLARE @nt_user_name   NVARCHAR(100)
      SELECT @nt_user_name = ISNULL(NT_CLIENT(), ISNULL(SUSER_SNAME(), FORMATMESSAGE(14205)))
      --Call the xp directly. sp_sqlagent_notify checks sysjobs_view and the record has already been deleted
      EXEC master.dbo.xp_sqlagent_notify N'J', @job_id, 0, 0, N'D', @nt_user_name, 1, @@trancount, NULL, NULL
    END

  END
  ELSE
  -- Do the delete (for all jobs originating from the specific server)
  IF (@originating_server IS NOT NULL)
  BEGIN
    EXECUTE msdb.dbo.sp_delete_all_msx_jobs @msx_server = @originating_server

    -- NOTE: In this case there is no need to propagate the delete via sp_post_msx_operation
    --       since this type of delete is only ever performed on a TSX.
  END

  IF (OBJECT_ID(N'tempdb.dbo.#temp_jobs_to_delete', 'U') IS NOT NULL)	
    DROP TABLE #temp_jobs_to_delete

  RETURN(0) -- 0 means success
END
go

/**************************************************************/
/* SP_SQLAGENT_IS_SRVROLEMEMBER                               */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_sqlagent_is_srvrolemember...'
go

ALTER PROCEDURE sp_sqlagent_is_srvrolemember
   @role_name sysname, @login_name sysname
AS
BEGIN
  DECLARE @is_member        INT
  SET NOCOUNT ON
  
  IF @role_name IS NULL OR @login_name IS NULL
    RETURN(0)
  
  SELECT @is_member = 0
  --IS_SRVROLEMEMBER works only if the login to be tested is provisioned with sqlserver
  if( @login_name = SUSER_SNAME())
    SELECT @is_member = IS_SRVROLEMEMBER(@role_name)
  else
    SELECT @is_member = IS_SRVROLEMEMBER(@role_name, @login_name)
    
  
  --try to impersonate. A try catch is used because we can have @name as NT groups also
  IF @is_member IS NULL
  BEGIN
    BEGIN TRY
      if( is_srvrolemember('sysadmin') = 1)
      begin
      EXECUTE AS LOGIN = @login_name -- impersonate 
        SELECT @is_member = IS_SRVROLEMEMBER(@role_name)  -- check role membership 
      REVERT -- revert back
      end
    END TRY
    BEGIN CATCH
      SELECT @is_member = 0
    END CATCH
  END
 
  RETURN ISNULL(@is_member,0)
END
GO

/**************************************************************/
/* sp_verify_jobstep                                          */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_verify_jobstep...'
go

ALTER PROCEDURE sp_verify_jobstep
  @job_id             UNIQUEIDENTIFIER,
  @step_id            INT,
  @step_name          sysname,
  @subsystem          NVARCHAR(40),
  @command            NVARCHAR(max),
  @server             sysname,
  @on_success_action  TINYINT,
  @on_success_step_id INT,
  @on_fail_action     TINYINT,
  @on_fail_step_id    INT,
  @os_run_priority    INT,
  @database_name      sysname OUTPUT,
  @database_user_name sysname OUTPUT,
  @flags              INT,
  @output_file_name   NVARCHAR(200),
  @proxy_id         INT 
AS
BEGIN
  DECLARE @max_step_id             INT
  DECLARE @retval                  INT
  DECLARE @valid_values            VARCHAR(50)
  DECLARE @database_name_temp      sysname
  DECLARE @database_user_name_temp sysname
  DECLARE @temp_command            NVARCHAR(max)
  DECLARE @iPos                    INT
  DECLARE @create_count            INT
  DECLARE @destroy_count           INT
  DECLARE @is_olap_subsystem       BIT
  DECLARE @owner_sid               VARBINARY(85)
  DECLARE @owner_name              sysname
  -- Remove any leading/trailing spaces from parameters
  SELECT @subsystem        = LTRIM(RTRIM(@subsystem))
  SELECT @server           = LTRIM(RTRIM(@server))
  SELECT @output_file_name = LTRIM(RTRIM(@output_file_name))

  -- Get current maximum step id
  SELECT @max_step_id = ISNULL(MAX(step_id), 0)
  FROM msdb.dbo.sysjobsteps
  WHERE (job_id = @job_id)

  -- Check step id
  IF (@step_id < 1) OR (@step_id > @max_step_id + 1)
  BEGIN
    SELECT @valid_values = '1..' + CONVERT(VARCHAR, @max_step_id + 1)
    RAISERROR(14266, -1, -1, '@step_id', @valid_values)
    RETURN(1) -- Failure
  END

  -- Check subsystem
  EXECUTE @retval = sp_verify_subsystem @subsystem
  IF (@retval <> 0)
    RETURN(1) -- Failure
  

  --check if proxy is allowed for this subsystem for current user
  IF (@proxy_id IS NOT NULL)
  BEGIN
    --get the job owner
    SELECT @owner_sid = owner_sid FROM sysjobs
    WHERE  job_id = @job_id
    IF @owner_sid = 0xFFFFFFFF
    BEGIN
      --ask to verify for the special account
      EXECUTE @retval = sp_verify_proxy_permissions 
        @subsystem_name = @subsystem, 
        @proxy_id = @proxy_id, 
        @name = NULL, 
        @raise_error = 1, 
        @allow_disable_proxy = 1, 
        @verify_special_account = 1
      IF (@retval <> 0)
        RETURN(1) -- Failure
    END
    ELSE
    BEGIN
      SELECT @owner_name = SUSER_SNAME(@owner_sid)
      EXECUTE @retval = sp_verify_proxy_permissions 
      @subsystem_name = @subsystem, 
      @proxy_id = @proxy_id, 
      @name = @owner_name, 
      @raise_error = 1, 
      @allow_disable_proxy = 1
      IF (@retval <> 0)
        RETURN(1) -- Failure
    END
  END

  --Only sysadmin can specify @output_file_name 
  IF (@output_file_name IS NOT NULL) AND  (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1)
  BEGIN
    RAISERROR(14582, -1, -1)
    RETURN(1) -- Failure    
  END

  --Determmine if this is a olap subsystem jobstep
  IF ( UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) in (N'ANALYSISQUERY', N'ANALYSISCOMMAND') )
    SELECT @is_olap_subsystem = 1
  ELSE
    SELECT @is_olap_subsystem = 0

  -- Check command length
  -- not necessary now, command can be any length
/*
  IF ((DATALENGTH(@command) / 2) > 3200)
  BEGIN
    RAISERROR(14250, 16, 1, '@command', 3200)
    RETURN(1) -- Failure
  END
*/
  -- For a VBScript command, check that object creations are paired with object destructions
  IF ((UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) = N'ACTIVESCRIPTING') AND (@database_name = N'VBScript'))
  BEGIN
    SELECT @temp_command = @command

    SELECT @create_count = 0
    SELECT @iPos = PATINDEX('%[Cc]reate[Oo]bject[ (]%', @temp_command)
    WHILE(@iPos > 0)
    BEGIN
      SELECT @temp_command = SUBSTRING(@temp_command, @iPos + 1, DATALENGTH(@temp_command) / 2)
      SELECT @iPos = PATINDEX('%[Cc]reate[Oo]bject[ (]%', @temp_command)
      SELECT @create_count = @create_count + 1
    END

    SELECT @destroy_count = 0
    SELECT @iPos = PATINDEX('%[Ss]et %=%[Nn]othing%', @temp_command)
    WHILE(@iPos > 0)
    BEGIN
      SELECT @temp_command = SUBSTRING(@temp_command, @iPos + 1, DATALENGTH(@temp_command) / 2)
      SELECT @iPos = PATINDEX('%[Ss]et %=%[Nn]othing%', @temp_command)
      SELECT @destroy_count = @destroy_count + 1
    END

    IF(@create_count > @destroy_count)
    BEGIN
      RAISERROR(14277, -1, -1)
      RETURN(1) -- Failure
    END
  END

  -- Check step name
  IF (EXISTS (SELECT *
              FROM msdb.dbo.sysjobsteps
              WHERE (job_id = @job_id)
                AND (step_name = @step_name)))
  BEGIN
    RAISERROR(14261, -1, -1, '@step_name', @step_name)
    RETURN(1) -- Failure
  END

  -- Check on-success action/step
  IF (@on_success_action <> 1) AND -- Quit Qith Success
     (@on_success_action <> 2) AND -- Quit Qith Failure
     (@on_success_action <> 3) AND -- Goto Next Step
     (@on_success_action <> 4)     -- Goto Step
  BEGIN
    RAISERROR(14266, -1, -1, '@on_success_action', '1, 2, 3, 4')
    RETURN(1) -- Failure
  END
  IF (@on_success_action = 4) AND
     ((@on_success_step_id < 1) OR (@on_success_step_id = @step_id))
  BEGIN
    -- NOTE: We allow forward references to non-existant steps to prevent the user from
    --       having to make a second update pass to fix up the flow
    RAISERROR(14235, -1, -1, '@on_success_step', @step_id)
    RETURN(1) -- Failure
  END

  -- Check on-fail action/step
  IF (@on_fail_action <> 1) AND -- Quit Qith Success
     (@on_fail_action <> 2) AND -- Quit Qith Failure
     (@on_fail_action <> 3) AND -- Goto Next Step
     (@on_fail_action <> 4)     -- Goto Step
  BEGIN
    RAISERROR(14266, -1, -1, '@on_failure_action', '1, 2, 3, 4')
    RETURN(1) -- Failure
  END
  IF (@on_fail_action = 4) AND
     ((@on_fail_step_id < 1) OR (@on_fail_step_id = @step_id))
  BEGIN
    -- NOTE: We allow forward references to non-existant steps to prevent the user from
    --       having to make a second update pass to fix up the flow
    RAISERROR(14235, -1, -1, '@on_failure_step', @step_id)
    RETURN(1) -- Failure
  END

  -- Warn the user about forward references
  IF ((@on_success_action = 4) AND (@on_success_step_id > @max_step_id))
    RAISERROR(14236, 0, 1, '@on_success_step_id')
  IF ((@on_fail_action = 4) AND (@on_fail_step_id > @max_step_id))
    RAISERROR(14236, 0, 1, '@on_fail_step_id')

  --Special case the olap subsystem. It can have any server name. 
  --Default it to the local server if @server is null 
  IF(@is_olap_subsystem = 1)
  BEGIN
    IF(@server IS NULL)
    BEGIN
    --TODO: needs error better message ? >> 'Specify the OLAP server name in the %s parameter'
      --Must specify the olap server name
      RAISERROR(14262, -1, -1, '@server', @server)
      RETURN(1) -- Failure    
    END
  END
  ELSE
  BEGIN
    -- Check server (this is the replication server, NOT the job-target server)
    IF (@server IS NOT NULL) AND (NOT EXISTS (SELECT *
                                              FROM master.dbo.sysservers
                                              WHERE (UPPER(srvname) = UPPER(@server))))
    BEGIN
      RAISERROR(14234, -1, -1, '@server', 'sp_helpserver')
      RETURN(1) -- Failure
    END
  END

  -- Check run priority: must be a valid value to pass to SetThreadPriority:
  -- [-15 = IDLE, -1 = BELOW_NORMAL, 0 = NORMAL, 1 = ABOVE_NORMAL, 15 = TIME_CRITICAL]
  IF (@os_run_priority NOT IN (-15, -1, 0, 1, 15))
  BEGIN
    RAISERROR(14266, -1, -1, '@os_run_priority', '-15, -1, 0, 1, 15')
    RETURN(1) -- Failure
  END

  -- Check flags
  IF ((@flags < 0) OR (@flags > 50))
  BEGIN
    RAISERROR(14266, -1, -1, '@flags', '0..50')
    RETURN(1) -- Failure
  END

  -- Check output file
  IF (@output_file_name IS NOT NULL) AND (UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) NOT IN ('TSQL', 'CMDEXEC', 'ANALYSISQUERY', 'ANALYSISCOMMAND', 'SSIS' ))
  BEGIN
    RAISERROR(14545, -1, -1, '@output_file_name', @subsystem)
    RETURN(1) -- Failure
  END

  -- Check writing to table flags
  IF (@flags IS NOT NULL) AND (((@flags & 8) <> 0) OR ((@flags & 16) <> 0)) AND (UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) NOT IN ('TSQL', 'CMDEXEC', 'ANALYSISQUERY', 'ANALYSISCOMMAND', 'SSIS' ))
  BEGIN
    RAISERROR(14545, -1, -1, '@flags', @subsystem)
    RETURN(1) -- Failure
  END

  -- For CmdExec steps database-name and database-user-name should both be null
  IF (UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) = N'CMDEXEC')
    SELECT @database_name = NULL,
           @database_user_name = NULL

  -- For non-TSQL steps, database-user-name should be null
  IF (UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) <> 'TSQL')
    SELECT @database_user_name = NULL

  -- For a TSQL step, get (and check) the username of the caller in the target database.
  IF (UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) = 'TSQL')
  BEGIN
    SET NOCOUNT ON

    -- But first check if remote server name has been supplied
    IF (@server IS NOT NULL)
      SELECT @server = NULL

    -- Default database to 'master' if not supplied
    IF (LTRIM(RTRIM(@database_name)) IS NULL)
      SELECT @database_name = N'master'

    -- Check the database (although this is no guarantee that @database_user_name can access it)
    IF (DB_ID(@database_name) IS NULL)
    BEGIN
      RAISERROR(14262, -1, -1, '@database_name', @database_name)
      RETURN(1) -- Failure
    END

    SELECT @database_user_name = LTRIM(RTRIM(@database_user_name))

    -- Only if a SysAdmin is creating the job can the database user name be non-NULL [since only
    -- SysAdmin's can call SETUSER].
    -- NOTE: In this case we don't try to validate the user name (it's too costly to do so)
    --       so if it's bad we'll get a runtime error when the job executes.
    IF (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 1)
    BEGIN
      -- If this is a multi-server job then @database_user_name must be null
      IF (@database_user_name IS NOT NULL)
      BEGIN
        IF (EXISTS (SELECT *
                    FROM msdb.dbo.sysjobs       sj,
                         msdb.dbo.sysjobservers sjs
                    WHERE (sj.job_id = sjs.job_id)
                      AND (sj.job_id = @job_id)
                      AND (sjs.server_id <> 0)))
        BEGIN
          RAISERROR(14542, -1, -1, N'database_user_name')
          RETURN(1) -- Failure
        END
      END

      -- For a SQL-user, check if it exists
      IF (@database_user_name NOT LIKE N'%\%')
      BEGIN
        SELECT @database_user_name_temp = REPLACE(@database_user_name, N'''', N'''''')
        SELECT @database_name_temp = REPLACE(@database_name, N'''', N'''''')

        EXECUTE(N'DECLARE @ret INT
                  SELECT @ret = COUNT(*)
                  FROM ' + @database_name_temp + N'.dbo.sysusers
                  WHERE (name = N''' + @database_user_name_temp + N''')
                  HAVING (COUNT(*) > 0)')
        IF (@@ROWCOUNT = 0)
        BEGIN
          RAISERROR(14262, -1, -1, '@database_user_name', @database_user_name)
          RETURN(1) -- Failure
        END
      END
    END
    ELSE
      SELECT @database_user_name = NULL

  END  -- End of TSQL property verification

  RETURN(0) -- Success
END
go

 
/**************************************************************/
/* sysmail_delete_mailitems_sp                                */
/**************************************************************/
-----
PRINT 'Updating sysmail_delete_mailitems_sp'
-----
GO
ALTER PROCEDURE sysmail_delete_mailitems_sp
   @sent_before DATETIME   = NULL, -- sent before
   @sent_status varchar(8)   = NULL -- sent status
AS
BEGIN

   SET @sent_status       = LTRIM(RTRIM(@sent_status))
   IF @sent_status           = '' SET @sent_status = NULL

   IF ( (@sent_status IS NOT NULL) AND
         (LOWER(@sent_status collate SQL_Latin1_General_CP1_CS_AS) NOT IN ( 'unsent', 'sent', 'failed', 'retrying') ) )
   BEGIN
      RAISERROR(14266, -1, -1, '@sent_status', 'unsent, sent, failed, retrying')
      RETURN(1) -- Failure
   END

   IF ( @sent_before IS NULL AND @sent_status IS NULL )
   BEGIN
      RAISERROR(14608, -1, -1, '@sent_before', '@sent_status')  
      RETURN(1) -- Failure
   END

   DELETE FROM msdb.dbo.sysmail_allitems 
   WHERE 
        ((@sent_before IS NULL) OR ( send_request_date < @sent_before))
   AND ((@sent_status IS NULL) OR (sent_status = @sent_status))

   DECLARE @localmessage nvarchar(255)
    SET @localmessage = FORMATMESSAGE(14665, SUSER_SNAME(), @@ROWCOUNT)
    exec msdb.dbo.sysmail_logmailevent_sp @event_type=1, @description=@localmessage

END
GO

/**************************************************************/
/* sp_sysmail_activate                                */
/**************************************************************/
-----
PRINT 'Updating procedure sp_sysmail_activate'
-----
GO
-- sp_sysmail_activate : Starts the DatabaseMail process if it isn't already running
--
ALTER PROCEDURE sp_sysmail_activate
AS
BEGIN
    DECLARE @mailDbName sysname
    DECLARE @mailDbId INT
    DECLARE @mailEngineLifeMin INT
    DECLARE @loggingLevel nvarchar(256)
    DECLARE @loggingLevelInt int   
    DECLARE @parameter_value nvarchar(256)
    DECLARE @localmessage nvarchar(max)
    DECLARE @rc INT

    SET NOCOUNT ON
    EXEC sp_executesql @statement = N'RECEIVE TOP(0) * FROM msdb.dbo.ExternalMailQueue'

    EXEC @rc = msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'DatabaseMailExeMinimumLifeTime', 
                                                        @parameter_value = @parameter_value OUTPUT
    IF(@rc <> 0)
        RETURN (1)

    --ConvertToInt will return the default if @parameter_value is null or config value can't be converted
    --Setting max exe lifetime is 1 week (604800 secs). Can't see a reason for it to ever run longer that this
    SET @mailEngineLifeMin = dbo.ConvertToInt(@parameter_value, 604800, 600) 
    
    --Try and get the optional logging level for the DatabaseMail process
    EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'LoggingLevel', 
                                                  @parameter_value = @loggingLevel OUTPUT

    --Convert logging level into string value for passing into XP
    SET @loggingLevelInt = dbo.ConvertToInt(@loggingLevel, 3, 2) 
    IF @loggingLevelInt = 1
       SET @loggingLevel = 'Normal'
    ELSE IF @loggingLevelInt = 3
       SET @loggingLevel = 'Verbose'
    ELSE -- default
       SET @loggingLevel = 'Extended'

    SET @mailDbName = DB_NAME() 
    SET @mailDbId   = DB_ID()

    EXEC @rc = master..xp_sysmail_activate @mailDbId, @mailDbName, @mailEngineLifeMin, @loggingLevel
    IF(@rc <> 0)
    BEGIN
        SET @localmessage = FORMATMESSAGE(14637)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage
    END
    ELSE
    BEGIN
        SET @localmessage = FORMATMESSAGE(14638)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=0, @description=@localmessage
    END

    RETURN @rc
END
GO

/**************************************************************/
/* Update the RunMailQuery stored procedure          */
/**************************************************************/
/****** Object:  StoredProcedure [dbo].[sp_RunMailQuery]    Script Date: 06/06/2006 12:26:03 ******/
use msdb
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
ALTER PROCEDURE [dbo].[sp_RunMailQuery]
   @query                    NVARCHAR(max),
   @attach_results             BIT,
    @query_attachment_filename  NVARCHAR(260) = NULL,
   @no_output                  BIT,
   @query_result_header        BIT,
   @separator                  VARCHAR(1),
   @echo_error                 BIT,
   @dbuse                      sysname,
   @width                   INT,
    @temp_table_uid             uniqueidentifier,
   @query_no_truncate          BIT,
   @query_result_no_padding             BIT
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER ON

    DECLARE @rc             INT,
            @prohibitedExts NVARCHAR(1000),
            @fileSizeStr    NVARCHAR(256),
            @fileSize       INT,
            @attach_res_int INT,
            @no_output_int  INT,
            @no_header_int  INT,
            @echo_error_int INT,
         @query_no_truncate_int INT,
         @query_result_no_padding_int   INT,
            @mailDbName     sysname,
            @uid            uniqueidentifier,
            @uidStr         VARCHAR(36)

    --
    --Get config settings and verify parameters
    --
    SET @query_attachment_filename = LTRIM(RTRIM(@query_attachment_filename))

    --Get the maximum file size allowed for attachments from sysmailconfig.
    EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'MaxFileSize', 
                                                @parameter_value = @fileSizeStr OUTPUT
    --ConvertToInt will return the default if @fileSizeStr is null
    SET @fileSize = dbo.ConvertToInt(@fileSizeStr, 0x7fffffff, 100000)

    IF (@attach_results = 1)
    BEGIN
        --Need this if attaching the query
        EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'ProhibitedExtensions', 
                                                    @parameter_value = @prohibitedExts OUTPUT

        -- If attaching query results to a file and a filename isn't given create one
        IF ((@query_attachment_filename IS NOT NULL) AND (LEN(@query_attachment_filename) > 0))
        BEGIN 
          EXEC @rc = sp_isprohibited @query_attachment_filename, @prohibitedExts
          IF (@rc <> 0)
          BEGIN
              RAISERROR(14630, 16, 1, @query_attachment_filename, @prohibitedExts)
              RETURN 2
          END
        END
        ELSE
        BEGIN
            --If queryfilename is not specified, generate a random name (doesn't have to be unique)
           SET @query_attachment_filename = 'QueryResults' + CONVERT(varchar, ROUND(RAND() * 1000000, 0)) + '.txt'
        END
    END

    --Init variables used in the query execution
    SET @mailDbName = db_name()
    SET @uidStr = convert(varchar(36), @temp_table_uid)

    SET @attach_res_int        = CONVERT(int, @attach_results)
    SET @no_output_int         = CONVERT(int, @no_output)
    IF(@query_result_header = 0) SET @no_header_int  = 1 ELSE SET @no_header_int  = 0
    SET @echo_error_int        = CONVERT(int, @echo_error)
    SET @query_no_truncate_int = CONVERT(int, @query_no_truncate)
    SET @query_result_no_padding_int = CONVERT(int, @query_result_no_padding )

    EXEC @rc = master..xp_sysmail_format_query  
                @query        = @query,
                @message      = @mailDbName,
                    @subject     = @uidStr,
                    @dbuse       = @dbuse, 
                    @attachments = @query_attachment_filename,
                    @attach_results = @attach_res_int,
                    -- format params
                    @separator      = @separator,
                    @no_header      = @no_header_int,
                    @no_output      = @no_output_int,
                    @echo_error     = @echo_error_int,
                @max_attachment_size = @fileSize,
                    @width       = @width, 
                    @query_no_truncate = @query_no_truncate_int,
                    @query_result_no_padding    = @query_result_no_padding_int
   RETURN @rc
END
GO

use msdb
GO
/****** Object:  StoredProcedure [dbo].[sp_send_dbmail]    Script Date: 06/06/2006 12:24:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
-- sp_sendemail : Sends a mail from Yukon outbox.
--
ALTER PROCEDURE [dbo].[sp_send_dbmail]
   @profile_name               sysname    = NULL,        
   @recipients                 VARCHAR(MAX)  = NULL, 
   @copy_recipients            VARCHAR(MAX)  = NULL,
   @blind_copy_recipients      VARCHAR(MAX)  = NULL,
   @subject                    NVARCHAR(255) = NULL,
   @body                       NVARCHAR(MAX) = NULL, 
   @body_format                VARCHAR(20)      = NULL, 
   @importance                 VARCHAR(6)    = 'NORMAL',
   @sensitivity                VARCHAR(12)      = 'NORMAL',
   @file_attachments           NVARCHAR(MAX) = NULL,  
   @query                      NVARCHAR(MAX) = NULL,
   @execute_query_database     sysname    = NULL,  
   @attach_query_result_as_file BIT    = 0,
        @query_attachment_filename  NVARCHAR(260)  = NULL,  
        @query_result_header        BIT         = 1,
   @query_result_width         INT        = 256,            
   @query_result_separator     CHAR(1)    = ' ',
   @exclude_query_output       BIT        = 0,
   @append_query_error         BIT        = 0,
   @query_no_truncate          BIT        = 0,
   @query_result_no_padding            BIT        = 0,
   @mailitem_id               INT         = NULL OUTPUT
  WITH EXECUTE AS 'dbo'
AS
BEGIN
    SET NOCOUNT ON

    -- And make sure ARITHABORT is on. This is the default for yukon DB's
    SET ARITHABORT ON

    --Declare variables used by the procedure internally
    DECLARE @profile_id         INT,
            @temp_table_uid     uniqueidentifier,
            @sendmailxml        VARCHAR(max),
            @CR_str             NVARCHAR(2),
            @localmessage       NVARCHAR(255),
            @QueryResultsExist  INT,
            @AttachmentsExist   INT,
            @RetErrorMsg        NVARCHAR(4000), --Impose a limit on the error message length to avoid memory abuse 
            @rc                 INT,
            @procName           sysname,
       @trancountSave      INT,
       @tranStartedBool    INT,
            @is_sysadmin        BIT,
            @send_request_user  sysname,
            @database_user_id   INT

    -- Initialize 
    SELECT  @rc                 = 0,
            @QueryResultsExist  = 0,
            @AttachmentsExist   = 0,
            @temp_table_uid     = NEWID(),
            @procName           = OBJECT_NAME(@@PROCID),
            @tranStartedBool  = 0,
       @trancountSave      = @@TRANCOUNT

    EXECUTE AS CALLER
       SELECT @is_sysadmin       = IS_SRVROLEMEMBER('sysadmin'),
              @send_request_user = SUSER_SNAME(),
              @database_user_id  = USER_ID()
    REVERT

    --Check if SSB is enabled in this database
    IF (ISNULL(DATABASEPROPERTYEX(DB_NAME(), N'IsBrokerEnabled'), 0) <> 1)
    BEGIN
       RAISERROR(14650, 16, 1)
       RETURN 1
    END

    --Report error if the mail queue has been stopped. 
    --sysmail_stop_sp/sysmail_start_sp changes the receive status of the SSB queue
    IF NOT EXISTS (SELECT * FROM sys.service_queues WHERE name = N'ExternalMailQueue' AND is_receive_enabled = 1)
    BEGIN
       RAISERROR(14641, 16, 1)
       RETURN 1
    END

    -- Get the relevant profile_id 
    --
    IF (@profile_name IS NULL)
    BEGIN
        -- Use the global or users default if profile name is not supplied
        SELECT TOP (1) @profile_id = pp.profile_id
        FROM msdb.dbo.sysmail_principalprofile as pp
        WHERE (pp.is_default = 1) AND
            (dbo.get_principal_id(pp.principal_sid) = @database_user_id OR pp.principal_sid = 0x00)
        ORDER BY dbo.get_principal_id(pp.principal_sid) DESC

        --Was a profile found
        IF(@profile_id IS NULL)
        BEGIN
           RAISERROR(14636, 16, 1)
           RETURN 1
        END
    END
    ELSE
    BEGIN
        --Get primary account if profile name is supplied
        EXEC @rc = msdb.dbo.sysmail_verify_profile_sp @profile_id = NULL, 
                         @profile_name = @profile_name, 
                         @allow_both_nulls = 0, 
                         @allow_id_name_mismatch = 0,
                         @profileid = @profile_id OUTPUT
        IF (@rc <> 0)
            RETURN @rc

        --Make sure this user has access to the specified profile.
        --sysadmins can send on any profiles
        IF ( @is_sysadmin <> 1)
        BEGIN
            --Not a sysadmin so check users access to profile
            iF NOT EXISTS(SELECT * 
                        FROM msdb.dbo.sysmail_principalprofile 
                        WHERE ((profile_id = @profile_id) AND
                                (dbo.get_principal_id(principal_sid) = @database_user_id OR principal_sid = 0x00)))
            BEGIN
               RAISERROR(14607, -1, -1, 'profile')
               RETURN 1
            END
        END
    END

    --Attach results must be specified
    IF @attach_query_result_as_file IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'attach_query_result_as_file')
       RETURN 2
    END

    --No output must be specified
    IF @exclude_query_output IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'exclude_query_output')
       RETURN 3
    END

    --No header must be specified
    IF @query_result_header IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'query_result_header')
       RETURN 4
    END

    -- Check if query_result_separator is specifed
    IF @query_result_separator IS NULL OR DATALENGTH(@query_result_separator) = 0
    BEGIN
       RAISERROR(14618, 16, 1, 'query_result_separator')
       RETURN 5
    END

    --Echo error must be specified
    IF @append_query_error IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'append_query_error')
       RETURN 6
    END

    --@body_format can be TEXT (default) or HTML
    IF (@body_format IS NULL)
    BEGIN
       SET @body_format = 'TEXT'
    END
    ELSE
    BEGIN
       SET @body_format = UPPER(@body_format)

       IF @body_format NOT IN ('TEXT', 'HTML') 
       BEGIN
          RAISERROR(14626, 16, 1, @body_format)
          RETURN 13
       END
    END

    --Importance must be specified
    IF @importance IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'importance')
       RETURN 15
    END

    SET @importance = UPPER(@importance)

    --Importance must be one of the predefined values
    IF @importance NOT IN ('LOW', 'NORMAL', 'HIGH')
    BEGIN
       RAISERROR(14622, 16, 1, @importance)
       RETURN 16
    END

    --Sensitivity must be specified
    IF @sensitivity IS NULL
    BEGIN
       RAISERROR(14618, 16, 1, 'sensitivity')
       RETURN 17
    END

    SET @sensitivity = UPPER(@sensitivity)

    --Sensitivity must be one of predefined values
    IF @sensitivity NOT IN ('NORMAL', 'PERSONAL', 'PRIVATE', 'CONFIDENTIAL')
    BEGIN
       RAISERROR(14623, 16, 1, @sensitivity)
       RETURN 18
    END

    --Message body cannot be null. Atleast one of message, subject, query,
    --attachments must be specified.
    IF( (@body IS NULL AND @query IS NULL AND @file_attachments IS NULL AND @subject IS NULL)
       OR
    ( (LEN(@body) IS NULL OR LEN(@body) <= 0)  
       AND (LEN(@query) IS NULL  OR  LEN(@query) <= 0)
       AND (LEN(@file_attachments) IS NULL OR LEN(@file_attachments) <= 0)
       AND (LEN(@subject) IS NULL OR LEN(@subject) <= 0)
    )
    )
    BEGIN
       RAISERROR(14624, 16, 1, '@body, @query, @file_attachments, @subject')
       RETURN 19
    END   
    ELSE
       IF @subject IS NULL OR LEN(@subject) <= 0
          SET @subject='SQL Server Message'

    --Recipients cannot be empty. Atleast one of the To, Cc, Bcc must be specified
    IF ( (@recipients IS NULL AND @copy_recipients IS NULL AND 
       @blind_copy_recipients IS NULL
        )     
       OR
        ( (LEN(@recipients) IS NULL OR LEN(@recipients) <= 0)
       AND (LEN(@copy_recipients) IS NULL OR LEN(@copy_recipients) <= 0)
       AND (LEN(@blind_copy_recipients) IS NULL OR LEN(@blind_copy_recipients) <= 0)
        )
    )
    BEGIN
       RAISERROR(14624, 16, 1, '@recipients, @copy_recipients, @blind_copy_recipients')
       RETURN 20
    END

    --If query is not specified, attach results and no header cannot be true.
    IF ( (@query IS NULL OR LEN(@query) <= 0) AND @attach_query_result_as_file = 1)
    BEGIN
       RAISERROR(14625, 16, 1)
       RETURN 21
    END

    --
    -- Execute Query if query is specified
    IF ((@query IS NOT NULL) AND (LEN(@query) > 0))
    BEGIN
        EXECUTE AS CALLER
        EXEC @rc = sp_RunMailQuery 
                    @query                     = @query,
               @attach_results            = @attach_query_result_as_file,
                    @query_attachment_filename = @query_attachment_filename,
               @no_output                 = @exclude_query_output,
               @query_result_header       = @query_result_header,
               @separator                 = @query_result_separator,
               @echo_error                = @append_query_error,
               @dbuse                     = @execute_query_database,
               @width                     = @query_result_width,
                @temp_table_uid            = @temp_table_uid,
            @query_no_truncate         = @query_no_truncate,
            @query_result_no_padding           = @query_result_no_padding
      -- This error indicates that query results size was over the configured MaxFileSize.
      -- Note, an error has already beed raised in this case
      IF(@rc = 101)
         GOTO ErrorHandler;
         REVERT
 
         -- Always check the transfer tables for data. They may also contain error messages
         -- Only one of the tables receives data in the call to sp_RunMailQuery
         IF(@attach_query_result_as_file = 1)
         BEGIN
             IF EXISTS(SELECT * FROM sysmail_attachments_transfer WHERE uid = @temp_table_uid)
            SET @AttachmentsExist = 1
         END
         ELSE
         BEGIN
             IF EXISTS(SELECT * FROM sysmail_query_transfer WHERE uid = @temp_table_uid AND uid IS NOT NULL)
            SET @QueryResultsExist = 1
         END

         -- Exit if there was an error and caller doesn't want the error appended to the mail
         IF (@rc <> 0 AND @append_query_error = 0)
         BEGIN
            --Error msg with be in either the attachment table or the query table 
            --depending on the setting of @attach_query_result_as_file
            IF(@attach_query_result_as_file = 1)
            BEGIN
               --Copy query results from the attachments table to mail body
               SELECT @RetErrorMsg = CONVERT(NVARCHAR(4000), attachment)
               FROM sysmail_attachments_transfer 
               WHERE uid = @temp_table_uid
            END
            ELSE
            BEGIN
               --Copy query results from the query table to mail body
               SELECT @RetErrorMsg = text_data 
               FROM sysmail_query_transfer 
               WHERE uid = @temp_table_uid
            END

            GOTO ErrorHandler;
         END
         SET @AttachmentsExist = @attach_query_result_as_file
    END
    ELSE
    BEGIN
        --If query is not specified, attach results cannot be true.
        IF (@attach_query_result_as_file = 1)
        BEGIN
           RAISERROR(14625, 16, 1)
           RETURN 21
        END
    END

    --Get the prohibited extensions for attachments from sysmailconfig.
    IF ((@file_attachments IS NOT NULL) AND (LEN(@file_attachments) > 0)) 
    BEGIN
        EXECUTE AS CALLER
        EXEC @rc = sp_GetAttachmentData 
                        @attachments = @file_attachments, 
                        @temp_table_uid = @temp_table_uid,
                        @exclude_query_output = @exclude_query_output
        REVERT
        IF (@rc <> 0)
            GOTO ErrorHandler;
        
        IF EXISTS(SELECT * FROM sysmail_attachments_transfer WHERE uid = @temp_table_uid)
            SET @AttachmentsExist = 1
    END

    -- Start a transaction if not already in one. 
    -- Note: For rest of proc use GOTO ErrorHandler for falures  
    if (@trancountSave = 0) 
       BEGIN TRAN @procName

    SET @tranStartedBool = 1

    -- Store complete mail message for history/status purposes  
    INSERT sysmail_mailitems
    (
       profile_id,   
       recipients,
       copy_recipients,
       blind_copy_recipients,
       subject,
       body, 
       body_format, 
       importance,
       sensitivity,
       file_attachments,  
       attachment_encoding,
       query,
       execute_query_database,
       attach_query_result_as_file,
       query_result_header,
       query_result_width,          
       query_result_separator,
       exclude_query_output,
       append_query_error,
            send_request_user
    )
    VALUES
    (
       @profile_id,        
       @recipients, 
       @copy_recipients,
       @blind_copy_recipients,
       @subject,
       @body, 
       @body_format, 
       @importance,
       @sensitivity,
       @file_attachments,  
       'MIME',
       @query,
       @execute_query_database,  
       @attach_query_result_as_file,
       @query_result_header,
       @query_result_width,            
       @query_result_separator,
       @exclude_query_output,
       @append_query_error,
            @send_request_user
    )

    SELECT @rc          = @@ERROR,
           @mailitem_id = @@IDENTITY

    IF(@rc <> 0)
        GOTO ErrorHandler;

    --Copy query into the message body
    IF(@QueryResultsExist = 1)
    BEGIN
      -- if the body is null initialize it
        UPDATE sysmail_mailitems
        SET body = N''
        WHERE mailitem_id = @mailitem_id
        AND body is null

        --Add CR    
        SET @CR_str = CHAR(13) + CHAR(10)
        UPDATE sysmail_mailitems
        SET body.WRITE(@CR_str, NULL, NULL)
        WHERE mailitem_id = @mailitem_id

   --Copy query results to mail body
        UPDATE sysmail_mailitems
        SET body.WRITE( (SELECT text_data from sysmail_query_transfer WHERE uid = @temp_table_uid), NULL, NULL )
        WHERE mailitem_id = @mailitem_id

    END

    --Copy into the attachments table
    IF(@AttachmentsExist = 1)
    BEGIN
        --Copy temp attachments to sysmail_attachments      
        INSERT INTO sysmail_attachments(mailitem_id, filename, filesize, attachment)
        SELECT @mailitem_id, filename, filesize, attachment
        FROM sysmail_attachments_transfer
        WHERE uid = @temp_table_uid
    END

    -- Create the primary SSB xml maessage
    SET @sendmailxml = '<requests:SendMail xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.microsoft.com/databasemail/requests RequestTypes.xsd" xmlns:requests="http://schemas.microsoft.com/databasemail/requests"><MailItemId>'
                        + CONVERT(NVARCHAR(20), @mailitem_id) + N'</MailItemId></requests:SendMail>'

    -- Send the send request on queue.
    EXEC @rc = sp_SendMailQueues @sendmailxml
    IF @rc <> 0
    BEGIN
       RAISERROR(14627, 16, 1, @rc, 'send mail')
       GOTO ErrorHandler;
    END

    -- Print success message if required
    IF (@exclude_query_output = 0)
    BEGIN
       SET @localmessage = FORMATMESSAGE(14635)
       PRINT @localmessage
    END  

    --
    -- See if the transaction needs to be commited
    --
    IF (@trancountSave = 0 and @tranStartedBool = 1)
       COMMIT TRAN @procName

    -- All done OK
    goto ExitProc;

    -----------------
    -- Error Handler
    -----------------
ErrorHandler:
    IF (@tranStartedBool = 1) 
       ROLLBACK TRAN @procName

    ------------------
    -- Exit Procedure
    ------------------
ExitProc:
   
    --Always delete query and attactment transfer records. 
   --Note: Query results can also be returned in the sysmail_attachments_transfer table
    DELETE sysmail_attachments_transfer WHERE uid = @temp_table_uid
    DELETE sysmail_query_transfer WHERE uid = @temp_table_uid

   --Raise an error it the query execution fails
   -- This will only be the case when @append_query_error is set to 0 (false)
   IF( (@RetErrorMsg IS NOT NULL) AND (@exclude_query_output=0) )
   BEGIN
      RAISERROR(14661, -1, -1, @RetErrorMsg)
   END

    RETURN (@rc)
END

GO

USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_ProcessResponse]    Script Date: 08/04/2006 14:54:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
-- Processes responses from dbmail 
--
ALTER PROCEDURE [dbo].[sp_ProcessResponse]
    @conv_handle        uniqueidentifier,
    @message_type_name  NVARCHAR(256),
    @xml_message_body   NVARCHAR(max)
AS
BEGIN
    DECLARE 
        @idoc               INT,
        @mailitem_id        INT,
        @sent_status        INT,
        @rc                 INT,
        @index              INT,
        @processId          INT,
        @sent_date          DATETIME,
        @localmessage       NVARCHAR(max),
        @LogMessage         NVARCHAR(max),
        @retry_hconv        uniqueidentifier,
        @paramStr           NVARCHAR(256),
        @accRetryDelay      INT

    --------------------------
    --Always send the response 
    ;SEND ON CONVERSATION @conv_handle MESSAGE TYPE @message_type_name (@xml_message_body)


    --
    -- Need to handle the case where a sent retry is requested. 
    -- This is done by setting a conversation timer, The timer with go off in the external queue

    -- Get the handle to the xml document
    EXEC @rc = sp_xml_preparedocument 
                    @idoc OUTPUT, 
                    @xml_message_body, 
                    N'<ns xmlns:responses="http://schemas.microsoft.com/databasemail/responses" />'
    IF(@rc <> 0)
    BEGIN
        --Log the error. The response has already sent to the Internal queue. 
        -- This will update the mail with the latest staus
        SET @localmessage = FORMATMESSAGE(14655, CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage

        GOTO ErrorHandler;
    END

    -- Execute a SELECT statement that uses the OPENXML rowset provider to get the MailItemId and sent status.
    SELECT @mailitem_id     = MailItemId, 
           @sent_status     = SentStatus
    FROM OPENXML (@idoc, '/responses:SendMail', 1)
        WITH (MailItemId    INT      './MailItemId/@Id', 
              SentStatus    INT      './SentStatus/@Status')

    --Close the handle to the xml document
    EXEC sp_xml_removedocument @idoc

    IF(@mailitem_id IS NULL OR @sent_status IS NULL)
    BEGIN  
        --Log error and continue.
        SET @localmessage = FORMATMESSAGE(14652, CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage

        GOTO ErrorHandler;
    END      

	-- Update the status of the email item
	UPDATE msdb.dbo.sysmail_mailitems
	SET sent_status = @sent_status
	WHERE mailitem_id = @mailitem_id

    --
    -- A send retry has been requested. Set a conversation timer
    IF(@sent_status = 3)
    BEGIN
        -- Get the associated mail item data for the given @conversation_handle (if it exists)
       SELECT @retry_hconv = conversation_handle
       FROM sysmail_send_retries as sr
            RIGHT JOIN sysmail_mailitems as mi
            ON sr.mailitem_id = mi.mailitem_id
       WHERE mi.mailitem_id = @mailitem_id

        --Must be the first retry attempt. Create a sysmail_send_retries record to track retries
        IF(@retry_hconv IS NULL)
        BEGIN
            INSERT sysmail_send_retries(conversation_handle, mailitem_id) --last_send_attempt_date
            VALUES(@conv_handle, @mailitem_id)
        END
        ELSE
        BEGIN
            --Update existing retry record
            UPDATE sysmail_send_retries
            SET last_send_attempt_date = GETDATE(),
                send_attempts = send_attempts + 1
            WHERE mailitem_id = @mailitem_id

        END

        --Get the global retry delay time
        EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'AccountRetryDelay', 
                                                    @parameter_value = @paramStr OUTPUT
        --ConvertToInt will return the default if @paramStr is null
        SET @accRetryDelay = dbo.ConvertToInt(@paramStr, 0x7fffffff, 300) -- 5 min default


        --Now set the dialog timer. This triggers the send retry
        ;BEGIN CONVERSATION TIMER (@conv_handle) TIMEOUT = @accRetryDelay 

    END
    ELSE
    BEGIN
        --Only end theconversation if a retry isn't being attempted
        END CONVERSATION @conv_handle
    END


    -- All done OK
    goto ExitProc;

    -----------------
    -- Error Handler
    -----------------
ErrorHandler:

    ------------------
    -- Exit Procedure
    ------------------
ExitProc:
    RETURN (@rc);

END

go

/**************************************************************/
/* SP_HELP_JOBHISTORY                                         */
/**************************************************************/

use [msdb]

PRINT ''
PRINT 'Creating procedure sp_help_jobhistory...'
go
IF (EXISTS (SELECT *
            FROM msdb.dbo.sysobjects
            WHERE (name = N'sp_help_jobhistory_full')
              AND (type = 'P')))
  DROP PROCEDURE sp_help_jobhistory_full
go
IF (EXISTS (SELECT *
            FROM msdb.dbo.sysobjects
            WHERE (name = N'sp_help_jobhistory_summary')
              AND (type = 'P')))
  DROP PROCEDURE sp_help_jobhistory_summary
go
IF (EXISTS (SELECT *
            FROM msdb.dbo.sysobjects
            WHERE (name = N'sp_help_jobhistory_sem')
              AND (type = 'P')))
  DROP PROCEDURE sp_help_jobhistory_sem
go
CREATE PROCEDURE sp_help_jobhistory_full
               @job_id               UNIQUEIDENTIFIER,
               @job_name             sysname,
               @step_id              INT,
               @sql_message_id       INT,
               @sql_severity         INT,
               @start_run_date       INT,
               @end_run_date         INT,
               @start_run_time       INT,
               @end_run_time         INT,
               @minimum_run_duration INT,
               @run_status           INT,
               @minimum_retries      INT,
               @oldest_first         INT,
               @server               sysname,
               @mode                 VARCHAR(7),
               @order_by             INT,
               @distributed_job_history BIT
AS
IF(@distributed_job_history = 1)
  SELECT null as instance_id, 
     sj.job_id,
     job_name = sj.name,
     null as step_id,
     null as step_name,
     null as sql_message_id,
     null as sql_severity,
     sjh.last_outcome_message as message,
     sjh.last_run_outcome as run_status,
     sjh.last_run_date as run_date,
     sjh.last_run_time as run_time,
    sjh.last_run_duration as run_duration,
     null as operator_emailed,
     null as operator_netsentname,
     null as operator_paged,
     null as retries_attempted,
     sts.server_name as server
  FROM msdb.dbo.sysjobservers                sjh
  JOIN msdb.dbo.systargetservers sts ON (sts.server_id = sjh.server_id)
  JOIN msdb.dbo.sysjobs_view     sj  ON(sj.job_id = sjh.job_id)
  WHERE 
  (@job_id = sjh.job_id)
  AND ((@start_run_date       IS NULL) OR (sjh.last_run_date >= @start_run_date))
  AND ((@end_run_date         IS NULL) OR (sjh.last_run_date <= @end_run_date))
  AND ((@start_run_time       IS NULL) OR (sjh.last_run_time >= @start_run_time))
  AND ((@minimum_run_duration IS NULL) OR (sjh.last_run_duration >= @minimum_run_duration))
  AND ((@run_status           IS NULL) OR (@run_status = sjh.last_run_outcome))
  AND ((@server               IS NULL) OR (sts.server_name = @server))
ELSE
  SELECT sjh.instance_id, -- This is included just for ordering purposes
     sj.job_id,
     job_name = sj.name,
     sjh.step_id,
     sjh.step_name,
     sjh.sql_message_id,
     sjh.sql_severity,
     sjh.message,
     sjh.run_status,
     sjh.run_date,
     sjh.run_time,
     sjh.run_duration,
     operator_emailed = so1.name,
     operator_netsent = so2.name,
     operator_paged = so3.name,
     sjh.retries_attempted,
     sjh.server
  FROM msdb.dbo.sysjobhistory                sjh
     LEFT OUTER JOIN msdb.dbo.sysoperators so1  ON (sjh.operator_id_emailed = so1.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so2  ON (sjh.operator_id_netsent = so2.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so3  ON (sjh.operator_id_paged = so3.id),
     msdb.dbo.sysjobs_view sj
  WHERE (sj.job_id = sjh.job_id)
  AND ((@job_id               IS NULL) OR (@job_id = sjh.job_id))
  AND ((@step_id              IS NULL) OR (@step_id = sjh.step_id))
  AND ((@sql_message_id       IS NULL) OR (@sql_message_id = sjh.sql_message_id))
  AND ((@sql_severity         IS NULL) OR (@sql_severity = sjh.sql_severity))
  AND ((@start_run_date       IS NULL) OR (sjh.run_date >= @start_run_date))
  AND ((@end_run_date         IS NULL) OR (sjh.run_date <= @end_run_date))
  AND ((@start_run_time       IS NULL) OR (sjh.run_time >= @start_run_time))
  AND ((@end_run_time         IS NULL) OR (sjh.run_time <= @end_run_time))
  AND ((@minimum_run_duration IS NULL) OR (sjh.run_duration >= @minimum_run_duration))
  AND ((@run_status           IS NULL) OR (@run_status = sjh.run_status))
  AND ((@minimum_retries      IS NULL) OR (sjh.retries_attempted >= @minimum_retries))
  AND ((@server               IS NULL) OR (sjh.server = @server))
  ORDER BY (sjh.instance_id * @order_by)

GO
CREATE PROCEDURE sp_help_jobhistory_summary
               @job_id               UNIQUEIDENTIFIER,
               @job_name             sysname,
               @step_id              INT,
               @sql_message_id       INT,
               @sql_severity         INT,
               @start_run_date       INT,
               @end_run_date         INT,
               @start_run_time       INT,
               @end_run_time         INT,
               @minimum_run_duration INT,
               @run_status           INT,
               @minimum_retries      INT,
               @oldest_first         INT,
               @server               sysname,
               @mode                 VARCHAR(7),
               @order_by             INT,
               @distributed_job_history BIT
AS
-- Summary format: same WHERE clause as for full, just a different SELECT list
IF(@distributed_job_history = 1)
  SELECT sj.job_id,
     job_name = sj.name,
     sjh.last_run_outcome as run_status,
     sjh.last_run_date as run_date,
     sjh.last_run_time as run_time,
     sjh.last_run_duration as run_duration,
     null as operator_emailed,
     null as operator_netsentname,
     null as operator_paged,
     null as retries_attempted,
     sts.server_name as server
  FROM msdb.dbo.sysjobservers                sjh
  JOIN msdb.dbo.systargetservers sts ON (sts.server_id = sjh.server_id)
  JOIN msdb.dbo.sysjobs_view     sj  ON(sj.job_id = sjh.job_id)
  WHERE 
  (@job_id = sjh.job_id)
  AND ((@start_run_date       IS NULL) OR (sjh.last_run_date >= @start_run_date))
  AND ((@end_run_date         IS NULL) OR (sjh.last_run_date <= @end_run_date))
  AND ((@start_run_time       IS NULL) OR (sjh.last_run_time >= @start_run_time))
  AND ((@minimum_run_duration IS NULL) OR (sjh.last_run_duration >= @minimum_run_duration))
  AND ((@run_status           IS NULL) OR (@run_status = sjh.last_run_outcome))
  AND ((@server               IS NULL) OR (sts.server_name = @server))
ELSE
  SELECT sj.job_id,
     job_name = sj.name,
     sjh.run_status,
     sjh.run_date,
     sjh.run_time,
     sjh.run_duration,
     operator_emailed = substring(so1.name, 1, 20),
     operator_netsent = substring(so2.name, 1, 20),
     operator_paged = substring(so3.name, 1, 20),
     sjh.retries_attempted,
     sjh.server
  FROM msdb.dbo.sysjobhistory                sjh
     LEFT OUTER JOIN msdb.dbo.sysoperators so1  ON (sjh.operator_id_emailed = so1.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so2  ON (sjh.operator_id_netsent = so2.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so3  ON (sjh.operator_id_paged = so3.id),
     msdb.dbo.sysjobs_view                 sj
  WHERE (sj.job_id = sjh.job_id)
  AND ((@job_id               IS NULL) OR (@job_id = sjh.job_id))
  AND ((@step_id              IS NULL) OR (@step_id = sjh.step_id))
  AND ((@sql_message_id       IS NULL) OR (@sql_message_id = sjh.sql_message_id))
  AND ((@sql_severity         IS NULL) OR (@sql_severity = sjh.sql_severity))
  AND ((@start_run_date       IS NULL) OR (sjh.run_date >= @start_run_date))
  AND ((@end_run_date         IS NULL) OR (sjh.run_date <= @end_run_date))
  AND ((@start_run_time       IS NULL) OR (sjh.run_time >= @start_run_time))
  AND ((@end_run_time         IS NULL) OR (sjh.run_time <= @end_run_time))
  AND ((@minimum_run_duration IS NULL) OR (sjh.run_duration >= @minimum_run_duration))
  AND ((@run_status           IS NULL) OR (@run_status = sjh.run_status))
  AND ((@minimum_retries      IS NULL) OR (sjh.retries_attempted >= @minimum_retries))
  AND ((@server               IS NULL) OR (sjh.server = @server))
  ORDER BY (sjh.instance_id * @order_by)

GO
CREATE PROCEDURE sp_help_jobhistory_sem
               @job_id               UNIQUEIDENTIFIER,
               @job_name             sysname,
               @step_id              INT,
               @sql_message_id       INT,
               @sql_severity         INT,
               @start_run_date       INT,
               @end_run_date         INT,
               @start_run_time       INT,
               @end_run_time         INT,
               @minimum_run_duration INT,
               @run_status           INT,
               @minimum_retries      INT,
               @oldest_first         INT,
               @server               sysname,
               @mode                 VARCHAR(7),
               @order_by             INT,
               @distributed_job_history BIT
AS
-- SQL Enterprise Manager format
IF(@distributed_job_history = 1)
  SELECT sj.job_id,
     null as step_name,
     sjh.last_outcome_message as message,
     sjh.last_run_outcome as run_status,
     sjh.last_run_date as run_date,
     sjh.last_run_time as run_time,
     sjh.last_run_duration as run_duration,
     null as operator_emailed,
     null as operator_netsentname,
     null as operator_paged
  FROM msdb.dbo.sysjobservers                sjh
  JOIN msdb.dbo.systargetservers sts ON (sts.server_id = sjh.server_id)
  JOIN msdb.dbo.sysjobs_view     sj  ON(sj.job_id = sjh.job_id)
  WHERE 
  (@job_id = sjh.job_id)
ELSE
  SELECT sjh.step_id,
     sjh.step_name,
     sjh.message,
     sjh.run_status,
     sjh.run_date,
     sjh.run_time,
     sjh.run_duration,
     operator_emailed = so1.name,
     operator_netsent = so2.name,
     operator_paged = so3.name
  FROM msdb.dbo.sysjobhistory                sjh
     LEFT OUTER JOIN msdb.dbo.sysoperators so1  ON (sjh.operator_id_emailed = so1.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so2  ON (sjh.operator_id_netsent = so2.id)
     LEFT OUTER JOIN msdb.dbo.sysoperators so3  ON (sjh.operator_id_paged = so3.id),
     msdb.dbo.sysjobs_view                 sj
  WHERE (sj.job_id = sjh.job_id)
  AND (@job_id = sjh.job_id)
  ORDER BY (sjh.instance_id * @order_by)
GO
ALTER PROCEDURE [dbo].[sp_help_jobhistory]
  @job_id               UNIQUEIDENTIFIER = NULL,
  @job_name             sysname          = NULL,
  @step_id              INT              = NULL,
  @sql_message_id       INT              = NULL,
  @sql_severity         INT              = NULL,
  @start_run_date       INT              = NULL,     -- YYYYMMDD
  @end_run_date         INT              = NULL,     -- YYYYMMDD
  @start_run_time       INT              = NULL,     -- HHMMSS
  @end_run_time         INT              = NULL,     -- HHMMSS
  @minimum_run_duration INT              = NULL,     -- HHMMSS
  @run_status           INT              = NULL,     -- SQLAGENT_EXEC_X code
  @minimum_retries      INT              = NULL,
  @oldest_first         INT              = 0,        -- Or 1
  @server               sysname          = NULL,
  @mode                 VARCHAR(7)       = 'SUMMARY' -- Or 'FULL' or 'SEM'
AS
BEGIN
  DECLARE @retval   INT
  DECLARE @order_by INT  -- Must be INT since it can be -1

  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @server   = LTRIM(RTRIM(@server))
  SELECT @mode     = LTRIM(RTRIM(@mode))

  -- Turn [nullable] empty string parameters into NULLs
  IF (@server = N'')   SELECT @server = NULL

  -- Check job id/name (if supplied)
  IF ((@job_id IS NOT NULL) OR (@job_name IS NOT NULL))
  BEGIN
    EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                                '@job_id',
                                                 @job_name OUTPUT,
                                                 @job_id   OUTPUT
    IF (@retval <> 0)
      RETURN(1) -- Failure
  END

  -- Check @start_run_date
  IF (@start_run_date IS NOT NULL)
  BEGIN
    EXECUTE @retval = sp_verify_job_date @start_run_date, '@start_run_date'
    IF (@retval <> 0)
      RETURN(1) -- Failure
  END

  -- Check @end_run_date
  IF (@end_run_date IS NOT NULL)
  BEGIN
    EXECUTE @retval = sp_verify_job_date @end_run_date, '@end_run_date'
    IF (@retval <> 0)
      RETURN(1) -- Failure
  END

  -- Check @start_run_time
  EXECUTE @retval = sp_verify_job_time @start_run_time, '@start_run_time'
  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- Check @end_run_time
  EXECUTE @retval = sp_verify_job_time @end_run_time, '@end_run_time'
  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- Check @run_status
  IF ((@run_status < 0) OR (@run_status > 5))
  BEGIN
    RAISERROR(14198, -1, -1, '@run_status', '0..5')
    RETURN(1) -- Failure
  END

  -- Check mode
  SELECT @mode = UPPER(@mode collate SQL_Latin1_General_CP1_CS_AS)
  IF (@mode NOT IN ('SUMMARY', 'FULL', 'SEM'))
  BEGIN
    RAISERROR(14266, -1, -1, '@mode', 'SUMMARY, FULL, SEM')
    RETURN(1) -- Failure
  END

  SELECT @order_by = -1
  IF (@oldest_first = 1)
    SELECT @order_by = 1

  DECLARE @distributed_job_history BIT 
  SET @distributed_job_history = 0
  
  IF (@job_id IS NOT NULL) AND ( EXISTS (SELECT *
                              FROM msdb.dbo.sysjobs       sj,
                                 msdb.dbo.sysjobservers sjs
                              WHERE (sj.job_id = sjs.job_id)
                                 AND (sj.job_id = @job_id)
                                 AND (sjs.server_id <> 0)))
   SET @distributed_job_history = 1

  -- Return history information filtered by the supplied parameters.
  -- Having actual queries in subprocedures allows better query plans because query optimizer sniffs correct parameters
  IF (@mode = 'FULL')
  BEGIN
  -- NOTE: SQLDMO relies on the 'FULL' format; ** DO NOT CHANGE IT **
	  EXECUTE sp_help_jobhistory_full
	     @job_id,
	     @job_name,
	     @step_id,
	     @sql_message_id,
	     @sql_severity,
	     @start_run_date,
	     @end_run_date,
	     @start_run_time,
	     @end_run_time,
	     @minimum_run_duration,
	     @run_status,
	     @minimum_retries,
	     @oldest_first,
	     @server,
	     @mode,
	     @order_by,
	     @distributed_job_history
  END
  ELSE
  IF (@mode = 'SUMMARY')
  BEGIN
    -- Summary format: same WHERE clause as for full, just a different SELECT list
    EXECUTE sp_help_jobhistory_summary
         @job_id,
         @job_name,
         @step_id,
         @sql_message_id,
         @sql_severity,
         @start_run_date,
         @end_run_date,
         @start_run_time,
         @end_run_time,
         @minimum_run_duration,
         @run_status,
         @minimum_retries,
         @oldest_first,
         @server,
         @mode,
         @order_by,
         @distributed_job_history
  END
  ELSE
  IF (@mode = 'SEM')
  BEGIN
    -- SQL Enterprise Manager format
    EXECUTE sp_help_jobhistory_sem
         @job_id,
         @job_name,
         @step_id,
         @sql_message_id,
         @sql_severity,
         @start_run_date,
         @end_run_date,
         @start_run_time,
         @end_run_time,
         @minimum_run_duration,
         @run_status,
         @minimum_retries,
         @oldest_first,
         @server,
         @mode,
         @order_by,
         @distributed_job_history
  END
  RETURN(0) -- Success
END
GO

GRANT EXECUTE ON sp_help_jobhistory  TO SQLAgentUserRole
GRANT EXECUTE ON sp_help_jobhistory_full TO SQLAgentUserRole
GRANT EXECUTE ON sp_help_jobhistory_summary TO SQLAgentUserRole
GRANT EXECUTE ON sp_help_jobhistory_sem TO SQLAgentUserRole

/**************************************************************/
/* sysmail_event_log                                         */
/**************************************************************/
use msdb
go
PRINT ''
PRINT 'Creating view sysmail_event_log...'
go
IF (EXISTS (SELECT *
            FROM msdb.dbo.sysobjects
            WHERE (name = N'sysmail_event_log')
              AND (type = 'V')))
  DROP VIEW sysmail_event_log
go

CREATE VIEW sysmail_event_log
AS
SELECT log_id,
       CASE event_type 
          WHEN 0 THEN 'success' 
          WHEN 1 THEN 'information' 
          WHEN 2 THEN 'warning' 
          ELSE 'error' 
       END as event_type,
       log_date,
       description,
       process_id,
       sl.mailitem_id,
       account_id,
       sl.last_mod_date,
       sl.last_mod_user
FROM [dbo].[sysmail_log]  sl
WHERE (ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 1) OR 
      (EXISTS ( SELECT mailitem_id FROM [dbo].[sysmail_allitems] ai WHERE sl.mailitem_id = ai.mailitem_id ))


GO

GRANT SELECT  ON [dbo].[sysmail_event_log]                TO DatabaseMailUserRole

USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_sysmail_activate]    Script Date: 06/22/2006 17:56:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- sp_sysmail_activate : Starts the DatabaseMail process if it isn't already running
--
ALTER PROCEDURE [dbo].[sp_sysmail_activate]

AS
BEGIN
    DECLARE @mailDbName sysname
    DECLARE @mailDbId INT
    DECLARE @mailEngineLifeMin INT
    DECLARE @loggingLevel nvarchar(256)
    DECLARE @loggingLevelInt int   
    DECLARE @parameter_value nvarchar(256)
    DECLARE @localmessage nvarchar(max)
	DECLARE @readFromConfigFile INT
    DECLARE @rc INT

    SET NOCOUNT ON
    EXEC sp_executesql @statement = N'RECEIVE TOP(0) * FROM msdb.dbo.ExternalMailQueue'

    EXEC @rc = msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'DatabaseMailExeMinimumLifeTime', 
                                                        @parameter_value = @parameter_value OUTPUT
    IF(@rc <> 0)
        RETURN (1)

    --ConvertToInt will return the default if @parameter_value is null or config value can't be converted
    --Setting max exe lifetime is 1 week (604800 secs). Can't see a reason for it to ever run longer that this
    SET @mailEngineLifeMin = dbo.ConvertToInt(@parameter_value, 604800, 600) 

	EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'ReadFromConfigurationFile', 
                                                  @parameter_value = @parameter_value OUTPUT
	--Try to read the optional read from configuration file:
    SET @readFromConfigFile = dbo.ConvertToInt(@parameter_value, 1, 0) 

    --Try and get the optional logging level for the DatabaseMail process
    EXEC msdb.dbo.sysmail_help_configure_value_sp @parameter_name = N'LoggingLevel', 
                                                  @parameter_value = @loggingLevel OUTPUT

    --Convert logging level into string value for passing into XP
    SET @loggingLevelInt = dbo.ConvertToInt(@loggingLevel, 3, 2) 
    IF @loggingLevelInt = 1
       SET @loggingLevel = 'Normal'
    ELSE IF @loggingLevelInt = 3
       SET @loggingLevel = 'Verbose'
    ELSE -- default
       SET @loggingLevel = 'Extended'

    SET @mailDbName = DB_NAME()
    SET @mailDbId   = DB_ID()

    EXEC @rc = master..xp_sysmail_activate @mailDbId, @mailDbName, @readFromConfigFile,
	@mailEngineLifeMin, @loggingLevel
    IF(@rc <> 0)
    BEGIN
        SET @localmessage = FORMATMESSAGE(14637)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage
    END
    ELSE
    BEGIN
        SET @localmessage = FORMATMESSAGE(14638)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=0, @description=@localmessage
    END

    RETURN @rc
END
GO


USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sysmail_delete_profile_sp]    Script Date: 07/19/2006 16:26:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER PROCEDURE [dbo].[sysmail_delete_profile_sp]
   @profile_id int = NULL, -- must provide either id or name
   @profile_name sysname = NULL,
   @force_delete BIT = 1
AS
   SET NOCOUNT ON
  
   DECLARE @rc int
   DECLARE @profileid int
   exec @rc = msdb.dbo.sysmail_verify_profile_sp @profile_id, @profile_name, 0, 0, @profileid OUTPUT
   IF @rc <> 0
      RETURN(1)

IF(EXISTS (select * from sysmail_unsentitems WHERE 
   sysmail_unsentitems.profile_id = @profileid) AND @force_delete <> 1)
BEGIN
	IF(@profile_name IS NULL)
	BEGIN
		select @profile_name = name from dbo.sysmail_profile WHERE profile_id = @profileid
	END
	RAISERROR(14668, -1, -1, @profile_name)
	RETURN (1)   
END

UPDATE [msdb].[dbo].[sysmail_mailitems]
SET [sent_status] = 2, [sent_date] = getdate()
WHERE profile_id = @profileid AND sent_status <> 1
     
   DELETE FROM msdb.dbo.sysmail_profile 
   WHERE profile_id = @profileid
   RETURN(0)
GO
/******** [sysmail_update_account_sp] ********/

USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sysmail_update_account_sp]    Script Date: 06/26/2006 10:45:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_ExternalMailQueueListener]    Script Date: 08/10/2006 14:31:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
-- Processes messages from the external mail queue
--
ALTER PROCEDURE [dbo].[sp_ExternalMailQueueListener]
AS
BEGIN
    DECLARE 
        @idoc               INT,
        @mailitem_id        INT,
        @sent_status        INT,
        @sent_account_id    INT,
        @rc                 INT,
        @processId          INT,
        @sent_date          DATETIME,
        @localmessage       NVARCHAR(max),
        @conv_handle        uniqueidentifier,
       @message_type_name  NVARCHAR(256),
       @xml_message_body   NVARCHAR(max),
        @LogMessage         NVARCHAR(max)

    -- Table to store message information.
    DECLARE @msgs TABLE
    (
        [conversation_handle]   uniqueidentifier,
       [message_type_name]     nvarchar(256),
       [message_body]          varbinary(max)
    )

    --RECEIVE messages from the external queue. 
    --MailItem status messages are sent from the external sql mail process along with other SSB notifications and errors
    ;RECEIVE conversation_handle, message_type_name, message_body FROM InternalMailQueue INTO @msgs
    -- Check if there was some error in reading from queue
    SET @rc = @@ERROR
    IF (@rc <> 0)
    BEGIN
        --Log error and continue. Don't want to block the following messages on the queue
        SET @localmessage = FORMATMESSAGE(@@ERROR)
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage

        GOTO ErrorHandler;
    END
   
    -----------------------------------
    --Process sendmail status messages
    SELECT 
        @conv_handle        = conversation_handle,
        @message_type_name  = message_type_name, 
        @xml_message_body   = CAST(message_body AS NVARCHAR(MAX))
    FROM @msgs 
    WHERE [message_type_name] = N'{//www.microsoft.com/databasemail/messages}SendMailStatus'

    IF(@message_type_name IS NOT NULL)
    BEGIN
        --
        --Expecting the xml body to be n the following form:
        --
        --<?xml version="1.0" encoding="utf-16"?>
        --<responses:SendMail xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.microsoft.com/databasemail/responses ResponseTypes.xsd" xmlns:responses="http://schemas.microsoft.com/databasemail/responses">
        --<Information>
        --    <Failure Message="THe error message...."/>
        --</Information>
        --<MailItemId Id="1" />
        --<SentStatus Status="3" />
        --<SentAccountId Id="0" />
        --<SentDate Date="2005-03-30T14:55:13" />
        --<CallingProcess Id="3012" />
        --</responses:SendMail>

        -- Get the handle to the xml document
        EXEC @rc = sp_xml_preparedocument 
                        @idoc OUTPUT, 
                        @xml_message_body, 
                        N'<ns xmlns:responses="http://schemas.microsoft.com/databasemail/responses" />'
        IF(@rc <> 0)
        BEGIN
            --Log error and continue. Don't want to block the following messages on the queue
            SET @localmessage = FORMATMESSAGE(14655, CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
            exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage

            GOTO ErrorHandler;
        END

        -- Execute a SELECT statement that uses the OPENXML rowset provider to get the MailItemId and sent status.
        SELECT @mailitem_id     = MailItemId, 
               @sent_status     = SentStatus,
               @sent_account_id = SentAccountId,
               @sent_date       = SentDate,
               @processId       = CallingProcess,
               @LogMessage      = LogMessage
        FROM OPENXML (@idoc, '/responses:SendMail', 1)
            WITH (MailItemId    INT      './MailItemId/@Id', 
                  SentStatus    INT      './SentStatus/@Status',
                  SentAccountId INT      './SentAccountId/@Id',
                  SentDate      DATETIME './SentDate/@Date', --The date was formated using ISO8601
                  CallingProcess INT     './CallingProcess/@Id', 
                  LogMessage     NVARCHAR(max) './Information/Failure/@Message')

        --Close the handle to the xml document
        EXEC sp_xml_removedocument @idoc

        IF(@mailitem_id IS NULL)
        BEGIN  
            --Log error and continue. Don't want to block the following messages on the queue by rolling back the tran
            SET @localmessage = FORMATMESSAGE(14652, CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
            exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage
        END      
        ELSE
        BEGIN
            -- check sent_status is valid : 0(PendingSend), 1(SendSuccessful), 2(SendFailed), 3(AttemptingSendRetry)
            IF(@sent_status NOT IN (1, 2, 3))
            BEGIN
                SET @localmessage = FORMATMESSAGE(14653, N'SentStatus', CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
                exec msdb.dbo.sysmail_logmailevent_sp @event_type=2, @description=@localmessage

                --Set value to SendFailed
                SET @sent_status = 2
            END

            --Make the @sent_account_id NULL if it is 0. 
            IF(@sent_account_id IS NOT NULL AND @sent_account_id = 0)
                SET @sent_account_id = NULL

            --
            -- Update the mail status if not a retry. Nothing else needs to be done in this case
            UPDATE sysmail_mailitems
            SET sent_status     = CAST (@sent_status as TINYINT),
                sent_account_id = @sent_account_id,
                sent_date       = @sent_date
            WHERE mailitem_id = @mailitem_id
        
            -- Report a failure if no record is found in the sysmail_mailitems table
            IF (@@ROWCOUNT = 0)
            BEGIN
                SET @localmessage = FORMATMESSAGE(14653, N'MailItemId', CONVERT(NVARCHAR(50), @conv_handle), @message_type_name, @xml_message_body)
                exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@localmessage
            END

            IF (@LogMessage IS NOT NULL)
            BEGIN
                exec msdb.dbo.sysmail_logmailevent_sp @event_type=3, @description=@LogMessage, @process_id=@processId, @mailitem_id=@mailitem_id, @account_id=@sent_account_id
            END
        END
    END

    -------------------------------------------------------
    --Process all other messages by logging to sysmail_log
    SET @conv_handle = NULL;
    
    --Always end the conversion if this message is received
    SELECT @conv_handle = conversation_handle
    FROM @msgs 
    WHERE [message_type_name] = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
    
    IF(@conv_handle IS NOT NULL)
    BEGIN
        END CONVERSATION @conv_handle;
    END

    DECLARE @queuemessage nvarchar(max)
    DECLARE queue_messages_cursor CURSOR LOCAL 
    FOR
        SELECT FORMATMESSAGE(14654, CONVERT(NVARCHAR(50), conversation_handle), message_type_name, message_body)
        FROM @msgs 
        WHERE [message_type_name] 
              NOT IN (N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog',
                      N'{//www.microsoft.com/databasemail/messages}SendMailStatus')
  
    OPEN queue_messages_cursor 
    FETCH NEXT FROM queue_messages_cursor INTO @queuemessage
    WHILE (@@fetch_status = 0)
    BEGIN
        exec msdb.dbo.sysmail_logmailevent_sp @event_type=2, @description=@queuemessage
        FETCH NEXT FROM queue_messages_cursor INTO @queuemessage
    END
    CLOSE queue_messages_cursor 
    DEALLOCATE queue_messages_cursor 

    -- All done OK
    goto ExitProc;

    -----------------
    -- Error Handler
    -----------------
ErrorHandler:

    ------------------
    -- Exit Procedure
    ------------------
ExitProc:
    RETURN (@rc)
END

GO

ALTER PROCEDURE [dbo].[sysmail_update_account_sp]
   @account_id int = NULL, -- must provide either id or name
   @account_name sysname = NULL,
   @email_address nvarchar(128) = NULL,
   @display_name nvarchar(128) = NULL,
   @replyto_address nvarchar(128) = NULL,
   @description nvarchar(256) = NULL,
   @mailserver_name sysname = NULL,  
   @mailserver_type sysname = NULL,  
   @port int = NULL,
   @username sysname = NULL,
   @password sysname = NULL,
   @use_default_credentials bit = NULL,
   @enable_ssl bit = NULL
  -- WITH EXECUTE AS OWNER --Allows access to sys.credentials
AS
   SET NOCOUNT ON

   DECLARE @rc int
   DECLARE @accountid int
   DECLARE @credential_id int
   DECLARE @credential_name sysname

   exec @rc = msdb.dbo.sysmail_verify_account_sp @account_id, @account_name, 0, 1, @accountid OUTPUT
   IF @rc <> 0
      RETURN(1)

   IF(@email_address IS NULL)
   BEGIN
   SELECT @email_address = email_address FROM msdb.dbo.sysmail_account WHERE account_id=@accountid
   END


   IF(@display_name IS NULL)
   BEGIN
   SELECT @display_name = display_name FROM msdb.dbo.sysmail_account WHERE account_id=@accountid
   END

   IF(@replyto_address IS NULL)
   BEGIN
   SELECT @replyto_address = replyto_address FROM msdb.dbo.sysmail_account WHERE account_id=@accountid
   END

   IF(@description IS NULL)
   BEGIN
   SELECT @description = description FROM msdb.dbo.sysmail_account WHERE account_id=@accountid
   END


   IF(@port IS NULL)
   BEGIN
   SELECT @port = port FROM msdb.dbo.sysmail_server WHERE account_id=@accountid
   END

   IF(@use_default_credentials IS NULL)
   BEGIN
   SELECT @use_default_credentials = use_default_credentials FROM msdb.dbo.sysmail_server WHERE account_id=@accountid
   END

   IF(@enable_ssl IS NULL)
   BEGIN
   SELECT @enable_ssl = enable_ssl FROM msdb.dbo.sysmail_server WHERE account_id=@accountid
   END

   IF(@mailserver_type IS NULL)
   BEGIN
   SELECT @mailserver_type = servertype FROM msdb.dbo.sysmail_server WHERE account_id=@accountid
   END


   EXEC @rc = msdb.dbo.sysmail_verify_accountparams_sp 
            @use_default_credentials = @use_default_credentials,
            @mailserver_type = @mailserver_type OUTPUT, -- validates and returns trimmed value
            @username = @username OUTPUT, -- returns trimmed value
            @password = @password OUTPUT  -- returns empty string if @username is given and @password is null 
   IF(@rc <> 0)
      RETURN (1)

   --transact this in case credential updates fail
   BEGIN TRAN
   -- update account table
   IF (@account_name IS NOT NULL)
      IF (@email_address IS NOT NULL)
         UPDATE msdb.dbo.sysmail_account
         SET name=@account_name, description=@description, email_address=@email_address, display_name=@display_name, replyto_address=@replyto_address
         WHERE account_id=@accountid
      ELSE
         UPDATE msdb.dbo.sysmail_account
         SET name=@account_name, description=@description, display_name=@display_name, replyto_address=@replyto_address
         WHERE account_id=@accountid

   ELSE
      IF (@email_address IS NOT NULL)
         UPDATE msdb.dbo.sysmail_account
         SET description=@description, email_address=@email_address, display_name=@display_name, replyto_address=@replyto_address
         WHERE account_id=@accountid
      ELSE
         UPDATE msdb.dbo.sysmail_account
         SET description=@description, display_name=@display_name, replyto_address=@replyto_address
         WHERE account_id=@accountid
      
   -- see if a credential has been stored for this account
   SELECT @credential_name = name,
         @credential_id = c.credential_id
   FROM sys.credentials as c
     JOIN msdb.dbo.sysmail_server as ms
       ON c.credential_id = ms.credential_id
   WHERE account_id = @accountid 
     AND servertype = @mailserver_type

   --update the credential store
   IF(@credential_name IS NOT NULL)
   BEGIN
      --Remove the unneed credential
      IF(@username IS NULL)
      BEGIN
         SET @credential_id = NULL
         EXEC @rc = msdb.dbo.sysmail_drop_user_credential_sp 
                        @credential_name = @credential_name
      END
      -- Update the credential
      ELSE
      BEGIN
         EXEC @rc = msdb.dbo.sysmail_alter_user_credential_sp
                        @credential_name = @credential_name,
                        @username = @username,
                        @password = @password
      END

      IF(@rc <> 0)
      BEGIN 
         ROLLBACK TRAN
         RETURN (1)
      END
   END
   -- create a new credential if one doesn't exist
   ELSE IF(@credential_name IS NULL AND @username IS NOT NULL)
   BEGIN
      EXEC @rc = msdb.dbo.sysmail_create_user_credential_sp
                     @username = @username,
                     @password = @password,
                     @credential_id = @credential_id  OUTPUT
      IF(@rc <> 0)
      BEGIN 
         ROLLBACK TRAN
         RETURN (1)
      END
   END

   -- update server table
   IF (@mailserver_name IS NOT NULL)
      UPDATE msdb.dbo.sysmail_server 
      SET servername=@mailserver_name, port=@port, username=@username, credential_id = @credential_id, use_default_credentials = @use_default_credentials, enable_ssl = @enable_ssl
      WHERE account_id=@accountid AND servertype=@mailserver_type
   
   ELSE
      UPDATE msdb.dbo.sysmail_server 
      SET port=@port, username=@username, credential_id = @credential_id, use_default_credentials = @use_default_credentials, enable_ssl = @enable_ssl
      WHERE account_id=@accountid AND servertype=@mailserver_type
      
   COMMIT TRAN
   RETURN(0)
go

IF NOT EXISTS (
    select * from msdb.dbo.syscolumns where name='msx_job_id' and id =
        (select id from msdb.dbo.sysobjects where name='sysmaintplan_subplans'))
BEGIN
    PRINT 'Altering table sysmaintplan_subplans...'
    ALTER TABLE sysmaintplan_subplans ADD msx_job_id UNIQUEIDENTIFIER DEFAULT NULL NULL

    ALTER TABLE sysmaintplan_subplans ADD CONSTRAINT FK_subplan_msx_job_id FOREIGN KEY (msx_job_id) REFERENCES sysjobs(job_id)
END

IF NOT EXISTS (
    select * from msdb.dbo.syscolumns where name='msx_plan' and id =
        (select id from msdb.dbo.sysobjects where name='sysmaintplan_subplans'))
BEGIN
    ALTER TABLE sysmaintplan_subplans ADD msx_plan bit DEFAULT 0 NOT NULL
END

GO

/**************************************************************/
/* sp_maintplan_update_subplan                                */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_maintplan_update_subplan...'
go
ALTER PROCEDURE sp_maintplan_update_subplan
    @subplan_id       UNIQUEIDENTIFIER,
    @plan_id       UNIQUEIDENTIFIER    = NULL,
    @name          sysname             = NULL,
    @description  NVARCHAR(512)       = NULL,
    @job_id        UNIQUEIDENTIFIER    = NULL,
    @schedule_id  INT                 = NULL,
    @allow_create   BIT                 = 0,
    @msx_job_id    UNIQUEIDENTIFIER    = NULL
AS
BEGIN

   SET NOCOUNT ON

   SELECT @name = LTRIM(RTRIM(@name))
   SELECT @description = LTRIM(RTRIM(@description))

   --Are we creating a new entry or updating an existing one?

   IF( NOT EXISTS(SELECT * FROM msdb.dbo.sysmaintplan_subplans WHERE subplan_id = @subplan_id) )
   BEGIN
        -- Only allow creation of a record if user permits it
        IF(@allow_create = 0)
        BEGIN
            DECLARE @subplan_id_as_char VARCHAR(36)
            SELECT @subplan_id_as_char = CONVERT(VARCHAR(36), @subplan_id)
            RAISERROR(14262, -1, -1, '@subplan_id', @subplan_id_as_char)
          RETURN(1)
        END

        --Insert it's a new subplan
      IF (@name IS NULL)
      BEGIN
          RAISERROR(12981, -1, -1, '@name')
         RETURN(1) -- Failure
      END

      IF (@plan_id IS NULL)
      BEGIN
          RAISERROR(12981, -1, -1, '@plan_id')
         RETURN(1) -- Failure
      END

      INSERT INTO msdb.dbo.sysmaintplan_subplans(
            subplan_id,
            plan_id,
            subplan_description,
            subplan_name,
            job_id,
            schedule_id,
            msx_job_id)
      VALUES(
            @subplan_id,
            @plan_id,
            @description,
            @name,
            @job_id,
            @schedule_id,
            @msx_job_id)

   END
   ELSE
   BEGIN --Update the table

      DECLARE @s_subplan_name sysname
      DECLARE @s_job_id UNIQUEIDENTIFIER

      SELECT @s_subplan_name         = subplan_name,
            @s_job_id               = job_id
      FROM msdb.dbo.sysmaintplan_subplans
      WHERE (@subplan_id = subplan_id)

      --Determine if user wants to change these variables
      IF (@name IS NOT NULL)          SELECT @s_subplan_name          = @name
      IF (@job_id IS NOT NULL)        SELECT @s_job_id                = @job_id

      --UPDATE the record

      UPDATE msdb.dbo.sysmaintplan_subplans 
        SET subplan_name        = @s_subplan_name,
            subplan_description = @description,
            job_id              = @s_job_id,
            schedule_id         = @schedule_id,
            msx_job_id          = @msx_job_id
      WHERE (subplan_id = @subplan_id)

   END

    RETURN (@@ERROR)
END
GO

/**************************************************************/
/* sp_maintplan_delete_subplan                                */
/**************************************************************/
PRINT ''
PRINT 'Altering procedure sp_maintplan_delete_subplan...'
go
ALTER PROCEDURE sp_maintplan_delete_subplan
    @subplan_id       UNIQUEIDENTIFIER,
    @delete_jobs BIT                   = 1
AS
BEGIN

    DECLARE @retval     INT
    DECLARE @job        UNIQUEIDENTIFIER
    DECLARE @jobMsx     UNIQUEIDENTIFIER

    SET NOCOUNT ON
    SET @retval = 0

    -- Raise an error if the @subplan_id doesn't exist
    IF( NOT EXISTS(SELECT * FROM sysmaintplan_subplans WHERE subplan_id = @subplan_id))
    BEGIN
        DECLARE @subplan_id_as_char VARCHAR(36)
        SELECT @subplan_id_as_char = CONVERT(VARCHAR(36), @subplan_id)
        RAISERROR(14262, -1, -1, '@subplan_id', @subplan_id_as_char)
        RETURN(1)
    END


    BEGIN TRAN

    --Is there an Agent Job/Schedule associated with this subplan?
    SELECT @job = job_id, @jobMsx = msx_job_id
    FROM msdb.dbo.sysmaintplan_subplans 
    WHERE subplan_id = @subplan_id

    EXEC @retval = msdb.dbo.sp_maintplan_delete_log @subplan_id = @subplan_id
    IF (@retval <> 0)
    BEGIN
        ROLLBACK TRAN
        RETURN @retval
    END

    -- Delete the subplans table entry first since it has a foreign
    -- key constraint on its job_id existing in sysjobs.
    DELETE msdb.dbo.sysmaintplan_subplans 
    WHERE (subplan_id = @subplan_id)

    IF (@delete_jobs = 1)
    BEGIN
        --delete the local job associated with this subplan
        IF (@job IS NOT NULL)
        BEGIN
            EXEC @retval = msdb.dbo.sp_delete_job @job_id = @job, @delete_unused_schedule = 1
            IF (@retval <> 0)
            BEGIN
                ROLLBACK TRAN
                RETURN @retval
            END
        END

        --delete the multi-server job associated with this subplan.
        IF (@jobMsx IS NOT NULL)
        BEGIN 
            EXEC @retval = msdb.dbo.sp_delete_job @job_id = @jobMsx, @delete_unused_schedule = 1
            IF (@retval <> 0)
            BEGIN
                ROLLBACK TRAN
                RETURN @retval
            END
        END
    END

    COMMIT TRAN
    RETURN (0)
END
go

/**************************************************************/
/* SP_MAINTPLAN_UPDATE_SUBPLAN_TSX                            */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_maintplan_update_subplan_tsx...'
IF (OBJECT_ID(N'dbo.sp_maintplan_update_subplan_tsx', 'P') IS NULL)
  execute sp_executesql N'CREATE PROCEDURE sp_maintplan_update_subplan_tsx
    AS
    select 1
'
go

-- This procedure is called when a maintenance plan subplan record
-- needs to be created or updated to match a multi-server Agent job
-- that has arrived from the master server.
ALTER PROCEDURE sp_maintplan_update_subplan_tsx
    @subplan_id    UNIQUEIDENTIFIER,
    @plan_id       UNIQUEIDENTIFIER,
    @name          sysname,
    @description   NVARCHAR(512),
    @job_id        UNIQUEIDENTIFIER
AS
BEGIN
    -- Find out what schedule, if any, is associated with the job.
    declare @schedule_id int
    select @schedule_id = (SELECT TOP(1) schedule_id
                           FROM msdb.dbo.sysjobschedules
                           WHERE (job_id = @job_id) )

    exec sp_maintplan_update_subplan @subplan_id, @plan_id, @name, @description, @job_id, @schedule_id, @allow_create=1

    -- Be sure to mark this subplan as coming from the master, not locally.
    update sysmaintplan_subplans
    set msx_plan = 1
    where subplan_id = @subplan_id
    
END
go

/**************************************************************/
/* SP_MAINTPLAN_SUBPLANS_BY_JOB                               */
/**************************************************************/
PRINT ''
PRINT 'Updating procedure sp_maintplan_subplans_by_job...'
IF (OBJECT_ID(N'dbo.sp_maintplan_subplans_by_job', 'P') IS NULL)
  execute sp_executesql N'CREATE PROCEDURE sp_maintplan_subplans_by_job
    @job_id  UNIQUEIDENTIFIER
    AS
    select 1
'
go
-- If the given job_id is associated with a maintenance plan,
-- then matching entries from sysmaintplan_subplans are returned.
ALTER PROCEDURE sp_maintplan_subplans_by_job
    @job_id  UNIQUEIDENTIFIER
AS
BEGIN
    select plans.name as 'plan_name', plans.id as 'plan_id', subplans.subplan_name, subplans.subplan_id
    from sysmaintplan_plans plans, sysmaintplan_subplans subplans
    where  plans.id = subplans.plan_id
    and (job_id = @job_id
         or msx_job_id = @job_id)
    order by subplans.plan_id, subplans.subplan_id
END
go

-- Allow SQLAgent on target servers to gather information about
-- maintenance plans from the master.
GRANT EXECUTE ON sp_maintplan_subplans_by_job  TO SQLAgentUserRole
GRANT EXECUTE ON sp_maintplan_subplans_by_job  TO TargetServersRole

-- In order to read any maintenance plan package for import into its
-- TSX Server, the SQLAgent running on the TSX server must be able to
-- load all DTS packages.
EXECUTE sp_addrolemember @rolename = 'db_dtsoperator', @membername = 'TargetServersRole' 

GO

/**************************************************************/
/* SYSMAINTPLAN_LOG                                           */
/**************************************************************/
-- Alter the sysmaintplan_log table to allow for remote logging
-- of maintenance plan execution.
IF NOT EXISTS (
    select * from msdb.dbo.syscolumns where name='logged_remotely' and id =
        (select id from msdb.dbo.sysobjects where name='sysmaintplan_log'))
BEGIN
    alter table sysmaintplan_log
        alter column plan_id uniqueidentifier NULL
    alter table sysmaintplan_log
        alter column subplan_id uniqueidentifier NULL
    alter table sysmaintplan_log
    add logged_remotely bit not null default (0),
        source_server_name nvarchar (128) NULL,
        plan_name nvarchar (128) NULL,
        subplan_name nvarchar (128) NULL
END
GO

/**************************************************************/
/* SYSMAINTPLAN_PLANS                                         */
/**************************************************************/

-- Alter the sysmaintplan_plans view to include the from_msx and
-- has_targets columns, which indicate that this maintenance plan is
-- a distributed plan that came from an MSX server, or that it
-- a plan that is currently distributed to other servers.
ALTER VIEW sysmaintplan_plans
AS
   SELECT
   s.name AS [name],
   s.id AS [id],
   s.description AS [description],
   s.createdate AS [create_date],
   suser_sname(s.ownersid) AS [owner],
   s.vermajor AS [version_major],
   s.verminor AS [version_minor],
   s.verbuild AS [version_build],
   s.vercomments AS [version_comments],
   ISNULL((select TOP 1 msx_plan from sysmaintplan_subplans where plan_id = s.id), 0) AS [from_msx],
   CASE WHEN (NOT EXISTS (select TOP 1 msx_job_id 
                          from sysmaintplan_subplans subplans, sysjobservers jobservers
                          where plan_id = s.id 
                          and msx_job_id is not null
                          and subplans.msx_job_id = jobservers.job_id
                          and server_id != 0)) 
        then 0 
        else 1 END AS [has_targets]
   FROM
   msdb.dbo.sysdtspackages90 AS s
   WHERE
   (s.folderid = '08aa12d5-8f98-4dab-a4fc-980b150a5dc8' and s.packagetype = 6)
go

/**************************************************************/
/* SP_DELETE_JOB_REFERENCES                                   */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_delete_job_references...'
go
ALTER PROCEDURE sp_delete_job_references
  @notify_sqlagent BIT = 1
AS
BEGIN
  DECLARE @deleted_job_id  UNIQUEIDENTIFIER
  DECLARE @task_id_as_char VARCHAR(10)
  DECLARE @job_is_cached   INT
  DECLARE @alert_name      sysname
  DECLARE @maintplan_plan_id  UNIQUEIDENTIFIER
  DECLARE @maintplan_subplan_id  UNIQUEIDENTIFIER

  -- Keep SQLServerAgent's cache in-sync and cleanup any 'webtask' cross-references to the deleted job(s)
  -- NOTE: The caller must have created a table called #temp_jobs_to_delete of the format
  --       (job_id UNIQUEIDENTIFIER NOT NULL, job_is_cached INT NOT NULL).

  DECLARE sqlagent_notify CURSOR LOCAL
  FOR
  SELECT job_id, job_is_cached
  FROM #temp_jobs_to_delete

  OPEN sqlagent_notify
  FETCH NEXT FROM sqlagent_notify INTO @deleted_job_id, @job_is_cached

  WHILE (@@fetch_status = 0)
  BEGIN
    -- NOTE: We only notify SQLServerAgent if we know the job has been cached
    IF(@job_is_cached = 1 AND @notify_sqlagent = 1)
      EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'J',
                                          @job_id      = @deleted_job_id,
                                          @action_type = N'D'

    IF (EXISTS (SELECT *
                FROM master.dbo.sysobjects
                WHERE (name = N'sp_cleanupwebtask')
                  AND (type = 'P')))
    BEGIN
      SELECT @task_id_as_char = CONVERT(VARCHAR(10), task_id)
      FROM msdb.dbo.systaskids
      WHERE (job_id = @deleted_job_id)
      IF (@task_id_as_char IS NOT NULL)
        EXECUTE ('master.dbo.sp_cleanupwebtask @taskid = ' + @task_id_as_char)
    END

    -- Maintenance plan cleanup for SQL 2005.
    -- If this job came from another server and it runs a subplan of a
    -- maintenance plan, then delete the subplan record. If that was
    -- the last subplan still referencing that plan, delete the plan.
    -- This removes a distributed maintenance plan from a target server
    -- once all of jobs from the master server that used that maintenance
    -- plan are deleted.
    SELECT @maintplan_plan_id = plans.plan_id, @maintplan_subplan_id = plans.subplan_id
    FROM sysmaintplan_subplans plans, sysjobs_view sjv
    WHERE plans.job_id = @deleted_job_id
      AND plans.job_id = sjv.job_id
      AND sjv.master_server = 1 -- This means the job came from the master

    IF (@maintplan_subplan_id is not NULL)
    BEGIN
      EXECUTE sp_maintplan_delete_subplan @subplan_id = @maintplan_subplan_id, @delete_jobs = 0
      IF (NOT EXISTS (SELECT *
                      FROM sysmaintplan_subplans
                      where plan_id = @maintplan_plan_id))
      BEGIN
        DECLARE @plan_name sysname

        SELECT @plan_name = name
          FROM sysmaintplan_plans
          WHERE id = @maintplan_plan_id

        EXECUTE sp_dts_deletepackage @name = @plan_name, @folderid = '08aa12d5-8f98-4dab-a4fc-980b150a5dc8' -- this is the guid for 'Maintenance Plans'
      END
    END

    FETCH NEXT FROM sqlagent_notify INTO @deleted_job_id, @job_is_cached
  END
  DEALLOCATE sqlagent_notify

  -- Remove systaskid references (must do this AFTER sp_cleanupwebtask stuff)
  DELETE FROM msdb.dbo.systaskids
  WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)

  -- Remove sysdbmaintplan_jobs references (legacy maintenance plans prior to SQL 2005)
  DELETE FROM msdb.dbo.sysdbmaintplan_jobs
  WHERE job_id IN (SELECT job_id FROM #temp_jobs_to_delete)

  -- Finally, clean up any dangling references in sysalerts to the deleted job(s)
  DECLARE sysalerts_cleanup CURSOR LOCAL
  FOR
  SELECT name
  FROM msdb.dbo.sysalerts
  WHERE (job_id IN (SELECT job_id FROM #temp_jobs_to_delete))

  OPEN sysalerts_cleanup
  FETCH NEXT FROM sysalerts_cleanup INTO @alert_name
  WHILE (@@fetch_status = 0)
  BEGIN
    EXECUTE msdb.dbo.sp_update_alert @name   = @alert_name,
                                     @job_id = 0x00
    FETCH NEXT FROM sysalerts_cleanup INTO @alert_name
  END
  DEALLOCATE sysalerts_cleanup
END
go


/**************************************************************/
/* SP_DELETE_JOBSERVER                                        */
/**************************************************************/

PRINT ''
PRINT 'Updating procedure sp_delete_jobserver...'
go
ALTER PROCEDURE sp_delete_jobserver
  @job_id      UNIQUEIDENTIFIER = NULL, -- Must provide either this or job_name
  @job_name    sysname          = NULL, -- Must provide either this or job_id
  @server_name sysname
AS
BEGIN
  DECLARE @retval             INT
  DECLARE @server_id          INT
  DECLARE @local_machine_name sysname

  SET NOCOUNT ON

  -- Remove any leading/trailing spaces from parameters
  SELECT @server_name = LTRIM(RTRIM(@server_name))

  IF (UPPER(@server_name collate SQL_Latin1_General_CP1_CS_AS) = '(LOCAL)')
    SELECT @server_name = UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))

  EXECUTE @retval = sp_verify_job_identifiers '@job_name',
                                              '@job_id',
                                               @job_name OUTPUT,
                                               @job_id   OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  -- First, check if the server is the local server
  EXECUTE @retval = master.dbo.xp_getnetname @local_machine_name OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure
  IF (@local_machine_name IS NOT NULL) AND (UPPER(@server_name) = UPPER(@local_machine_name))
    SELECT @server_name = UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName')))

  -- Check server name
  IF (UPPER(@server_name) <> UPPER(CONVERT(sysname, SERVERPROPERTY('ServerName'))))
  BEGIN
    SELECT @server_id = server_id
    FROM msdb.dbo.systargetservers
    WHERE (UPPER(server_name) = @server_name)
    IF (@server_id IS NULL)
    BEGIN
      RAISERROR(14262, -1, -1, '@server_name', @server_name)
      RETURN(1) -- Failure
    END
  END
  ELSE
    SELECT @server_id = 0

  -- Check that the job is indeed targeted at the server
  IF (NOT EXISTS (SELECT *
                  FROM msdb.dbo.sysjobservers
                  WHERE (job_id = @job_id)
                    AND (server_id = @server_id)))
  BEGIN
    RAISERROR(14270, -1, -1, @job_name, @server_name)
    RETURN(1) -- Failure
  END

  -- Instruct the deleted server to purge the job
  -- NOTE: We must do this BEFORE we delete the sysjobservers row
  EXECUTE @retval = sp_post_msx_operation 'DELETE', 'JOB', @job_id, @server_name

  -- Delete the sysjobservers row
  DELETE FROM msdb.dbo.sysjobservers
  WHERE (job_id = @job_id)
    AND (server_id = @server_id)

  -- We used to change the category_id to 0 when removing the last job server
  -- from a job. We no longer do this.
--  IF (NOT EXISTS (SELECT *
--                  FROM msdb.dbo.sysjobservers
--                  WHERE (job_id = @job_id)))
--  BEGIN
--    UPDATE msdb.dbo.sysjobs
--    SET category_id = 0 -- [Uncategorized (Local)]
--    WHERE (job_id = @job_id)
--  END

  -- If the job is local, make sure that SQLServerAgent removes it from cache
  IF (@server_id = 0)
  BEGIN
    EXECUTE msdb.dbo.sp_sqlagent_notify @op_type     = N'J',
                                        @job_id      = @job_id,
                                        @action_type = N'D'
  END

  RETURN(@retval) -- 0 means success
END
go


/**************************************************************/
/* Sign agent sps and add them to Off By Default component    */
/*                                                            */
/* Also sign SPs for other components located in MSDB         */
/**************************************************************/
PRINT 'Signing sps ...'
-- Create certificate to sign Agent sps
--
if exists (select * from sys.certificates where name = '##MS_AgentSigningCertificate##')
   drop certificate [##MS_AgentSigningCertificate##]

declare @certError int
dbcc traceon(4606,-1)
create certificate [##MS_AgentSigningCertificate##] 
   encryption by password = 'Yukon90_'
   with subject = 'MS_AgentSigningCertificate'
select @certError = @@error
dbcc traceoff(4606,-1)

IF (@certError <> 0)
BEGIN
    select 'Objects still signed by ##MS_AgentSigningCertificate##' = object_name(crypts.major_id) 
    from sys.crypt_properties crypts, sys.certificates certs
    where crypts.thumbprint = certs.thumbprint
    and crypts.class = 1
    and certs.name = '##MS_AgentSigningCertificate##'

    RAISERROR('Cannot create ##MS_AgentSigningCertificate## in msdb. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG
END
go

-- List all of the stored procedures we need to sign
create table #sp_table (name sysname, sign int, comp int, bNewProc int)
go
insert into #sp_table values(N'sp_sqlagent_is_srvrolemember',               1, 0, 0)
insert into #sp_table values(N'sp_verify_category_identifiers',               1, 0, 0)
insert into #sp_table values(N'sp_verify_proxy_identifiers',               1, 0, 0)
insert into #sp_table values(N'sp_verify_credential_identifiers',          1, 0, 0)
insert into #sp_table values(N'sp_verify_subsystem_identifiers',           1, 0, 0)
insert into #sp_table values(N'sp_verify_login_identifiers',               1, 0, 0)
insert into #sp_table values(N'sp_verify_proxy',                  1, 0, 0)
insert into #sp_table values(N'sp_add_proxy',                     1, 0, 0)
insert into #sp_table values(N'sp_delete_proxy',                  1, 0, 0)
insert into #sp_table values(N'sp_update_proxy',                  1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_is_member',                  1, 0, 0)
insert into #sp_table values(N'sp_verify_proxy_permissions',               1, 0, 0)
insert into #sp_table values(N'sp_help_proxy',                    1, 0, 0)
insert into #sp_table values(N'sp_grant_proxy_to_subsystem',               1, 0, 0)
insert into #sp_table values(N'sp_grant_login_to_proxy',             1, 0, 0)
insert into #sp_table values(N'sp_revoke_login_from_proxy',             1, 0, 0)
insert into #sp_table values(N'sp_revoke_proxy_from_subsystem',               1, 0, 0)
insert into #sp_table values(N'sp_enum_proxy_for_subsystem',               1, 0, 0)
insert into #sp_table values(N'sp_enum_login_for_proxy',             1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_get_startup_info',              1, 1, 0)
insert into #sp_table values(N'sp_sqlagent_has_server_access',             1, 1, 0)
insert into #sp_table values(N'sp_sem_add_message',                  1, 0, 0)
insert into #sp_table values(N'sp_sem_drop_message',                 1, 0, 0)
insert into #sp_table values(N'sp_get_message_description',             1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_get_perf_counters',             1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_notify',                  1, 1, 0)
insert into #sp_table values(N'sp_is_sqlagent_starting',             1, 1, 0)
insert into #sp_table values(N'sp_verify_job_identifiers',              1, 0, 0)
insert into #sp_table values(N'sp_verify_schedule_identifiers',               1, 0, 0)
insert into #sp_table values(N'sp_verify_jobproc_caller',               1, 0, 0)
insert into #sp_table values(N'sp_downloaded_row_limiter',              1, 1, 0)
insert into #sp_table values(N'sp_post_msx_operation',                  1, 1, 0)
insert into #sp_table values(N'sp_verify_performance_condition',           1, 0, 0)
insert into #sp_table values(N'sp_verify_job_date',                  1, 0, 0)
insert into #sp_table values(N'sp_verify_job_time',                  1, 0, 0)
insert into #sp_table values(N'sp_verify_alert',                  1, 1, 0)
insert into #sp_table values(N'sp_update_alert',                  1, 0, 0)
insert into #sp_table values(N'sp_delete_job_references',               1, 0, 0)
insert into #sp_table values(N'sp_delete_all_msx_jobs',                 1, 0, 0)
insert into #sp_table values(N'sp_generate_target_server_job_assignment_sql',       1, 0, 0)
insert into #sp_table values(N'sp_generate_server_description',               1, 1, 0)
insert into #sp_table values(N'sp_msx_set_account',                  1, 1, 0)
insert into #sp_table values(N'sp_msx_get_account',                  1, 1, 0)
insert into #sp_table values(N'sp_delete_operator',                  1, 0, 0)
insert into #sp_table values(N'sp_msx_defect',                    1, 1, 0)
insert into #sp_table values(N'sp_msx_enlist',                    1, 1, 0)
insert into #sp_table values(N'sp_delete_targetserver',                 1, 0, 0)
insert into #sp_table values(N'sp_get_sqlagent_properties',             1, 1, 0)
insert into #sp_table values(N'sp_set_sqlagent_properties',             1, 1, 0)
insert into #sp_table values(N'sp_add_targetservergroup',               1, 0, 0)
insert into #sp_table values(N'sp_update_targetservergroup',               1, 0, 0)
insert into #sp_table values(N'sp_delete_targetservergroup',               1, 0, 0)
insert into #sp_table values(N'sp_help_targetservergroup',              1, 0, 0)
insert into #sp_table values(N'sp_add_targetsvrgrp_member',             1, 0, 0)
insert into #sp_table values(N'sp_delete_targetsvrgrp_member',             1, 0, 0)
insert into #sp_table values(N'sp_verify_category',                  1, 0, 0)
insert into #sp_table values(N'sp_add_category',                  1, 0, 0)
insert into #sp_table values(N'sp_update_category',                  1, 0, 0)
insert into #sp_table values(N'sp_delete_category',                  1, 0, 0)
insert into #sp_table values(N'sp_help_category',                 1, 0, 0)
insert into #sp_table values(N'sp_help_targetserver',                1, 0, 0)
insert into #sp_table values(N'sp_resync_targetserver',                 1, 0, 0)
insert into #sp_table values(N'sp_purge_jobhistory',                 1, 0, 0)
insert into #sp_table values(N'sp_help_jobhistory',                  1, 0, 0)
insert into #sp_table values(N'sp_help_jobhistory_full',                  1, 0, 0)
insert into #sp_table values(N'sp_help_jobhistory_summary',                  1, 0, 0)
insert into #sp_table values(N'sp_help_jobhistory_sem',                  1, 0, 0)
insert into #sp_table values(N'sp_add_jobserver',                 1, 0, 0)
insert into #sp_table values(N'sp_delete_jobserver',                 1, 0, 0)
insert into #sp_table values(N'sp_help_jobserver',                1, 0, 0)
insert into #sp_table values(N'sp_help_downloadlist',                1, 0, 0)
insert into #sp_table values(N'sp_enum_sqlagent_subsystems',               1, 0, 0)
insert into #sp_table values(N'sp_enum_sqlagent_subsystems_internal', 1, 0, 0)
insert into #sp_table values(N'sp_verify_subsystem',                 1, 1, 0)
insert into #sp_table values(N'sp_verify_subsystems',                 1, 0, 0)
insert into #sp_table values(N'sp_verify_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_add_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_attach_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_detach_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_update_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_delete_schedule',                  1, 0, 0)
insert into #sp_table values(N'sp_get_jobstep_db_username',             1, 0, 0)
insert into #sp_table values(N'sp_verify_jobstep',                1, 0, 0)
insert into #sp_table values(N'sp_add_jobstep_internal',             1, 0, 0)
insert into #sp_table values(N'sp_add_jobstep',                   1, 0, 0)
insert into #sp_table values(N'sp_update_jobstep',                1, 0, 0)
insert into #sp_table values(N'sp_delete_jobstep',                1, 0, 0)
insert into #sp_table values(N'sp_help_jobstep',                  1, 0, 0)
insert into #sp_table values(N'sp_write_sysjobstep_log',             1, 0, 0)
insert into #sp_table values(N'sp_help_jobsteplog',                  1, 0, 0)
insert into #sp_table values(N'sp_delete_jobsteplog',                1, 0, 0)
insert into #sp_table values(N'sp_get_schedule_description',               1, 1, 0)
insert into #sp_table values(N'sp_add_jobschedule',                  1, 0, 0)
insert into #sp_table values(N'sp_update_replication_job_parameter',          1, 0, 0)
insert into #sp_table values(N'sp_update_jobschedule',                  1, 0, 0)
insert into #sp_table values(N'sp_delete_jobschedule',                  1, 0, 0)
insert into #sp_table values(N'sp_help_schedule',                 1, 0, 0)
insert into #sp_table values(N'sp_help_jobschedule',                 1, 0, 0)
insert into #sp_table values(N'sp_verify_job',                    1, 1, 0)
insert into #sp_table values(N'sp_add_job',                    1, 0, 0)
insert into #sp_table values(N'sp_update_job',                    1, 0, 0)
insert into #sp_table values(N'sp_delete_job',                    1, 0, 0)
insert into #sp_table values(N'sp_get_composite_job_info',              1, 1, 0)
insert into #sp_table values(N'sp_help_job',                   1, 0, 0)
insert into #sp_table values(N'sp_help_jobcount ',                1, 0, 0)
insert into #sp_table values(N'sp_help_jobs_in_schedule',               1, 0, 0)
insert into #sp_table values(N'sp_manage_jobs_by_login',             1, 0, 0)
insert into #sp_table values(N'sp_apply_job_to_targets',             1, 0, 0)
insert into #sp_table values(N'sp_remove_job_from_targets',             1, 0, 0)
insert into #sp_table values(N'sp_get_job_alerts',                1, 0, 0)
insert into #sp_table values(N'sp_convert_jobid_to_char',               1, 0, 0)
insert into #sp_table values(N'sp_start_job',                     1, 0, 0)
insert into #sp_table values(N'sp_stop_job',                   1, 0, 0)
insert into #sp_table values(N'sp_cycle_agent_errorlog',             1, 0, 0)
insert into #sp_table values(N'sp_get_chunked_jobstep_params',             1, 0, 0)
insert into #sp_table values(N'sp_check_for_owned_jobs',             1, 0, 0)
insert into #sp_table values(N'sp_check_for_owned_jobsteps',               1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_refresh_job',             1, 0, 0)
insert into #sp_table values(N'sp_jobhistory_row_limiter',              1, 1, 0)
insert into #sp_table values(N'sp_sqlagent_log_jobhistory',             1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_check_msx_version',             1, 0, 0)
insert into #sp_table values(N'sp_sqlagent_probe_msx',                  1, 0, 0)
insert into #sp_table values(N'sp_set_local_time',                1, 1, 0)
insert into #sp_table values(N'sp_multi_server_job_summary',               1, 0, 0)
insert into #sp_table values(N'sp_target_server_summary',               1, 0, 0)
insert into #sp_table values(N'sp_uniquetaskname',                1, 0, 0)
insert into #sp_table values(N'sp_addtask',                    1, 0, 0)
insert into #sp_table values(N'sp_droptask',                   1, 0, 0)
insert into #sp_table values(N'sp_add_alert_internal',                  1, 0, 0)
insert into #sp_table values(N'sp_add_alert',                     1, 0, 0)
insert into #sp_table values(N'sp_delete_alert',                  1, 0, 0)
insert into #sp_table values(N'sp_help_alert',                    1, 0, 0)
insert into #sp_table values(N'sp_verify_operator',                  1, 0, 0)
insert into #sp_table values(N'sp_add_operator',                  1, 0, 0)
insert into #sp_table values(N'sp_update_operator',                  1, 1, 0)
insert into #sp_table values(N'sp_help_operator',                 1, 0, 0)
insert into #sp_table values(N'sp_help_operator_jobs',                  1, 0, 0)
insert into #sp_table values(N'sp_verify_operator_identifiers',               1, 0, 0)
insert into #sp_table values(N'sp_notify_operator',                  1, 0, 0)
insert into #sp_table values(N'sp_verify_notification',                 1, 0, 0)
insert into #sp_table values(N'sp_add_notification',                 1, 0, 0)
insert into #sp_table values(N'sp_update_notification',                 1, 0, 0)
insert into #sp_table values(N'sp_delete_notification',                 1, 0, 0)
insert into #sp_table values(N'sp_help_notification',                1, 0, 0)
insert into #sp_table values(N'sp_help_jobactivity',                 1, 0, 0)
insert into #sp_table values(N'sp_enlist_tsx',                    1, 1, 0)
insert into #sp_table values(N'trig_targetserver_insert',               1, 0, 0)

-- Database Mail configuration procs
insert into #sp_table values(N'sysmail_verify_accountparams_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_verify_principal_sp',               1, 0, 0)
insert into #sp_table values(N'sysmail_verify_profile_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_verify_account_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_add_profile_sp',                 1, 0, 0)
insert into #sp_table values(N'sysmail_update_profile_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_delete_profile_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_help_profile_sp',             1, 0, 0)
insert into #sp_table values(N'sysmail_create_user_credential_sp',            1, 0, 0)
insert into #sp_table values(N'sysmail_alter_user_credential_sp',          1, 0, 0)
insert into #sp_table values(N'sysmail_drop_user_credential_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_add_account_sp',                 1, 0, 0)
insert into #sp_table values(N'sysmail_update_account_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_delete_account_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_help_account_sp',             1, 0, 0)
insert into #sp_table values(N'sysmail_help_admin_account_sp',             1, 0, 0)
insert into #sp_table values(N'sysmail_add_profileaccount_sp',             1, 0, 0)
insert into #sp_table values(N'sysmail_update_profileaccount_sp',          1, 0, 0)
insert into #sp_table values(N'sysmail_delete_profileaccount_sp',          1, 0, 0)
insert into #sp_table values(N'sysmail_help_profileaccount_sp',               1, 0, 0)
insert into #sp_table values(N'sysmail_configure_sp',                1, 0, 0)
insert into #sp_table values(N'sysmail_help_configure_sp',              1, 0, 0)
insert into #sp_table values(N'sysmail_help_configure_value_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_add_principalprofile_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_update_principalprofile_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_delete_principalprofile_sp',           1, 0, 0)
insert into #sp_table values(N'sysmail_help_principalprofile_sp',          1, 0, 0)

-- Database Mail: mail host database specific procs
insert into #sp_table values(N'sysmail_start_sp',             1, 2, 0)
insert into #sp_table values(N'sysmail_stop_sp',              1, 2, 0)
insert into #sp_table values(N'sysmail_logmailevent_sp',      1, 0, 0)
insert into #sp_table values(N'sp_SendMailMessage',           1, 0, 0)
insert into #sp_table values(N'sp_isprohibited',              1, 0, 0)
insert into #sp_table values(N'sp_SendMailQueues',            1, 0, 0)
insert into #sp_table values(N'sp_ProcessResponse',           1, 0, 0)
insert into #sp_table values(N'sp_MailItemResultSets',        1, 0, 0)
insert into #sp_table values(N'sp_process_DialogTimer',       1, 0, 0)
insert into #sp_table values(N'sp_readrequest',               1, 0, 0)
insert into #sp_table values(N'sp_GetAttachmentData',         1, 0, 0)
insert into #sp_table values(N'sp_RunMailQuery',              1, 0, 0)
insert into #sp_table values(N'sysmail_help_queue_sp',        1, 0, 0)
insert into #sp_table values(N'sysmail_help_status_sp',       1, 2, 0)
insert into #sp_table values(N'sysmail_delete_mailitems_sp',  1, 0, 0)
insert into #sp_table values(N'sysmail_delete_log_sp',        1, 0, 0)
insert into #sp_table values(N'sp_send_dbmail',               1, 2, 0)
insert into #sp_table values(N'sp_ExternalMailQueueListener', 1, 0, 0)
insert into #sp_table values(N'sp_sysmail_activate',          1, 0, 0)
insert into #sp_table values(N'sp_get_script',                1, 0, 0)

-- Maintenance Plans
insert into #sp_table values(N'sp_maintplan_delete_log',             1, 0, 0)
insert into #sp_table values(N'sp_maintplan_delete_subplan',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_open_logentry',             1, 0, 0)
insert into #sp_table values(N'sp_maintplan_close_logentry',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_update_log',             1, 0, 0)
insert into #sp_table values(N'sp_maintplan_update_subplan',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_delete_plan',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_start',                  1, 0, 0)
insert into #sp_table values(N'sp_clear_dbmaintplan_by_db',             1, 0, 0)
insert into #sp_table values(N'sp_add_maintenance_plan',             1, 0, 0)
insert into #sp_table values(N'sp_delete_maintenance_plan',             1, 0, 0)
insert into #sp_table values(N'sp_add_maintenance_plan_db',             1, 0, 0)
insert into #sp_table values(N'sp_delete_maintenance_plan_db',             1, 0, 0)
insert into #sp_table values(N'sp_add_maintenance_plan_job',               1, 1, 0)
insert into #sp_table values(N'sp_delete_maintenance_plan_job',               1, 0, 0)
insert into #sp_table values(N'sp_help_maintenance_plan',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_update_subplan_tsx',               1, 0, 0)
insert into #sp_table values(N'sp_maintplan_subplans_by_job',               1, 0, 0)

-- Log Shipping
insert into #sp_table values(N'sp_add_log_shipping_monitor_jobs',          1, 0, 0)
insert into #sp_table values(N'sp_add_log_shipping_primary',               1, 0, 0)
insert into #sp_table values(N'sp_add_log_shipping_secondary',             1, 0, 0)
insert into #sp_table values(N'sp_delete_log_shipping_monitor_jobs',          1, 0, 0)
insert into #sp_table values(N'sp_delete_log_shipping_primary',               1, 0, 0)
insert into #sp_table values(N'sp_delete_log_shipping_secondary ',            1, 0, 0)
insert into #sp_table values(N'sp_log_shipping_in_sync',             1, 0, 0)
insert into #sp_table values(N'sp_log_shipping_get_date_from_file ',          1, 0, 0)
insert into #sp_table values(N'sp_get_log_shipping_monitor_info',          1, 0, 0)
insert into #sp_table values(N'sp_update_log_shipping_monitor_info',          1, 0, 0)
insert into #sp_table values(N'sp_delete_log_shipping_monitor_info',          1, 0, 0)
insert into #sp_table values(N'sp_remove_log_shipping_monitor_account',          1, 0, 0)
insert into #sp_table values(N'sp_log_shipping_monitor_backup',               1, 0, 0)
insert into #sp_table values(N'sp_log_shipping_monitor_restore',           1, 0, 0)
insert into #sp_table values(N'sp_change_monitor_role',                 1, 0, 0)
insert into #sp_table values(N'sp_create_log_shipping_monitor_account',          1, 0, 0)

-- DTS
insert into #sp_table values(N'sp_get_dtsversion',                1, 0, 0)
insert into #sp_table values(N'sp_make_dtspackagename',                 1, 0, 0)
insert into #sp_table values(N'sp_add_dtspackage',                1, 0, 0)
insert into #sp_table values(N'sp_drop_dtspackage',                  1, 0, 0)
insert into #sp_table values(N'sp_reassign_dtspackageowner',               1, 0, 0)
insert into #sp_table values(N'sp_get_dtspackage',                1, 0, 0)
insert into #sp_table values(N'sp_reassign_dtspackagecategory',               1, 0, 0)
insert into #sp_table values(N'sp_enum_dtspackages',                 1, 0, 0)
insert into #sp_table values(N'sp_add_dtscategory',                  1, 0, 0)
insert into #sp_table values(N'sp_drop_dtscategory',                 1, 0, 0)
insert into #sp_table values(N'sp_modify_dtscategory',                  1, 0, 0)
insert into #sp_table values(N'sp_enum_dtscategories',                  1, 0, 0)
insert into #sp_table values(N'sp_log_dtspackage_begin',             1, 0, 0)
insert into #sp_table values(N'sp_log_dtspackage_end',                  1, 0, 0)
insert into #sp_table values(N'sp_log_dtsstep_begin',                1, 0, 0)
insert into #sp_table values(N'sp_log_dtsstep_end',                  1, 0, 0)
insert into #sp_table values(N'sp_log_dtstask',                   1, 0, 0)
insert into #sp_table values(N'sp_enum_dtspackagelog',                  1, 0, 0)
insert into #sp_table values(N'sp_enum_dtssteplog',                  1, 0, 0)
insert into #sp_table values(N'sp_enum_dtstasklog',                  1, 0, 0)
insert into #sp_table values(N'sp_dump_dtslog_all',                  1, 0, 0)
insert into #sp_table values(N'sp_dump_dtspackagelog',                  1, 0, 0)
insert into #sp_table values(N'sp_dump_dtssteplog',                  1, 0, 0)
insert into #sp_table values(N'sp_dump_dtstasklog',                  1, 0, 0)
insert into #sp_table values(N'sp_dts_addlogentry',                  1, 0, 0)
insert into #sp_table values(N'sp_dts_listpackages',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_listfolders',                  1, 0, 0)
insert into #sp_table values(N'sp_dts_deletepackage',                1, 0, 0)
insert into #sp_table values(N'sp_dts_deletefolder',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_getpackage',                1, 0, 0)
insert into #sp_table values(N'sp_dts_getfolder',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_putpackage',                1, 0, 0)
insert into #sp_table values(N'sp_dts_addfolder',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_renamefolder',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_setpackageroles',                 1, 0, 0)
insert into #sp_table values(N'sp_dts_getpackageroles',                 1, 0, 0)
go

/**************************************************************/
/* Mark system objects                                        */
/**************************************************************/
declare  @start datetime
        ,@name  sysname
select @start = start from #sysdbupg
declare newsysobjs cursor for select name from sys.objects where schema_id = 1 and create_date >= @start
open newsysobjs
fetch next from newsysobjs into @name
while @@fetch_status = 0
begin
   Exec sp_MS_marksystemobject @name
   update #sp_table set bNewProc = 1 where name = @name
   fetch next from newsysobjs into @name
end
deallocate newsysobjs
drop table #sysdbupg
go


BEGIN TRANSACTION
declare @sp sysname
declare @exec_str nvarchar(1024)
declare @sign int
declare @comp int
declare @bNewProc int
declare ms_crs_sps cursor global for select name, sign, comp, bNewProc from #sp_table 
open ms_crs_sps
fetch next from ms_crs_sps into @sp, @sign, @comp, @bNewProc
while @@fetch_status = 0
begin
   if exists(select * from sys.objects where name = @sp)
   begin
      print 'processing sp: ' + @sp
      if (@sign = 1)
      begin
         set @exec_str = N'add signature to ' + @sp + N' by certificate [##MS_AgentSigningCertificate##] with password = ''Yukon90_'''
         Execute(@exec_str)
         if (@@error <> 0)
         begin
            declare @err_str nvarchar(1024)
            set @err_str = 'Cannot sign stored procedure ' + @sp + '. Terminating.'
            RAISERROR(@err_str, 20, 127) WITH LOG
            ROLLBACK TRANSACTION
            return
         end
      end

      -- If there is a new procedure that goes in a component, put it there
      if (@comp > 0 and @bNewProc > 0)
      begin
         if (@comp = 1) -- SQLAgent
             set @exec_str = N'exec sp_AddFunctionalUnitToComponent N''Agent XPs'', N''' + @sp + N''''

         else if (@comp = 2) -- DbMail
             set @exec_str = N'exec sp_AddFunctionalUnitToComponent N''Database Mail XPs'', N''' + @sp + N''''
 
         Execute(@exec_str)
         if (@@error <> 0)
         begin
            RAISERROR('Cannot add stored procedure to component. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG
            ROLLBACK TRANSACTION
            return
         end
      end

   end
   fetch next from ms_crs_sps into @sp, @sign, @comp, @bNewProc
end
close ms_crs_sps
deallocate ms_crs_sps
COMMIT TRANSACTION
go
drop table #sp_table
go

-- drop certificate private key
alter certificate [##MS_AgentSigningCertificate##] remove private key

IF (@@error <> 0)
   RAISERROR('Cannot alter ##MS_AgentSigningCertificate## in msdb. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG
go


--create a temporary database in order to get the path to the 'Data' folder
--because upon upgrade existing database are in temporary folder
IF (EXISTS (SELECT name
                FROM master.dbo.sysdatabases
                WHERE (name = N'temp_MS_AgentSigningCertificate_database')))
BEGIN
  DROP DATABASE temp_MS_AgentSigningCertificate_database
END
go
CREATE DATABASE temp_MS_AgentSigningCertificate_database
go
-- export certificate to master
-- use current directory to persist the file
--
DECLARE @certificate_name NVARCHAR(520)

SELECT @certificate_name = SUBSTRING(filename, 1, CHARINDEX(N'temp_MS_AgentSigningCertificate_database.mdf', filename) - 1) + 
                           CONVERT(NVARCHAR(520), NEWID()) + N'.cer'
  FROM master.dbo.sysaltfiles
  WHERE (name = N'temp_MS_AgentSigningCertificate_database')
  
EXECUTE(N'backup certificate [##MS_AgentSigningCertificate##] to file = ''' + @certificate_name + '''')

IF (@@error <> 0)
   RAISERROR('Cannot backup ##MS_AgentSigningCertificate##. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG

use master

if exists (select * from sys.database_principals where name = '##MS_AgentSigningCertificate##')
   drop user [##MS_AgentSigningCertificate##]

if exists (select * from sys.server_principals where name = '##MS_AgentSigningCertificate##')
   drop login [##MS_AgentSigningCertificate##]

if exists (select * from sys.certificates where name = '##MS_AgentSigningCertificate##')
   drop certificate [##MS_AgentSigningCertificate##]

execute(N'create certificate [##MS_AgentSigningCertificate##] from file = ''' + @certificate_name + '''')
IF (@@error <> 0)
   RAISERROR('Cannot create ##MS_AgentSigningCertificate## certificate in master. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG

-- create login
--
create login [##MS_AgentSigningCertificate##] from certificate [##MS_AgentSigningCertificate##]
IF (@@error <> 0)
   RAISERROR('Cannot create ##MS_AgentSigningCertificate## login. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG

-- create certificate based user for execution granting
--
create user [##MS_AgentSigningCertificate##] for certificate [##MS_AgentSigningCertificate##]
IF (@@error <> 0)
   RAISERROR('Cannot create ##MS_AgentSigningCertificate## user. SYSDBUPG.SQL terminating.', 20, 127) WITH LOG

-- enable certificate for OBD
--
exec sys.sp_SetOBDCertificate N'##MS_AgentSigningCertificate##',N'ON'

grant execute to [##MS_AgentSigningCertificate##]

use msdb
go

-- Refresh Subsystem list now that sp_verify_subsystems has been
-- signed and our special ##MS_AgentSigningCertificate## exists. We
-- have to do this after the certificate exists because
-- sp_verify_subsystems makes calls to xp_regread and xp_fileexist,
-- which are extended procedures that, if disabled, are only available
-- to procedures signed by special certificates like ours. If SSIS is
-- not installed but SSMS is installed this call will make SSIS
-- subsystem available to Agent jobs.
exec sp_verify_subsystems 1
go

-- drop temporary database
IF (EXISTS (SELECT name
                FROM master.dbo.sysdatabases
                WHERE (name = N'temp_MS_AgentSigningCertificate_database')))
BEGIN
  DROP DATABASE temp_MS_AgentSigningCertificate_database
END
go

PRINT 'Succesfully signed sps'
--
-- End of signing sps
go

USE msdb
go

/**************************************************************/
/* Drop auxilary procedure to enable OBD component          */
/**************************************************************/
DROP PROCEDURE #sp_enable_component 
go
DROP PROCEDURE #sp_restore_component_state 
go

--------------------------------------------------------------------------------
--	REPL_MASTER.SQL
--------------------------------------------------------------------------------
