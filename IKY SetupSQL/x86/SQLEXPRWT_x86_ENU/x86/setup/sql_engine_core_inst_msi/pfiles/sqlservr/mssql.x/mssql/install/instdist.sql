--***************************************************************************
-- Copyright (c) Microsoft Corporation.
-- All Rights Reserved
--
-- @File: instdist.sql
--
-- Purpose:
--  replication procedures for distribution database
--  
-- Notes:
--
-- History:
--
--     @Version: Yukon
--
-- @EndHeader@
--
--***************************************************************************

if (    (db_id()     = 1)  -- 'master' db
    OR
        is_srvrolemember('sysadmin') <> 1  -- SA
   )
    begin
    raiserror(21760,11,127)  -- State=127 should halt ISQL.EXE
    end

if (    (db_id()     = 1)  -- 'master' db
    OR
        is_srvrolemember('sysadmin') <> 1 -- SA
   )
    begin
    raiserror(21761,22,127) with log   -- SeverityLevel>=19 kills spid.
    end
go

EXEC dbo.sp_configure 'allow updates', 1
GO
reconfigure with override
GO

set ANSI_NULLS off
go

--
-- Check and make sure the database has the correct compatibility level
--
declare @dbname sysname
		,@cmptlevelmaster tinyint
		,@cmptlevel tinyint
		
select  @dbname = db_name()
select 	@cmptlevelmaster = cmptlevel from master.dbo.sysdatabases where name = 'master'
select 	@cmptlevel = cmptlevel from master.dbo.sysdatabases where name = @dbname
if (@cmptlevel != @cmptlevelmaster)
begin
    if (@@nestlevel = 0)
    begin
	    raiserror(21762,10, 1, @dbname, @cmptlevel, @cmptlevelmaster)    
	    exec dbo.sp_dbcmptlevel @dbname, @cmptlevelmaster
    end
end
go

/****************************************************************************/
PRINT ''
PRINT 'Creating distribution tables'
PRINT ''
/****************************************************************************/
EXEC dbo.sp_MScreate_dist_tables
go

/****************************************************************************/
PRINT ''
PRINT 'Dropping all distribution stored procedures and functions that are now in resource or are obsolete'
PRINT ''
/****************************************************************************/
IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_repl_command' and type = 'P')
      DROP PROCEDURE sp_MSadd_repl_command

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MScheckretention' and type = 'P')
      DROP PROCEDURE sp_MScheckretention

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSpersistPerfNumber' and type = 'P')
      DROP PROCEDURE sp_MSpersistPerfNumber

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MScheck_Jet_Subscriber' and type = 'P')
      DROP PROCEDURE sp_MScheck_Jet_Subscriber

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_replcmds_mcit' and type = 'P')
      DROP PROCEDURE sp_MSadd_replcmds_mcit

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_repl_commands27hp' and type = 'P')
      DROP PROCEDURE sp_MSadd_repl_commands27hp

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSrefresh_anonymous' and type = 'P')
      DROP PROCEDURE sp_MSrefresh_anonymous
      
IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_subscription' and type = 'P')
      DROP PROCEDURE sp_MSadd_subscription

IF EXISTS (SELECT * FROM sys.objects WHERE                    
   name = 'sp_MSdrop_subscription' and type = 'P')
      DROP PROCEDURE sp_MSdrop_subscription

if exists (select * from sys.objects where 
	type = 'P' and name = 'sp_MSfetchAdjustidentityrange')
	drop procedure sp_MSfetchAdjustidentityrange

IF EXISTS (SELECT * FROM sys.objects WHERE   
    name = 'sp_MSupdate_subscription' and type = 'P')
       DROP PROCEDURE sp_MSupdate_subscription

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSget_repl_commands' and type = 'P')
       DROP PROCEDURE sp_MSget_repl_commands

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSget_repl_cmds_anonymous' and type = 'P')
       DROP PROCEDURE sp_MSget_repl_cmds_anonymous

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSadd_anonymous_agent' and type = 'P')
       DROP PROCEDURE sp_MSadd_anonymous_agent

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSanonymous_status' and type = 'P')
       DROP PROCEDURE sp_MSanonymous_status

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSsubscription_status' and type = 'P')
       DROP PROCEDURE sp_MSsubscription_status
GO    

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSget_last_transaction' and type = 'P')
      DROP PROCEDURE sp_MSget_last_transaction
    

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_subscriber_info' and type = 'P')
      DROP PROCEDURE sp_MSadd_subscriber_info

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSadd_subscriber_schedule' and type = 'P')
      DROP PROCEDURE sp_MSadd_subscriber_schedule

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSupdate_subscriber_info' and type = 'P')
      DROP PROCEDURE sp_MSupdate_subscriber_info

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSupdate_subscriber_schedule' and type = 'P')
      DROP PROCEDURE sp_MSupdate_subscriber_schedule

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MSdrop_subscriber_info' and type = 'P')
      DROP PROCEDURE sp_MSdrop_subscriber_info

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MShelp_subscriber_info' and type = 'P')
      DROP PROCEDURE sp_MShelp_subscriber_info

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdistribution_counters' and type = 'P')
      DROP PROCEDURE sp_MSdistribution_counters

IF EXISTS (select * from sys.objects where
   name = 'sp_MSset_snapshot_xact_seqno' and type = 'P')
      DROP PROCEDURE sp_MSset_snapshot_xact_seqno

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_snapshot_history' and type = 'P')
      DROP PROCEDURE sp_MSadd_snapshot_history

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_logreader_history' and type = 'P')
      DROP PROCEDURE sp_MSadd_logreader_history

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_distribution_history' and type = 'P')
      DROP PROCEDURE sp_MSadd_distribution_history

IF EXISTS (select * from sys.objects where
   name = 'sp_MSreplremoveuncdir' and type = 'P')
      DROP PROCEDURE sp_MSreplremoveuncdir

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_snapshot_dirs' and type = 'P')
      DROP PROCEDURE sp_MSdrop_snapshot_dirs

IF EXISTS (select * from sys.objects where
   name = 'sp_MSfast_delete_trans' and type = 'P')
      DROP PROCEDURE sp_MSfast_delete_trans

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_subscriptions' and type = 'P')
      DROP PROCEDURE sp_MSenum_subscriptions

IF EXISTS (select * from sys.objects where
   name = 'sp_MSIfExistsSubscription' and type = 'P')
      DROP PROCEDURE sp_MSIfExistsSubscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_snapshot' and type = 'P')
      DROP PROCEDURE sp_MSenum_snapshot
      
IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_merge_anonymous_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_merge_anonymous_agent
    
IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_snapshot_s' and type = 'P')
      DROP PROCEDURE sp_MSenum_snapshot_s

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_snapshot_sd' and type = 'P')
      DROP PROCEDURE sp_MSenum_snapshot_sd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_logreader' and type = 'P')
      DROP PROCEDURE sp_MSenum_logreader

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_logreader_s' and type = 'P')
      DROP PROCEDURE sp_MSenum_logreader_s

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_logreader_sd' and type = 'P')
      DROP PROCEDURE sp_MSenum_logreader_sd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_qreader' and type = 'P')
      DROP PROCEDURE sp_MSenum_qreader

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_qreader_s' and type = 'P')
      DROP PROCEDURE sp_MSenum_qreader_s

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_qreader_sd' and type = 'P')
      DROP PROCEDURE sp_MSenum_qreader_sd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_distribution' and type = 'P')
      DROP PROCEDURE sp_MSenum_distribution

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_distribution_s' and type = 'P')
      DROP PROCEDURE sp_MSenum_distribution_s

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MShelp_subscription_status' and type = 'P')
      DROP PROCEDURE sp_MShelp_subscription_status

IF EXISTS (SELECT * FROM sys.objects WHERE
   name = 'sp_MScleanup_agent_entry' and type = 'P')
      DROP PROCEDURE sp_MScleanup_agent_entry

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_distribution_sd' and type = 'P')
      DROP PROCEDURE sp_MSenum_distribution_sd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_merge' and type = 'P')
      DROP PROCEDURE sp_MSenum_merge

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_merge_s' and type = 'P')
      DROP PROCEDURE sp_MSenum_merge_s

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_merge_sd' and type = 'P')
      DROP PROCEDURE sp_MSenum_merge_sd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSgetagentoffloadinfo' and type = 'P')
      DROP PROCEDURE sp_MSgetagentoffloadinfo

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenableagentoffload' and type = 'P')
      DROP PROCEDURE sp_MSenableagentoffload

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdisableagentoffload' and type = 'P')
      DROP PROCEDURE sp_MSdisableagentoffload 

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_repl_error' and type = 'P')
      DROP PROCEDURE sp_MSadd_repl_error

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_repl_alert' and type = 'P')
      DROP PROCEDURE sp_MSadd_repl_alert

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_replmergealert' and type = 'P')
      DROP PROCEDURE sp_MSadd_replmergealert

IF EXISTS (select * from sys.objects where
   name = 'sp_MSget_new_errorid' and type = 'P')
      DROP PROCEDURE sp_MSget_new_errorid

IF EXISTS (select * from sys.objects where
   name = 'sp_MSget_repl_error' and type = 'P')
      DROP PROCEDURE sp_MSget_repl_error

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_merge_history' and type = 'P')
      DROP PROCEDURE sp_MSadd_merge_history

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdist_activate_auto_sub' and type = 'P')
      DROP PROCEDURE sp_MSdist_activate_auto_sub

IF EXISTS (select * from sys.objects where
   name = 'sp_MSlock_auto_sub' and type = 'P')
      DROP PROCEDURE sp_MSlock_auto_sub

IF EXISTS (select * from sys.objects where
   name = 'sp_MSget_new_xact_seqno' and type = 'P')
      DROP PROCEDURE sp_MSget_new_xact_seqno

IF EXISTS (select * from sys.objects where
   name = 'sp_MSvalidate_distpublisher' and type = 'P')
      DROP PROCEDURE sp_MSvalidate_distpublisher

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_publication' and type = 'P')
      DROP PROCEDURE sp_MSadd_publication

IF EXISTS (select * from sys.objects where
   name = 'sp_MSchange_publication' and type = 'P')
      DROP PROCEDURE sp_MSchange_publication

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_article' and type = 'P')
      DROP PROCEDURE sp_MSadd_article

IF EXISTS (select * from sys.objects where
   name = 'sp_MSchange_article' and type = 'P')
      DROP PROCEDURE sp_MSchange_article

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_publication' and type = 'P')
      DROP PROCEDURE sp_MSdrop_publication

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_article' and type = 'P')
      DROP PROCEDURE sp_MSdrop_article

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_publication' and type = 'P')
      DROP PROCEDURE sp_MShelp_publication

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_article' and type = 'P')
      DROP PROCEDURE sp_MShelp_article

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_subscription' and type = 'P')
      DROP PROCEDURE sp_MShelp_subscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_subscription_3rd' and type = 'P')
      DROP PROCEDURE sp_MSadd_subscription_3rd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_subscription_3rd' and type = 'P')
      DROP PROCEDURE sp_MSdrop_subscription_3rd

IF EXISTS (select * from sys.objects where
   name = 'sp_MSactivate_subscriptions' and type = 'P')
      DROP PROCEDURE sp_MSactivate_subscriptions

IF EXISTS (select * from sys.objects where
   name = 'sp_MSrepl_raiserror' and type = 'P')
      DROP PROCEDURE sp_MSrepl_raiserror

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_merge_subscription' and type = 'P')
      DROP PROCEDURE sp_MSadd_merge_subscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_merge_subscription' and type = 'P')
      DROP PROCEDURE sp_MSdrop_merge_subscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_merge_subscriptions' and type = 'P')
      DROP PROCEDURE sp_MSenum_merge_subscriptions

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_snapshot_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_snapshot_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_snapshot_agent' and type = 'P')
      DROP PROCEDURE sp_MSdrop_snapshot_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_logreader_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_logreader_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_logreader_agent' and type = 'P')
      DROP PROCEDURE sp_MSdrop_logreader_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_distribution_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_distribution_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_distribution_agent' and type = 'P')
      DROP PROCEDURE sp_MSdrop_distribution_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_distribution_agentid' and type = 'P')
      DROP PROCEDURE sp_MSdrop_distribution_agentid

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_merge_agentid' and type = 'P')
      DROP PROCEDURE sp_MSdrop_merge_agentid

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_merge_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_merge_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_merge_agent' and type = 'P')
      DROP PROCEDURE sp_MSdrop_merge_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_qreader_agent' and type = 'P')
      DROP PROCEDURE sp_MSadd_qreader_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadd_qreader_history' and type = 'P')
      DROP PROCEDURE sp_MSadd_qreader_history

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_qreader_agent' and type = 'P')
      DROP PROCEDURE sp_MSdrop_qreader_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_qreader_history' and type = 'P')
      DROP PROCEDURE sp_MSdrop_qreader_history

IF EXISTS (select name from sys.objects where 
   name = 'sp_update_agent_profile' and type = 'P')
    DROP PROCEDURE sp_update_agent_profile

IF EXISTS (select name from sys.objects where 
   name = 'sp_MSprofile_in_use' and type = 'P')
    DROP PROCEDURE sp_MSprofile_in_use

IF EXISTS (select * from sys.objects where
   name = 'sp_MSreset_subscription' and type = 'P')
      DROP PROCEDURE sp_MSreset_subscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSget_subscription_guid' and type = 'P')
      DROP PROCEDURE sp_MSget_subscription_guid

IF EXISTS (select * from sys.objects where
   name = 'sp_MSreset_subscription_seqno' and type = 'P')
      DROP PROCEDURE sp_MSreset_subscription_seqno

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_profile' and type = 'P')
      DROP PROCEDURE sp_MShelp_profile

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_snapshot_agentid' and type = 'P')
      DROP PROCEDURE sp_MShelp_snapshot_agentid

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_logreader_agentid' and type = 'P')
      DROP PROCEDURE sp_MShelp_logreader_agentid

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_merge_agentid' and type = 'P')
      DROP PROCEDURE sp_MShelp_merge_agentid

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_replication_status' and type = 'P')
      DROP PROCEDURE sp_MSenum_replication_status

IF EXISTS (select * from sys.objects where
   name = 'sp_MSagent_stethoscope' and type = 'P')
      DROP PROCEDURE sp_MSagent_stethoscope

IF EXISTS (select * from sys.objects where
   name = 'sp_MSlock_distribution_agent' and type = 'P')
      DROP PROCEDURE sp_MSlock_distribution_agent

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdetect_nonlogged_shutdown' and type = 'P')
      DROP PROCEDURE sp_MSdetect_nonlogged_shutdown

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdistpublisher_cleanup' and type = 'P')
      DROP PROCEDURE sp_MSdistpublisher_cleanup

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenumerate_PAL' and type = 'P')
      DROP PROCEDURE sp_MSenumerate_PAL
      
IF EXISTS (select * from sys.objects where
   name = 'sp_MSpublication_access' and type = 'P')
      DROP PROCEDURE sp_MSpublication_access

IF EXISTS (select * from sys.objects where
   name = 'sp_MScheck_pull_access' and type = 'P')
      DROP PROCEDURE sp_MScheck_pull_access

GO
IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_6x_publication' and type = 'P')
      DROP PROCEDURE sp_MSdrop_6x_publication

IF EXISTS (select * from sys.objects where
   name = 'sp_MShelp_distribution_agentid' and type = 'P')
      DROP PROCEDURE sp_MShelp_distribution_agentid
GO

IF EXISTS (select * from sys.objects where
   name = 'sp_MScheck_tran_retention' and type = 'P')
      DROP PROCEDURE sp_MScheck_tran_retention
GO

IF EXISTS (select * from sys.objects where
   name = 'sp_MSreinit_subscription' and type = 'P')
      DROP PROCEDURE sp_MSreinit_subscription
go

IF EXISTS (select * from sys.objects where
   name = 'sp_MSmarkreinit' and type = 'P')
      DROP PROCEDURE sp_MSmarkreinit
go

IF EXISTS (select * from sys.objects where
   name = 'sp_MSbrowsesnapshotfolder' and type = 'P')
      DROP PROCEDURE sp_MSbrowsesnapshotfolder
go

IF EXISTS (select * from sys.objects where
   name = 'sp_MSquery_syncstates' and type = 'P')
      DROP PROCEDURE sp_MSquery_syncstates
go

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdist_adjust_identity' and type = 'P')
      DROP PROCEDURE sp_MSdist_adjust_identity

IF EXISTS (select * from sys.objects where
   name = 'sp_MSchange_subscription_dts_info' and type = 'P')
      DROP PROCEDURE sp_MSchange_subscription_dts_info

IF EXISTS (select * from sys.objects where
   name = 'sp_MSget_subscription_dts_info' and type = 'P')
      DROP PROCEDURE sp_MSget_subscription_dts_info
go

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenumdistributionagentproperties' and type = 'P')
      DROP PROCEDURE sp_MSenumdistributionagentproperties

IF EXISTS (select * from sys.objects where
   name = 'sp_MSenum_merge_agent_properties' and type = 'P')
      DROP PROCEDURE sp_MSenum_merge_agent_properties

IF EXISTS (select * from sys.objects where
   name = 'sp_MSinsert_identity' and type = 'P')
      DROP PROCEDURE sp_MSinsert_identity

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadjust_pub_identity' and type = 'P')
      DROP PROCEDURE sp_MSadjust_pub_identity    

IF EXISTS (select * from sys.objects where
   name = 'sp_MScheck_pub_identity' and type = 'P')
      DROP PROCEDURE sp_MScheck_pub_identity    

IF EXISTS (select * from sys.objects where
   name = 'sp_dropanonymoussubscription' and type = 'P')
      DROP PROCEDURE sp_dropanonymoussubscription

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdrop_anonymous_entry' and type = 'P')
      DROP PROCEDURE sp_MSdrop_anonymous_entry

IF EXISTS (select * from sys.objects where
   name = 'sp_MSadddynamicsnapshotjobatdistributor' and type = 'P')
      DROP PROCEDURE sp_MSadddynamicsnapshotjobatdistributor

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdeleterepljob' and type = 'P')
      DROP PROCEDURE sp_MSdeleterepljob

IF EXISTS (select * from sys.objects where
   name = 'sp_MSdeletefoldercontents' and type = 'P')
      DROP PROCEDURE sp_MSdeletefoldercontents

IF EXISTS (select * from sys.objects where
   name = 'sp_MSinvalidate_snapshot' and type = 'P')
      DROP PROCEDURE sp_MSinvalidate_snapshot

IF EXISTS (select * from sys.objects where
   name = 'sp_MSrepl_init_backup_lsns' and type = 'P')
      DROP PROCEDURE sp_MSrepl_init_backup_lsns

IF EXISTS (select * from sys.objects where
   name = 'sp_MSispublicationqueued' and type = 'P')
      DROP PROCEDURE sp_MSispublicationqueued

if exists (select * from sys.objects 
        where type = 'P' and
        name = 'sp_MSwritemergeperfcounter')
        drop procedure sp_MSwritemergeperfcounter

if exists (select * from sys.objects 
        where type = 'P' and
        name = 'sp_browseagentcmds')
        drop procedure sp_browseagentcmds

IF EXISTS (SELECT * FROM sys.objects WHERE
    name = 'sp_MSsetupnosyncsubwithlsnatdist' and type = 'P')
        DROP PROCEDURE sp_MSsetupnosyncsubwithlsnatdist
go

if object_id('dbo.sp_MSadd_tracer_history', 'local') is not null
	drop procedure dbo.sp_MSadd_tracer_history
go
if object_id('dbo.sp_MSupdate_subscriber_tracer_history', 'local') is not null
	drop procedure dbo.sp_MSupdate_subscriber_tracer_history
go
if object_id('dbo.sp_MSupdate_tracer_history', 'local') is not null
	drop procedure dbo.sp_MSupdate_tracer_history
go
if object_id('dbo.sp_MSdelete_tracer_history', 'local') is not null
	drop procedure dbo.sp_MSdelete_tracer_history

if object_id('dbo.sp_MSislogreaderjobnamegenerated', 'local') is not null
    drop procedure dbo.sp_MSislogreaderjobnamegenerated

if object_id('dbo.sp_MSisqueuereaderjobnamegenerated', 'local') is not null
    drop procedure dbo.sp_MSisqueuereaderjobnamegenerated

if object_id('dbo.sp_MSissnapshotjobnamegenerated', 'local') is not null
    drop procedure dbo.sp_MSissnapshotjobnamegenerated

if object_id('dbo.sp_MSisdistributionjobnamegenerated', 'local') is not null
    drop procedure dbo.sp_MSisdistributionjobnamegenerated

if object_id('dbo.sp_MSismergejobnamegenerated', 'local') is not null
    drop procedure dbo.sp_MSismergejobnamegenerated

if object_id(N'dbo.sp_MSget_undelivered_commands', 'local') is not null
    drop procedure dbo.sp_MSget_undelivered_commands

if object_id(N'dbo.sp_MSget_anonymous_cmds', 'local') is not null
    drop procedure dbo.sp_MSget_anonymous_cmds

if object_id(N'dbo.sp_MSget_loopback_cmds', 'local') is not null
    drop procedure dbo.sp_MSget_loopback_cmds

if object_id(N'dbo.sp_browsereplcmds', 'local') is not null
    drop procedure dbo.sp_browsereplcmds

if object_id(N'dbo.sp_dumpparamcmd', 'local') is not null
    drop procedure dbo.sp_dumpparamcmd

if object_id(N'dbo.sp_MSadd_repl_commands27hp_mcit', 'local') is not null
    drop procedure dbo.sp_MSadd_repl_commands27hp_mcit

if object_id(N'dbo.sp_MSadd_repl_commands27hp6x', 'local') is not null
    drop procedure dbo.sp_MSadd_repl_commands27hp6x
go

/****************************************************************************/
PRINT ''
PRINT 'Dropping all distribution stored procedures and functions that are created locally'
PRINT ''
/****************************************************************************/

if object_id(N'dbo.sp_MSadd_replcmds', 'local') is not null
	drop procedure dbo.sp_MSadd_replcmds

if object_id(N'dbo.sp_MSadd_repl_commands27', 'local') is not null
	drop procedure dbo.sp_MSadd_repl_commands27
      
if object_id(N'dbo.sp_MSremove_published_jobs', 'local') is not null
	drop procedure dbo.sp_MSremove_published_jobs
      
if object_id(N'dbo.sp_MSdistribution_cleanup', 'local') is not null
	drop procedure dbo.sp_MSdistribution_cleanup

if object_id(N'dbo.sp_MSsubscription_cleanup', 'local') is not null
	drop procedure dbo.sp_MSsubscription_cleanup

if object_id(N'dbo.sp_MSdistribution_delete', 'local') is not null
	drop procedure dbo.sp_MSdistribution_delete

if object_id(N'dbo.sp_MSmaximum_cleanup_seqno', 'local') is not null
	drop procedure dbo.sp_MSmaximum_cleanup_seqno

if object_id(N'dbo.sp_MSdelete_dodelete', 'local') is not null
	drop procedure dbo.sp_MSdelete_dodelete

if object_id(N'dbo.sp_MSdelete_publisherdb_trans', 'local') is not null
	drop procedure dbo.sp_MSdelete_publisherdb_trans

if object_id(N'dbo.sp_MShistory_cleanup', 'local') is not null
	drop procedure dbo.sp_MShistory_cleanup

if object_id(N'dbo.sp_MSget_repl_version', 'local') is not null
	drop procedure dbo.sp_MSget_repl_version

if object_id(N'dbo.sp_MSset_syncstate', 'local') is not null
	drop procedure dbo.sp_MSset_syncstate

if object_id(N'dbo.fn_MSmask_agent_type', 'local') is not null
	drop function dbo.fn_MSmask_agent_type

if object_id(N'dbo.sp_MSlog_agent_cancel', 'local') is not null
	drop procedure dbo.sp_MSlog_agent_cancel

go

--
-- Name: fn_MSmask_agent_type
--
-- Descriptions: 
-- This function is used internally by other stored procedures to mark the agent type.
-- Only distribution agents and merge agents should use this function.
-- BUGBUG: Is this obsolete ?
--
-- Parameters: as defined in create statement
--
-- Returns: int
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'fn_MSmask_agent_type')
go
create function dbo.fn_MSmask_agent_type(
    @agent_id int,
	@agent_type int
    ) returns int
as
begin
	declare @anonymous_mask int
	select @anonymous_mask = 0x80000000
	if @agent_type = 3 -- If dist agent
	begin
		if exists (select * from MSdistribution_agents where id = @agent_id and 
			subscriber_name is not null)
			select @agent_type = 3 | @anonymous_mask
		else
			select @agent_type = 3 
	end
	else if @agent_type = 4 -- if merge agent
	begin
		if exists (select * from dbo.MSmerge_agents where id = @agent_id and 
			anonymous_subid is not null)
			select @agent_type = 4 | @anonymous_mask
		else
			select @agent_type = 4 
	end
	-- if other agents, @agent_type will not change.
	return @agent_type
end
go

--
-- Name: sp_MSset_syncstate
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSset_syncstate')
GO
create procedure sp_MSset_syncstate
@publisher_id smallint, 
@publisher_db sysname, 
@article_id int, 
@sync_state int,  
@xact_seqno varbinary(16)
as
set nocount on 
declare @publication_id int

select top 1 @publication_id = s.publication_id 
from MSsubscriptions s
where 
s.publisher_id = @publisher_id and
s.publisher_db = @publisher_db and
s.article_id = @article_id     and
s.subscription_seqno < @xact_seqno


if @publication_id is not null
begin
	if( @sync_state = 1 )
	begin
		if not exists( select * from MSsync_states 
		               where publisher_id = @publisher_id and
					   publisher_db = @publisher_db and
					   publication_id = @publication_id )
		begin
			insert into MSsync_states( publisher_id, publisher_db, publication_id )
			values( @publisher_id, @publisher_db, @publication_id )
		end
	end
	else if @sync_state = 0 
	begin
		
		delete MSsync_states 
		where 
		publisher_id = @publisher_id and
		publisher_db = @publisher_db and
		publication_id = @publication_id 

		-- activate the subscription(s) so the distribution agent can start processing
		declare @automatic int
		declare @active int	
		declare @initiated int

		select @automatic = 1
		select @active = 2
		select @initiated = 3

		-- set status to active, ss_cplt_seqno = commit LSN of xact containing
		-- syncdone token.  
		--
		-- VERY IMPORTANT:  We can only do this because we know that the publisher
		-- tables are locked in the same transaction that writes the SYNCDONE token.
		-- If the tables were NOT locked, we could get into a situation where data
		-- in the table was changed and committed between the time the SYNCDONE token was
		-- written and the time the SYNCDONE xact was committed.  This would cause the
		-- logreader to replicate the xact with no compensation records, but the advance
		-- of the ss_cplt_seqno would cause the dist to skip that command since only commands
		-- with the snapshot bit set will be processed if they are <= ss_cplt_seqno.
		--
		update MSsubscriptions 
		set status = @active,
			subscription_time = getdate(),
			ss_cplt_seqno = @xact_seqno		
		where
			publisher_id = @publisher_id and
			publisher_db = @publisher_db and
			publication_id = @publication_id and
			sync_type = @automatic and
			status in( @initiated ) and
			ss_cplt_seqno <= @xact_seqno	
	end
end
go

--
-- Name: sp_MSadd_repl_commands27
--
-- Descriptions: this procedure is used by replication agent
-- to directly insert commands in distribution queue.
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSadd_repl_commands27')
GO
CREATE PROCEDURE sp_MSadd_repl_commands27
(
@publisher_id smallint,
@publisher_db sysname,
@xact_id varbinary(16) = 0x0,
@xact_seqno varbinary(16) = 0x0,
@originator sysname,
@originator_db sysname,
@article_id int,
@command_id int,
@type int = 0,
@partial_command bit,
@command varbinary(1024),

@1xact_id varbinary(16) = 0x0,

@1xact_seqno varbinary(16) = 0x0,
@1originator sysname = NULL,
@1originator_db sysname = NULL,
@1article_id int = 0,
@1command_id int = 0,
@1type int = 0,
@1partial_command bit = 0,
@1command varbinary(1024) = NULL,

@2xact_id varbinary(16) = 0x0,

@2xact_seqno varbinary(16) = 0x0,
@2originator sysname = NULL,
@2originator_db sysname = NULL,
@2article_id int = 0,
@2command_id int = 0,
@2type int = 0,
@2partial_command bit = 0,
@2command varbinary(1024) = NULL,

@3xact_id varbinary(16) = 0x0,

@3xact_seqno varbinary(16) = 0x0,
@3originator sysname = NULL,
@3originator_db sysname = NULL,
@3article_id int = 0,
@3command_id int = 0,
@3type int = 0,
@3partial_command bit = 0,
@3command varbinary(1024) = NULL,

@4xact_id varbinary(16) = 0x0,

@4xact_seqno varbinary(16) = 0x0,
@4originator sysname = NULL,
@4originator_db sysname = NULL,
@4article_id int = 0,
@4command_id int = 0,
@4type int = 0,
@4partial_command bit = 0,
@4command varbinary(1024) = NULL,

@5xact_id varbinary(16) = 0x0,

@5xact_seqno varbinary(16) = 0x0,
@5originator sysname = NULL,
@5originator_db sysname = NULL,
@5article_id int = 0,
@5command_id int = 0,
@5type int = 0,
@5partial_command bit = 0,
@5command varbinary(1024) = NULL,

@6xact_id varbinary(16) = 0x0,

@6xact_seqno varbinary(16) = 0x0,
@6originator sysname = NULL,
@6originator_db sysname = NULL,
@6article_id int = 0,
@6command_id int = 0,
@6type int = 0,
@6partial_command bit = 0,
@6command varbinary(1024) = NULL,

@7xact_id varbinary(16) = 0x0,

@7xact_seqno varbinary(16) = 0x0,
@7originator sysname = NULL,
@7originator_db sysname = NULL,
@7article_id int = 0,
@7command_id int = 0,
@7type int = 0,
@7partial_command bit = 0,
@7command varbinary(1024) = NULL,

@8xact_id varbinary(16) = 0x0,

@8xact_seqno varbinary(16) = 0x0,
@8originator sysname = NULL,
@8originator_db sysname = NULL,
@8article_id int = 0,
@8command_id int = 0,
@8type int = 0,
@8partial_command bit = 0,
@8command varbinary(1024) = NULL,

@9xact_id varbinary(16) = 0x0,

@9xact_seqno varbinary(16) = 0x0,
@9originator sysname = NULL,
@9originator_db sysname = NULL,
@9article_id int = 0,
@9command_id int = 0,
@9type int = 0,
@9partial_command bit = 0,
@9command varbinary(1024) = NULL,

@10xact_id varbinary(16) = 0x0,

@10xact_seqno varbinary(16) = 0x0,
@10originator sysname = NULL,
@10originator_db sysname = NULL,
@10article_id int = 0,
@10command_id int = 0,
@10type int = 0,
@10partial_command bit = 0,
@10command varbinary(1024) = NULL,

@11xact_id varbinary(16) = 0x0,

@11xact_seqno varbinary(16) = 0x0,
@11originator sysname = NULL,
@11originator_db sysname = NULL,
@11article_id int = 0,
@11command_id int = 0,
@11type int = 0,
@11partial_command bit = 0,
@11command varbinary(1024) = NULL,

@12xact_id varbinary(16) = 0x0,

@12xact_seqno varbinary(16) = 0x0,
@12originator sysname = NULL,
@12originator_db sysname = NULL,
@12article_id int = 0,
@12command_id int = 0,
@12type int = 0,
@12partial_command bit = 0,
@12command varbinary(1024) = NULL,

@13xact_id varbinary(16) = 0x0,

@13xact_seqno varbinary(16) = 0x0,
@13originator sysname = NULL,
@13originator_db sysname = NULL,
@13article_id int = 0,
@13command_id int = 0,
@13type int = 0,
@13partial_command bit = 0,
@13command varbinary(1024) = NULL,

@14xact_id varbinary(16) = 0x0,

@14xact_seqno varbinary(16) = 0x0,
@14originator sysname = NULL,
@14originator_db sysname = NULL,
@14article_id int = 0,
@14command_id int = 0,
@14type int = 0,
@14partial_command bit = 0,
@14command varbinary(1024) = NULL,

@15xact_id varbinary(16) = 0x0,

@15xact_seqno varbinary(16) = 0x0,
@15originator sysname = NULL,
@15originator_db sysname = NULL,
@15article_id int = 0,
@15command_id int = 0,
@15type int = 0,
@15partial_command bit = 0,
@15command varbinary(1024) = NULL,

@16xact_id varbinary(16) = 0x0,

@16xact_seqno varbinary(16) = 0x0,
@16originator sysname = NULL,
@16originator_db sysname = NULL,
@16article_id int = 0,
@16command_id int = 0,
@16type int = 0,
@16partial_command bit = 0,
@16command varbinary(1024) = NULL,

@17xact_id varbinary(16) = 0x0,

@17xact_seqno varbinary(16) = 0x0,
@17originator sysname = NULL,
@17originator_db sysname = NULL,
@17article_id int = 0,
@17command_id int = 0,
@17type int = 0,
@17partial_command bit = 0,
@17command varbinary(1024) = NULL,

@18xact_id varbinary(16) = 0x0,

@18xact_seqno varbinary(16) = 0x0,
@18originator sysname = NULL,
@18originator_db sysname = NULL,
@18article_id int = 0,
@18command_id int = 0,
@18type int = 0,
@18partial_command bit = 0,
@18command varbinary(1024) = NULL,

@19xact_id varbinary(16) = 0x0,

@19xact_seqno varbinary(16) = 0x0,
@19originator sysname = NULL,
@19originator_db sysname = NULL,
@19article_id int = 0,
@19command_id int = 0,
@19type int = 0,
@19partial_command bit = 0,
@19command varbinary(1024) = NULL,

@20xact_id varbinary(16) = 0x0,

@20xact_seqno varbinary(16) = 0x0,
@20originator sysname = NULL,
@20originator_db sysname = NULL,
@20article_id int = 0,
@20command_id int = 0,
@20type int = 0,
@20partial_command bit = 0,
@20command varbinary(1024) = NULL,

@21xact_id varbinary(16) = 0x0,

@21xact_seqno varbinary(16) = 0x0,
@21originator sysname = NULL,
@21originator_db sysname = NULL,
@21article_id int = 0,
@21command_id int = 0,
@21type int = 0,
@21partial_command bit = 0,
@21command varbinary(1024) = NULL,

@22xact_id varbinary(16) = 0x0,

@22xact_seqno varbinary(16) = 0x0,
@22originator sysname = NULL,
@22originator_db sysname = NULL,
@22article_id int = 0,
@22command_id int = 0,
@22type int = 0,
@22partial_command bit = 0,
@22command varbinary(1024) = NULL,

@23xact_id varbinary(16) = 0x0,

@23xact_seqno varbinary(16) = 0x0,
@23originator sysname = NULL,
@23originator_db sysname = NULL,
@23article_id int = 0,
@23command_id int = 0,
@23type int = 0,
@23partial_command bit = 0,
@23command varbinary(1024) = NULL,

@24xact_id varbinary(16) = 0x0,

@24xact_seqno varbinary(16) = 0x0,
@24originator sysname = NULL,
@24originator_db sysname = NULL,
@24article_id int = 0,
@24command_id int = 0,
@24type int = 0,
@24partial_command bit = 0,
@24command varbinary(1024) = NULL,

@25xact_id varbinary(16) = 0x0,

@25xact_seqno varbinary(16) = 0x0,
@25originator sysname = NULL,
@25originator_db sysname = NULL,
@25article_id int = 0,
@25command_id int = 0,
@25type int = 0,
@25partial_command bit = 0,
@25command varbinary(1024) = NULL,

@26xact_id varbinary(16) = 0x0,

@26xact_seqno varbinary(16) = 0x0,
@26originator sysname = NULL,
@26originator_db sysname = NULL,
@26article_id int = 0,
@26command_id int = 0,
@26type int = 0,
@26partial_command bit = 0,
@26command varbinary(1024) = NULL
)
AS
begin
    SET NOCOUNT ON

    DECLARE @publisher_database_id int
    DECLARE @date datetime
    declare @originator_id int
	declare @syncstat int

    SELECT @date = GETDATE()

    -- Get publisher database id.
    SELECT @publisher_database_id = id from MSpublisher_databases where publisher_id = @publisher_id and 
        publisher_db = @publisher_db
    
    -- First insert into MS_repl_transactions
    IF @command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @xact_id,  @xact_seqno, @date)

    IF @1xact_id = 0x0
      goto INSERT_CMDS
    IF @1command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @1xact_id,  @1xact_seqno, @date)

    IF @2xact_id = 0x0
      goto INSERT_CMDS
    IF @2command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @2xact_id,  @2xact_seqno, @date)
    
    IF @3xact_id = 0x0
      goto INSERT_CMDS
    IF @3command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @3xact_id,  @3xact_seqno, @date)

    IF @4xact_id = 0x0
      goto INSERT_CMDS
    IF @4command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
        @4xact_id,  @4xact_seqno, @date)

    IF @5xact_id = 0x0
      goto INSERT_CMDS

    IF @5command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @5xact_id,  @5xact_seqno, @date)

    IF @6xact_id = 0x0
      goto INSERT_CMDS
    IF @6command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @6xact_id,  @6xact_seqno, @date)

    IF @7xact_id = 0x0
      goto INSERT_CMDS
    IF @7command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @7xact_id,  @7xact_seqno, @date)

    IF @8xact_id = 0x0
      goto INSERT_CMDS
    IF @8command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @8xact_id,  @8xact_seqno, @date)

    IF @9xact_id = 0x0
      goto INSERT_CMDS
    IF @9command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @9xact_id,  @9xact_seqno, @date)

    IF @10xact_id = 0x0
      goto INSERT_CMDS
    IF @10command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @10xact_id,  @10xact_seqno, @date)

    IF @11xact_id = 0x0
      goto INSERT_CMDS
    IF @11command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @11xact_id,  @11xact_seqno, @date)

    IF @12xact_id = 0x0
      goto INSERT_CMDS
    IF @12command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @12xact_id,  @12xact_seqno, @date)

    IF @13xact_id = 0x0
      goto INSERT_CMDS
    IF @13command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @13xact_id,  @13xact_seqno, @date)

    IF @14xact_id = 0x0
      goto INSERT_CMDS
    IF @14command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @14xact_id,  @14xact_seqno, @date)

    IF @15xact_id = 0x0
      goto INSERT_CMDS
    IF @15command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @15xact_id,  @15xact_seqno, @date)

    IF @16xact_id = 0x0
      goto INSERT_CMDS
    IF @16command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @16xact_id,  @16xact_seqno, @date)

    IF @17xact_id = 0x0
      goto INSERT_CMDS
    IF @17command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @17xact_id,  @17xact_seqno, @date)

    IF @18xact_id = 0x0
      goto INSERT_CMDS
    IF @18command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @18xact_id,  @18xact_seqno, @date)

    IF @19xact_id = 0x0
      goto INSERT_CMDS
    IF @19command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @19xact_id,  @19xact_seqno, @date)

    IF @20xact_id = 0x0
      goto INSERT_CMDS
    IF @20command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @20xact_id,  @20xact_seqno, @date)

    IF @21xact_id = 0x0
      goto INSERT_CMDS
    IF @21command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @21xact_id,  @21xact_seqno, @date)

    IF @22xact_id = 0x0
      goto INSERT_CMDS
    IF @22command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @22xact_id,  @22xact_seqno, @date)

    IF @23xact_id = 0x0
      goto INSERT_CMDS
    IF @23command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @23xact_id,  @23xact_seqno, @date)

    IF @24xact_id = 0x0
      goto INSERT_CMDS
    IF @24command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @24xact_id,  @24xact_seqno, @date)

    IF @25xact_id = 0x0
      goto INSERT_CMDS
    IF @25command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @25xact_id,  @25xact_seqno, @date)

    IF @26xact_id = 0x0
      goto INSERT_CMDS
    IF @26command_id = 1
      INSERT INTO MSrepl_transactions VALUES (@publisher_database_id,
         @26xact_id,  @26xact_seqno, @date)

INSERT_CMDS:

    -- Get the originator_id for the first command 
    if @originator <> N'' and @originator_db <> N'' and @originator is not null and @originator_db is not null 
    begin 
        set @originator_id = null select @originator_id = id from MSrepl_originators where
            publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@originator) and
            dbname = @originator_db
        if @originator_id is null
        begin
            insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                (@publisher_database_id, @originator, @originator_db)
            select @originator_id = @@identity
        end
    end
    else
        select @originator_id = 0

    -- Now insert into MSrepl_commands
    IF @command IS NOT NULL
	begin
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @article_id, @syncstat, @xact_seqno
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @xact_seqno,@type, @article_id, 
            @originator_id, 
            @command_id, @partial_command, @command)
	end

    IF @1xact_id = 0x0
      return

    IF @1command IS NOT NULL
    begin
            if @1originator <> N'' and @1originator_db <> N'' and @1originator is not null and @1originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@1originator) and
                    dbname = @1originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @1originator, @1originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @1type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @1article_id, @syncstat, @1xact_seqno
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @1xact_seqno,@1type, @1article_id, 
            @originator_id, 
            @1command_id, @1partial_command, @1command)
    end

    IF @2xact_id = 0x0
      return
    IF @2command IS NOT NULL
    begin
            if @2originator <> N'' and @2originator_db <> N'' and @2originator is not null and @2originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@2originator) and
                    dbname = @2originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @2originator, @2originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @2type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @2article_id, @syncstat, @2xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @2xact_seqno,@2type, @2article_id, 
            @originator_id, 
            @2command_id, @2partial_command, @2command)
    end

    IF @3xact_id = 0x0
      return
    IF @3command IS NOT NULL
    begin
            if @3originator <> N'' and @3originator_db <> N'' and @3originator is not null and @3originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@3originator) and
                    dbname = @3originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @3originator, @3originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0

		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @3type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @3article_id, @syncstat, @3xact_seqno 
		end
    
        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @3xact_seqno,@3type, @3article_id, 
            @originator_id, 
            @3command_id, @3partial_command, @3command)
    end

    IF @4xact_id = 0x0
      return
    IF @4command IS NOT NULL
    begin
            if @4originator <> N'' and @4originator_db <> N'' and @4originator is not null and @4originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@4originator) and
                    dbname = @4originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @4originator, @4originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0

		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @4type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @4article_id, @syncstat, @4xact_seqno 
		end
    
        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @4xact_seqno,@4type, @4article_id, 
            @originator_id, 
            @4command_id, @4partial_command, @4command)
    end

    IF @5xact_id = 0x0
      return
    IF @5command IS NOT NULL
    begin
            if @5originator <> N'' and @5originator_db <> N'' and @5originator is not null and @5originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@5originator) and
                    dbname = @5originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @5originator, @5originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @5type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @5article_id, @syncstat, @5xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @5xact_seqno,@5type, @5article_id, 
            @originator_id, 
            @5command_id, @5partial_command, @5command)
    end

    IF @6xact_id = 0x0
      return
    IF @6command IS NOT NULL
    begin
            if @6originator <> N'' and @6originator_db <> N'' and @6originator is not null and @6originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@6originator) and
                    dbname = @6originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @6originator, @6originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0

		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @6type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @6article_id, @syncstat, @6xact_seqno 
		end
    
        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @6xact_seqno,@6type, @6article_id, 
            @originator_id, 
            @6command_id, @6partial_command, @6command)
    end

    IF @7xact_id = 0x0
      return
    IF @7command IS NOT NULL
    begin
            if @7originator <> N'' and @7originator_db <> N'' and @7originator is not null and @7originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@7originator) and
                    dbname = @7originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @7originator, @7originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @7type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @7article_id, @syncstat, @7xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @7xact_seqno,@7type, @7article_id, 
            @originator_id, 
            @7command_id, @7partial_command, @7command)
    end

    IF @8xact_id = 0x0
      return
    IF @8command IS NOT NULL
    begin
            if @8originator <> N'' and @8originator_db <> N'' and @8originator is not null and @8originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@8originator) and
                    dbname = @8originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @8originator, @8originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @8type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @8article_id, @syncstat, @8xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @8xact_seqno,@8type, @8article_id, 
            @originator_id, 
            @8command_id, @8partial_command, @8command)
    end

    IF @9xact_id = 0x0
      return
    IF @9command IS NOT NULL
    begin
            if @9originator <> N'' and @9originator_db <> N'' and @9originator is not null and @9originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@9originator) and
                    dbname = @9originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @9originator, @9originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @9type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @9article_id, @syncstat, @9xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @9xact_seqno,@9type, @9article_id, 
            @originator_id, 
            @9command_id, @9partial_command, @9command)
    end

    IF @10xact_id = 0x0
      return
    IF @10command IS NOT NULL
    begin
            if @10originator <> N'' and @10originator_db <> N'' and @10originator is not null and @10originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@10originator) and
                    dbname = @10originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @10originator, @10originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @10type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @10article_id, @syncstat, @10xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @10xact_seqno,@10type, @10article_id, 
            @originator_id, 
            @10command_id, @10partial_command, @10command)
    end

    IF @11xact_id = 0x0
      return
    IF @11command IS NOT NULL
    begin
            if @11originator <> N'' and @11originator_db <> N'' and @11originator is not null and @11originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@11originator) and
                    dbname = @11originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @11originator, @11originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @11type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @11article_id, @syncstat, @11xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @11xact_seqno,@11type, @11article_id, 
            @originator_id, 
            @11command_id, @11partial_command, @11command)
    end

    IF @12xact_id = 0x0
      return
    IF @12command IS NOT NULL
    begin
            if @12originator <> N'' and @12originator_db <> N'' and @12originator is not null and @12originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@12originator) and
                    dbname = @12originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @12originator, @12originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @12type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @12article_id, @syncstat, @12xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
		VALUES (@publisher_database_id, 
            @12xact_seqno,@12type, @12article_id, 
            @originator_id, 
            @12command_id, @12partial_command, @12command)
    end


    IF @13xact_id = 0x0
      return
    IF @13command IS NOT NULL
    begin
            if @13originator <> N'' and @13originator_db <> N'' and @13originator is not null and @13originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@13originator) and
                    dbname = @13originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @13originator, @13originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @13type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @13article_id, @syncstat, @13xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @13xact_seqno,@13type, @13article_id, 
            @originator_id, 
            @13command_id, @13partial_command, @13command)
    end

    IF @14xact_id = 0x0
      return
    IF @14command IS NOT NULL
    begin
            if @14originator <> N'' and @14originator_db <> N'' and @14originator is not null and @14originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@14originator) and
                    dbname = @14originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @14originator, @14originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @14type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @14article_id, @syncstat, @14xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @14xact_seqno,@14type, @14article_id, 
            @originator_id, 
            @14command_id, @14partial_command, @14command)
    end


    IF @15xact_id = 0x0
      return
    IF @15command IS NOT NULL
    begin
            if @15originator <> N'' and @15originator_db <> N'' and @15originator is not null and @15originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@15originator) and
                    dbname = @15originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @15originator, @15originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @15type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @15article_id, @syncstat, @15xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @15xact_seqno,@15type, @15article_id, 
            @originator_id, 
            @15command_id, @15partial_command, @15command)
    end

    IF @16xact_id = 0x0
      return
    IF @16command IS NOT NULL
    begin
            if @16originator <> N'' and @16originator_db <> N'' and @16originator is not null and @16originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@16originator) and
                    dbname = @16originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @16originator, @16originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @16type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @16article_id, @syncstat, @16xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @16xact_seqno,@16type, @16article_id, 
            @originator_id, 
            @16command_id, @16partial_command, @16command)
    end


    IF @17xact_id = 0x0
      return
    IF @17command IS NOT NULL
    begin
            if @17originator <> N'' and @17originator_db <> N'' and @17originator is not null and @17originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@17originator) and
                    dbname = @17originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @17originator, @17originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @17type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @17article_id, @syncstat, @17xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @17xact_seqno,@17type, @17article_id, 
            @originator_id, 
            @17command_id, @17partial_command, @17command)
    end


    IF @18xact_id = 0x0
      return
    IF @18command IS NOT NULL
    begin
            if @18originator <> N'' and @18originator_db <> N'' and @18originator is not null and @18originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@18originator) and
                    dbname = @18originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @18originator, @18originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @18type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @18article_id, @syncstat, @18xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @18xact_seqno,@18type, @18article_id, 
            @originator_id, 
            @18command_id, @18partial_command, @18command)
    end


    IF @19xact_id = 0x0
      return
    IF @19command IS NOT NULL
    begin
            if @19originator <> N'' and @19originator_db <> N'' and @19originator is not null and @19originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@19originator) and
                    dbname = @19originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @19originator, @19originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @19type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @19article_id, @syncstat, @19xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @19xact_seqno,@19type, @19article_id, 
            @originator_id, 
            @19command_id, @19partial_command, @19command)
    end


    IF @20xact_id = 0x0
      return
    IF @20command IS NOT NULL
    begin
            if @20originator <> N'' and @20originator_db <> N'' and @20originator is not null and @20originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@20originator) and
                    dbname = @20originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @20originator, @20originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @20type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @20article_id, @syncstat, @20xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @20xact_seqno,@20type, @20article_id, 
            @originator_id, 
            @20command_id, @20partial_command, @20command)
    end

    IF @21xact_id = 0x0
      return
    IF @21command IS NOT NULL
    begin
            if @21originator <> N'' and @21originator_db <> N'' and @21originator is not null and @21originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@21originator) and
                    dbname = @21originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @21originator, @21originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @21type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @21article_id, @syncstat, @21xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @21xact_seqno,@21type, @21article_id, 
            @originator_id, 
            @21command_id, @21partial_command, @21command)
    end

    IF @22xact_id = 0x0
      return
    IF @22command IS NOT NULL
    begin
            if @22originator <> N'' and @22originator_db <> N'' and @22originator is not null and @22originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@22originator) and
                    dbname = @22originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @22originator, @22originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
        end
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @22type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @22article_id, @syncstat, @22xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @22xact_seqno,@22type, @22article_id, 
            @originator_id, 
            @22command_id, @22partial_command, @22command)


    IF @23xact_id = 0x0
      return
    IF @23command IS NOT NULL
    begin
            if @23originator <> N'' and @23originator_db <> N'' and @23originator is not null and @23originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@23originator) and
                    dbname = @23originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @23originator, @23originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @23type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @23article_id, @syncstat, @23xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @23xact_seqno,@23type, @23article_id, 
            @originator_id, 
            @23command_id, @23partial_command, @23command)
    end

    IF @24xact_id = 0x0
      return
    IF @24command IS NOT NULL
    begin
            if @24originator <> N'' and @24originator_db <> N'' and @24originator is not null and @24originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@24originator) and
                    dbname = @24originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @24originator, @24originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @24type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @24article_id, @syncstat, @24xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @24xact_seqno,@24type, @24article_id, 
            @originator_id, 
            @24command_id, @24partial_command, @24command)
    end


    IF @25xact_id = 0x0
      return
    IF @25command IS NOT NULL
    begin
            if @25originator <> N'' and @25originator_db <> N'' and @25originator is not null and @25originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@25originator) and
                    dbname = @25originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @25originator, @25originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @25type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @25article_id, @syncstat, @25xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @25xact_seqno,@25type, @25article_id, 
            @originator_id, 
            @25command_id, @25partial_command, @25command)
    end


    IF @26xact_id = 0x0
      return
    IF @26command IS NOT NULL
    begin
            if @26originator <> N'' and @26originator_db <> N'' and @26originator is not null and @26originator_db is not null 
            begin 
                set @originator_id = null select @originator_id = id from MSrepl_originators where
                    publisher_database_id = @publisher_database_id and UPPER(srvname) = UPPER(@26originator) and
                    dbname = @26originator_db
                if @originator_id is null
                begin
                    insert into MSrepl_originators (publisher_database_id, srvname, dbname) values
                        (@publisher_database_id, @26originator, @26originator_db)
                    select @originator_id = @@identity
                end
            end
            else
                select @originator_id = 0
    
		if( @type in( 37,38 ) )
		begin
		  select @syncstat = 38 - @26type
		  exec sp_MSset_syncstate @publisher_id, @publisher_db, @26article_id, @syncstat, @26xact_seqno 
		end

        INSERT INTO MSrepl_commands (publisher_database_id, xact_seqno, type, article_id, originator_id, command_id, partial_command, command)
VALUES (@publisher_database_id, 
            @26xact_seqno,@26type, @26article_id, 
            @originator_id, 
            @26command_id, @26partial_command, @26command)
    end


    IF @@ERROR <> 0
      return (1)
end
GO

--
-- Name: sp_MSadd_replcmds
--
-- Descriptions: this procedure is used by logreader agent
-- to insert commands in distribution queue.
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSadd_replcmds')
go
CREATE PROCEDURE sp_MSadd_replcmds
@publisher_database_id int,
@publisher_id smallint,
@publisher_db sysname,
@data varbinary(1595),
@1data varbinary(1595) = NULL,
@2data varbinary(1595) = NULL,
@3data varbinary(1595) = NULL,
@4data varbinary(1595) = NULL,
@5data varbinary(1595) = NULL,
@6data varbinary(1595) = NULL,
@7data varbinary(1595) = NULL,
@8data varbinary(1595) = NULL,
@9data varbinary(1595) = NULL,
@10data varbinary(1595) = NULL,
@11data varbinary(1595) = NULL,
@12data varbinary(1595) = NULL,
@13data varbinary(1595) = NULL,
@14data varbinary(1595) = NULL,
@15data varbinary(1595) = NULL,
@16data varbinary(1595) = NULL,
@17data varbinary(1595) = NULL,
@18data varbinary(1595) = NULL,
@19data varbinary(1595) = NULL,
@20data varbinary(1595) = NULL,
@21data varbinary(1595) = NULL,
@22data varbinary(1595) = NULL,
@23data varbinary(1595) = NULL,
@24data varbinary(1595) = NULL,
@25data varbinary(1595) = NULL,
@26data varbinary(1595) = NULL
AS
BEGIN
    SET NOCOUNT ON
    DECLARE @date datetime
			,@x int
			,@tempdata varbinary(1595)
			
	DECLARE @xactId			varbinary(10),
			@xactSeqNo		varbinary(10),
			@artId			int,
			@cmdId			int,
			@cmdType		int,
			@fIncomplete	bit,
			@cmdLen			int,
			@originator_id	int,
			@origSrvLen		int,
			@origDbLen		int,
			@origPublId		int,
			@origDbVersion	int,
			@origLSN		varbinary(10),
			@hashKey		int,
			@cmdText		varbinary(1595),
			@originator		sysname,
			@originatorDb	sysname
			
    SELECT @date = GETDATE()

	select @x = 0
	select @tempdata = null
	while @x <= 26
	begin
			select @tempdata = CASE @x
				when 0 then @data
				when 1 then @1data
				when 2 then @2data
				when 3 then @3data
				when 4 then @4data
				when 5 then @5data
				when 6 then @6data
				when 7 then @7data
				when 8 then @8data
				when 9 then @9data
				when 10 then @10data
				when 11 then @11data
				when 12 then @12data
				when 13 then @13data
				when 14 then @14data
				when 15 then @15data
				when 16 then @16data
				when 17 then @17data
				when 18 then @18data
				when 19 then @19data
				when 20 then @20data
				when 21 then @21data
				when 22 then @22data
				when 23 then @23data
				when 24 then @24data
				when 25 then @25data
				when 26 then @26data
			end

		if @tempdata is NULL
			goto END_CMDS

		-- We will now breakup the binary data. Check HP_FIXED_DATA 
		-- in publish.cpp for all of the offsets listed below...
		select @xactId 			= substring( @tempdata, 1, 10),
				@xactSeqNo		= substring( @tempdata, 11, 10),
				@artId			= substring( @tempdata, 21, 4),
				@cmdId			= substring( @tempdata, 25, 4),
				@cmdType		= substring( @tempdata, 29, 4),
				@fIncomplete	= convert(bit, substring( @tempdata, 33, 1)),
				@cmdLen			= substring( @tempdata, 34, 2),
				@origSrvLen		= substring( @tempdata, 36, 2),
				@origDbLen		= substring( @tempdata, 38, 2),
				@hashKey		= substring( @tempdata, 40, 2),
				-- @origPublId  = only done below if an originator len is detected : usually = substring( @tempdata, 42, 4)
				-- @origDbVersion=only done below if an originator len is detected : usually = substring( @tempdata, 46, 4)
				@origLSN		= substring( @tempdata, 50, 10),
				@cmdText		= substring( @tempdata, 60, @cmdLen)
				-- @originator  = only done below if an originator len is detected : usually = substring( @tempdata, 60 + @cmdLen, @origSrvLen)
				-- @originatorDb= only done below if an originator len is detected : usually = substring( @tempdata, 60 + @cmdLen + @origSrvLen, @origDbLen)
				
	    IF @cmdId = 1
	    begin
			INSERT INTO MSrepl_transactions 
				VALUES (@publisher_database_id, @xactId, @xactSeqNo, @date)
		end

		-- do special processing for the different command typs if needed
		if( @cmdType in( 37,38 ) )
		begin
			select @cmdType = 38 - @cmdType
			exec sp_MSset_syncstate @publisher_id, @publisher_db, @artId, @cmdType, @xactSeqNo
			select @cmdType = (38 - @cmdType) | 0x80000000
		end
		-- Check all posted cmds of SQLCMD type to see if they are tracer records
		-- sql cmd type is (47 | 0x40000000) or 1073741871
		else if @cmdType = 1073741871
		begin
			declare @tracer_id 	int,
				@retcode	int
			
			select @tracer_id = cast(cast(@cmdText as nvarchar) as int)

			exec @retcode = sys.sp_MSupdate_tracer_history @tracer_id = @tracer_id
			if @retcode <> 0 or @@error <> 0
				return 1
		end
		
		-- only add it if the command is not empty
	   	if @cmdLen > 0
	   	begin
	        -- Get the originator_id for the first command
	        if @origSrvLen <> 0 and @origDbLen <> 0 
	        begin 
	            select @originator_id 	= null,
	           			@originator		= substring( @tempdata, 60 + @cmdLen, @origSrvLen),
						@originatorDb	= substring( @tempdata, 60 + @cmdLen + @origSrvLen, @origDbLen),
						@origPublId 	= substring( @tempdata, 42, 4),
						@origDbVersion	= substring( @tempdata, 46, 4)

				-- if @origPublId and @origDbVersion is 0 or NULL
				-- then we are not in Peer-To-Peer so we do not need
				-- to set the dbversion and publication id values...
				if isnull(@origPublId, 0) != 0
					and isnull(@origDbVersion, 0) != 0
				begin
					select @originator_id = id 
		            	from MSrepl_originators with (readpast)
		            	where publisher_database_id = @publisher_database_id 
			                and UPPER(srvname) = UPPER(@originator)
			                and dbname = @originatorDb
			                and publication_id = @origPublId
			                and dbversion = @origDbVersion
				end
				else
				begin
					select @origPublId = NULL,
							@origDbVersion = NULL
							
					select @originator_id = id 
		            	from MSrepl_originators 
		            	where publisher_database_id = @publisher_database_id 
			                and UPPER(srvname) = UPPER(@originator)
			                and dbname = @originatorDb
			                and publication_id is NULL
			                and dbversion is NULL
				end
				
	            if @originator_id is null
	            begin
	                insert into MSrepl_originators (publisher_database_id, srvname, dbname, publication_id, dbversion) 
	                	values (@publisher_database_id, @originator, @originatorDb, @origPublId, @origDbVersion)
	                	
	                select @originator_id = @@identity
	            end
	        end
	        else
	            select @originator_id = 0
		
			INSERT INTO MSrepl_commands 
			(
				publisher_database_id, 
				xact_seqno, 
				type, 
				article_id, 
				originator_id, 
				command_id, 
				partial_command, 
				hashkey,
				originator_lsn,
				command
			)
			VALUES 
			(
				@publisher_database_id,
				@xactSeqNo,
				@cmdType,
				@artId, 					
				@originator_id,
				@cmdId,
				@fIncomplete,
				@hashKey,
				@origLSN,
				@cmdText
			)
	    end
		
		select @x = @x + 1
	end

END_CMDS:
    IF @@ERROR <> 0
      return (1)
END
go

--
-- Name: sp_MSremove_published_jobs
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSremove_published_jobs')
go
CREATE PROCEDURE sp_MSremove_published_jobs
@server sysname,
@database sysname
AS
    -- 6.5 publisher and 7.0 publisher will call this
    -- publisher_database_id will be drop in sp_MSdrop_publication.
    return(0)
go

--
-- Name: sp_MSsubscription_cleanup
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSsubscription_cleanup')
GO
CREATE PROCEDURE sp_MSsubscription_cleanup
    @cutoff_time datetime
as
begin
    set nocount on
	
	declare @ACTIVE 		tinyint,
    		@INACTIVE 		tinyint,
    		@SUBSCRIBED 	tinyint,
    		@VIRTUAL 		smallint,
			@SNAPSHOT_BIT 	int

    declare @retcode 		int,
			@max_time 		datetime,
			@agent_id 		int,
			@num_dropped 	int

    declare @pub_db_id      int,
            @min_autonosync_lsn varbinary(16),
            @new_autonosync_lsn varbinary(16),
            @low_autonosync_lsn binary(8),
            @high_autonosync_lsn binary(8),
            @publication_id int

	select @ACTIVE 			= 2,
			@INACTIVE 		= 0,
    		@SUBSCRIBED 	= 1,
    		@VIRTUAL 		= -1,
			@SNAPSHOT_BIT 	= 0x80000000

    select @max_time = dateadd(hour, 1, getdate())

    -- Refer to sp_MSmaximun_cleanup_xact_seqno to understand the logic
    -- in this sp. If you change the logic here, you may need to change
    -- that sp as well.

    -- Deactivate real subscriptions for agents that are working on 
    -- transactions that are older than @retention
    -- update all the subscriptions for those agents, including
    -- subscriptions that are in subscribed state!
    update MSsubscriptions  
		set status = @INACTIVE 
			where agent_id in (
							select derivedInfo.agent_id 
								from (
										-- Here we are retrieving the agent id, publisher database id, 
										-- min subscription sequence number, and the transaction seqno 
										-- related to the max timestamp row in the history table. this is
										-- important since the tran seqno can go back to lower values in 
										-- the case of reinit with immediate sync.
										select s.agent_id as agent_id,
											s.publisher_database_id as publisher_database_id,
											min(s.subscription_seqno) as subscription_seqno,
											isnull(h.xact_seqno, 0x0) as xact_seqno
										from MSsubscriptions s
											left join (MSdistribution_history h with (REPEATABLEREAD)
													join (select agent_id, 
																max(timestamp) as timestamp
															from MSdistribution_history with (REPEATABLEREAD)
															group by agent_id) as h2 
														on h.agent_id = h2.agent_id 
															and h.timestamp = h2.timestamp)
												on s.agent_id = h.agent_id
										where s.status = @ACTIVE                       
											and s.subscriber_id >= 0 	-- Only well-known agent
										group by s.agent_id,            -- agent and pubdbid as a pair can never be differnt
											s.publisher_database_id,      
											isnull(h.xact_seqno, 0x0)	-- because of join above we can include this
									) derivedInfo
								where @cutoff_time >= (
													-- get the entry_time of the first transaction that cannot be
													-- cleaned up normally because of this agent.
													-- use history if it exists and is larger
													case when derivedInfo.xact_seqno >= derivedInfo.subscription_seqno
													then
														-- join with commands table to filter out transactions that do not have commands
														isnull((select top 1 entry_time 
																	from MSrepl_transactions t, 
																			MSrepl_commands c, 
																			MSsubscriptions sss
																	where sss.agent_id = derivedInfo.agent_id 
																		and t.publisher_database_id = derivedInfo.publisher_database_id 
																		and c.publisher_database_id = derivedInfo.publisher_database_id 
																		and c.xact_seqno = t.xact_seqno
																		-- filter out snapshot transactions not for this subscription 
																		-- because they do not represent significant data changes
																		and ((c.type & @SNAPSHOT_BIT) <> @SNAPSHOT_BIT 
																				or (c.xact_seqno >= sss.subscription_seqno 
																					and c.xact_seqno <= sss.ss_cplt_seqno)) 
																		-- filter out non-subscription articles for independent agents
																		and c.article_id = sss.article_id 
																		-- history xact_seqno can be cleaned up
																		and t.xact_seqno > isnull( derivedInfo.xact_seqno, 0x0 ) 
																		and c.xact_seqno > isnull( derivedInfo.xact_seqno, 0x0 )
																	order by t.xact_seqno asc), @max_time)
													else
														isnull((select top 1 entry_time 
																	from MSrepl_transactions t, 
																			MSrepl_commands c, 
																			MSsubscriptions sss
																	where sss.agent_id = derivedInfo.agent_id 
																		and t.publisher_database_id = derivedInfo.publisher_database_id 
																		and c.publisher_database_id = derivedInfo.publisher_database_id
																		and c.xact_seqno = t.xact_seqno
																		-- filter out snapshot transactions not for this subscription 
																		-- because they do not represent significant data changes
																		and ((c.type & @SNAPSHOT_BIT ) <> @SNAPSHOT_BIT 
																				or (c.xact_seqno >= sss.subscription_seqno 
																					and c.xact_seqno <= sss.ss_cplt_seqno))
																		-- filter out non-subscription articles for independent agents
																		and c.article_id = sss.article_id
																		-- sub xact_seqno cannot be cleaned up
																		and t.xact_seqno >= derivedInfo.subscription_seqno
																		and c.xact_seqno >= derivedInfo.subscription_seqno
																	order by t.xact_seqno asc), @max_time)
													end))
	if @@rowcount <> 0
		RAISERROR(21011, 10, -1)

	-- Dropping all the aonymous agents that are working on
    -- transactions that are older than @retention
    -- No message raised.
	-- Don't drop agents that do not have history (true for new agents).
    -- For each publisher/publisherdb pair do cleanup
    declare hC CURSOR LOCAL FAST_FORWARD FOR 
		select distinct derivedInfo.agent_id 
			from (
					-- Here we are retrieving the agent id, publisher database id, 
					-- min subscription sequence number, and the transaction seqno 
					-- related to the max timestamp row in the history table. this is
					-- important since the tran seqno can go back to lower values in 
					-- the case of reinit with immediate sync.
					select msda.id as agent_id,
							msda.publisher_database_id as publisher_database_id,
							min(s.subscription_seqno) as subscription_seqno, 
							h.xact_seqno as xact_seqno
						from MSsubscriptions s 
							join MSdistribution_agents msda
								on s.agent_id = msda.virtual_agent_id 
							join (MSdistribution_history h with (REPEATABLEREAD)
									join (select agent_id,
												max(timestamp) as timestamp
											from MSdistribution_history with (REPEATABLEREAD)
											group by agent_id) as h2
										on h.agent_id = h2.agent_id
											and h.timestamp = h2.timestamp)
								on msda.id = h.agent_id
						where s.status = @ACTIVE                			
						group by msda.id, 						-- agent and pubdbid as a pair can never be differnt
							msda.publisher_database_id, 
							h.xact_seqno
				) derivedInfo
       		where @cutoff_time >= (
				                -- Get the entry_time of the first tran that cannot be
				                -- cleaned up normally because of this agent.
				                -- use history if it exists and is larger
				                case  when derivedInfo.xact_seqno > 0x00
				                then
									-- does not have commands will not be picked up by sp_MSget_repl_commands
									isnull((select top 1 entry_time 
												from MSrepl_transactions t, 
														MSrepl_commands c, 
														MSsubscriptions sss
												where sss.agent_id = derivedInfo.agent_id 
													and t.publisher_database_id = derivedInfo.publisher_database_id
													and c.publisher_database_id = derivedInfo.publisher_database_id 
													and c.xact_seqno = t.xact_seqno
													-- filter out snapshot transactions not for this subscription 
													-- because they do not represent significant data changes
													and ((c.type & @SNAPSHOT_BIT) <> @SNAPSHOT_BIT 
															or (c.xact_seqno >= sss.subscription_seqno 
																and c.xact_seqno <= sss.ss_cplt_seqno))
													-- filter out non-subscription articles for independent agents
													and c.article_id = sss.article_id
													-- history xact_seqno can be cleaned up
													and t.xact_seqno > derivedInfo.xact_seqno
													and c.xact_seqno > derivedInfo.xact_seqno
												order by t.xact_seqno asc), @max_time)
				                else
				                    isnull((select top 1 entry_time 
												from MSrepl_transactions t, 
														MSrepl_commands c, 
														MSsubscriptions sss
												where sss.agent_id = derivedInfo.agent_id
													and t.publisher_database_id = derivedInfo.publisher_database_id
													and c.publisher_database_id = derivedInfo.publisher_database_id
													and c.xact_seqno = t.xact_seqno
							                        -- filter out snapshot transactions not for this subscription 
							                        -- because they do not represent significant data changes
													and ((c.type & @SNAPSHOT_BIT ) <> @SNAPSHOT_BIT 
														or (c.xact_seqno >= sss.subscription_seqno 
															and c.xact_seqno <= sss.ss_cplt_seqno)) 
													-- filter out non-subscription articles for independent agents
													and c.article_id = sss.article_id
													-- sub xact_seqno cannot be cleaned up
													and t.xact_seqno >= isnull(derivedInfo.subscription_seqno, 0x0)
													and c.xact_seqno >= isnull(derivedInfo.subscription_seqno, 0x0)
				                        		order by t.xact_seqno asc), @max_time)
				                  end)
	for read only
	select @num_dropped = 0
    open hC
    fetch hC into @agent_id
    while (@@fetch_status <> -1)
    begin
		exec @retcode = sys.sp_MSdrop_distribution_agentid_dbowner_proxy @agent_id
		if @retcode <> 0 or @@error <> 0
			return (1)
			
		select @num_dropped = @num_dropped + 1
	    fetch hC into @agent_id
	end
	if @num_dropped > 0
        RAISERROR(20597, 10, -1, @num_dropped) 

    -- Deactivating virtual subscriptions that are older then @retention.
    update MSsubscriptions  
		set status = @SUBSCRIBED
		-- Only change active subscriptions!
		where status = @ACTIVE 					
			and subscriber_id = @VIRTUAL 
			-- Get the entry_time of the first tran that cannot be
			-- cleaned up normally because of this subscription.
			and @cutoff_time >= isnull((select top 1 entry_time 
										from MSrepl_transactions t 
										where t.publisher_database_id = MSsubscriptions.publisher_database_id 
											and xact_seqno >= MSsubscriptions.subscription_seqno
			                			order by t.xact_seqno asc), @max_time)

    if @@rowcount <> 0
		RAISERROR(21077, 10, -1)
    
    -- Clear the min_noautosync_lsn value in MSpublications, if it specifies a time older than the retention period
    --  This only applies to publications which are allowed for init from backup when there are no subscribers present.

    -- We first find all publications enabled for init from backup with a min_autonosync_lsn specified
    declare #pubC CURSOR FOR
        select msp.publication_id, mspd.id, msp.min_autonosync_lsn from dbo.MSpublications msp 
            join dbo.MSpublisher_databases mspd on msp.publisher_id = mspd.publisher_id
                 and msp.publisher_db = mspd.publisher_db
            where msp.allow_initialize_from_backup <> 0
                 and msp.min_autonosync_lsn is not null
                 and not exists(
                    select publisher_id from MSsubscriptions mss where
                        publisher_database_id = mspd.id) 
    for update of msp.publication_id

    open #pubC
    fetch next from #pubC into @publication_id, @pub_db_id, @min_autonosync_lsn

    while (@@fetch_status <> -1)
    begin
        select @new_autonosync_lsn = null

        -- Find the largest xact_seqno, that's outside of the retention period
        select top 1 @new_autonosync_lsn = xact_seqno from dbo.MSrepl_transactions
            where publisher_database_id = @pub_db_id 
                and xact_seqno >= @min_autonosync_lsn
                and entry_time <= @cutoff_time
            order by xact_seqno desc

        if @new_autonosync_lsn is not null
        begin
            -- We have the largest xact_seqno that's outside of the retention period
            --   however, this lsn is itself outside of the retention period, so we increment
            --   the LSN by 1 in order to make sure it gets cleaned up properly
            select @low_autonosync_lsn = substring(@new_autonosync_lsn, 9, 8)
            select @high_autonosync_lsn = substring(@new_autonosync_lsn, 1, 8)
			
            select @low_autonosync_lsn = cast(@low_autonosync_lsn as bigint) + 1
            -- Check for overflow
            if cast(@low_autonosync_lsn as bigint) = 0
               select @high_autonosync_lsn = cast(@high_autonosync_lsn as bigint) + 1

            -- Concat the two parts of the LSN
            select @new_autonosync_lsn = @high_autonosync_lsn + @low_autonosync_lsn 

            -- update the autonosync_lsn to reflect the earliest command we can keep within the 
            --  retention period
            update dbo.MSpublications
                set min_autonosync_lsn = @new_autonosync_lsn
                where publication_id = @publication_id
        end

        fetch next from #pubC into @publication_id, @pub_db_id, @min_autonosync_lsn
    end

    close #pubC
    deallocate #pubC

	return 0
end
GO
--
-- Name: sp_MSdelete_dodelete
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSdelete_dodelete')
go
-- New delete stored procedure WITH RECOMPILE
-- Note: this function is currently called from sp_MSdelete_publisherdb_trans only
--   and due to the removal of "set rowcount", the TOP(5000) has been added here also,
--   if a change needs to be made, check that proc also
CREATE PROCEDURE sp_MSdelete_dodelete
	@publisher_database_id int,
	@max_xact_seqno varbinary(16),
	@last_xact_seqno varbinary(16),
	@last_log_xact_seqno varbinary(16),
	@has_immediate_sync bit = 1
WITH RECOMPILE
as
begin
		declare @second_largest_log_xact_seqno varbinary(16)
		set @second_largest_log_xact_seqno = 0x0

		if @last_log_xact_seqno is not NULL
		begin
			--get the second largest xact_seqno among log entries
			select @second_largest_log_xact_seqno = max(xact_seqno)
			from MSrepl_transactions
			where publisher_database_id = @publisher_database_id
				and xact_id <> 0x0
				and xact_seqno < @last_log_xact_seqno

			if @second_largest_log_xact_seqno is NULL or substring(@second_largest_log_xact_seqno, 1, 10) <> substring(@last_log_xact_seqno, 1, 10)
			begin
				set @second_largest_log_xact_seqno = 0x0
			end
		end

		
		if @has_immediate_sync = 0
			delete TOP(5000) MSrepl_transactions WITH (PAGLOCK) from MSrepl_transactions with (INDEX(ucMSrepl_transactions)) where
				publisher_database_id = @publisher_database_id and
				xact_seqno <= @max_xact_seqno and
				xact_seqno <> @last_xact_seqno and
				xact_seqno <> @last_log_xact_seqno and
				xact_seqno <> @second_largest_log_xact_seqno --ensure at least two log entries are left, when there existed more than two log entries
				OPTION (MAXDOP 1)
		else
			delete TOP(5000) MSrepl_transactions WITH (PAGLOCK) from MSrepl_transactions with (INDEX(ucMSrepl_transactions)) where
				publisher_database_id = @publisher_database_id and
				xact_seqno <= @max_xact_seqno and
				xact_seqno <> @last_xact_seqno and
				xact_seqno <> @last_log_xact_seqno and  
				xact_seqno <> @second_largest_log_xact_seqno and --ensure at least two log entries are left, when there existed more than two log entries
				-- use nolock to avoid deadlock
				not exists (select * from MSrepl_commands c with (nolock) where
					c.publisher_database_id = @publisher_database_id and
					c.xact_seqno = MSrepl_transactions.xact_seqno and 
                    c.xact_seqno <= @max_xact_seqno)
			OPTION (MAXDOP 1)
end
GO
--
-- Name: sp_MSdelete_publisherdb_trans
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSdelete_publisherdb_trans')
GO
CREATE PROCEDURE sp_MSdelete_publisherdb_trans
    @publisher_database_id int,
    @max_xact_seqno varbinary(16),
	@max_cutoff_time datetime,
    @num_transactions int OUTPUT,
    @num_commands int OUTPUT
    as

	set nocount on
    
	declare @snapshot_bit int
	declare @replpost_bit int
    declare @directory_type int
    declare @alt_directory_type int
    declare @scriptexec_type int
    declare @last_xact_seqno varbinary(16)
    declare @last_log_xact_seqno varbinary(16)
    declare @max_immediate_sync_seqno varbinary(16)
    declare @dir nvarchar(512)
    declare @row_count int
    declare @batchsize int
    declare @retcode int            /* Return value of xp_cmdshell */
	declare @has_immediate_sync bit
	declare @xact_seqno varbinary(16)
	declare @command_id int
	declare @type int
	declare @directory nvarchar(1024)
	declare @syncinit int
	declare @syncdone int

    select @snapshot_bit = 0x80000000
	select @replpost_bit = 0x40000000
    select @directory_type = 7
    select @alt_directory_type = 25
	select @scriptexec_type = 46
	select @syncinit = 37
	select @syncdone = 38
    select @num_transactions = 0
    select @num_commands = 0

       -- Being as this is a cleanup process it is our prefered victim
       SET DEADLOCK_PRIORITY LOW

	-- If transactions for immediate_sync publications will not be cleanup up until
	-- they are older than max retention, except for snapshot transactions.
	-- Snapshot transactions for immediate_sync publication will be cleanup up if it is
	-- not used by any subscriptions (including virtual and virtual immediate_syncymous
	-- subscriptions. Both will be reset by snapshot agent every time if the 
	-- publication is snapshot type.) The special logic for snapshot transactions
	-- is mostly for snapshot publications. It is to cleaup up the snapshot files 
	-- ASAP and not to wait for max retention.
	-- We don't need to do this for non-immediate_syncymous publications since the snapshot
	-- trans for them will be removed as soon as they are distributed and min '
	-- retention is reached.

	-- Detect if there are immediate_syncymous publications in this publishing db.
	if exists (select * from MSsubscriptions where
			publisher_database_id = @publisher_database_id and
			subscriber_id < 0)
		select @has_immediate_sync = 1
	else
		select @has_immediate_sync = 0

	if @has_immediate_sync = 1
	begin
		-- if @max_immediate_sync_seqno is null, no row will be deleted based on that.
		select @max_immediate_sync_seqno = max(xact_seqno) 
			from MSrepl_transactions with (nolock)
			where publisher_database_id = @publisher_database_id 
				and entry_time <= @max_cutoff_time
	end

	-- table to store all of the snapshot command seqno that will 
	-- need to be deleted from MSrepl_commands after dir removal
	declare @snapshot_xact_seqno table (snap_xact_seqno varbinary(16))

    -- Note delete commands first since transaction table will be used for
    -- geting @max_xact_seqno (see sp_MSmaximum_cleanup_seqno).
    -- Delete all directories stored in directory command.
	if @has_immediate_sync = 0
		declare  hCdirs  CURSOR LOCAL FAST_FORWARD FOR select CONVERT(nvarchar(512), command),
			xact_seqno, command_id, type
			from MSrepl_commands with (nolock) where
			publisher_database_id = @publisher_database_id and
			xact_seqno <= @max_xact_seqno and   
			((type & ~@snapshot_bit) = @directory_type or
            (type & ~@snapshot_bit) = @alt_directory_type or
            (type & ~@replpost_bit) = @scriptexec_type)
		for read only
	else
		declare  hCdirs  CURSOR LOCAL FAST_FORWARD FOR select CONVERT(nvarchar(512), command),
			xact_seqno, command_id, type
			from MSrepl_commands c with (nolock) where
			publisher_database_id = @publisher_database_id and
			xact_seqno <= @max_xact_seqno and  
			(
				-- In this section we skip over script exec because they should only be
				-- removed when they are out of retention (no subscriptions will ever
				-- point to the script exec commands so if we didn't exclude them here they
				-- would always be removed... even when they are needed by subscribers).
				(
					(type & ~@snapshot_bit) in (@directory_type, @alt_directory_type)
				 	and (
						-- Select the row if it is older than max retention.
						xact_seqno <= @max_immediate_sync_seqno or 
						-- Select the row if it is not used by any subscriptions.
						not exists (select * from MSsubscriptions s where 
									s.publisher_database_id = @publisher_database_id and 
									s.subscription_seqno = c.xact_seqno) OR
						-- Select the row if it is not for immediate_sync publications
						-- Note: directory command have article id 0 so it is not useful
						not exists (select * from MSpublications p where
								p.publication_id = (select top 1 s.publication_id 
									from MSsubscriptions s where
									s.publisher_database_id = @publisher_database_id and
									s.subscription_seqno = c.xact_seqno) and
								p.immediate_sync = 1)
					)
				)
				-- For script exec only select the row if it is out of retention
				or ((type & ~@replpost_bit) = @scriptexec_type
						and xact_seqno <= @max_immediate_sync_seqno)
			)

		for read only

    open hCdirs
    fetch hCdirs into @dir, @xact_seqno, @command_id, @type
    while (@@fetch_status <> -1)
    begin
    	-- script exec command, need to map to the directory path and remove leading 0 or 1
		if((@type & ~@replpost_bit) = @scriptexec_type)
		begin
			select @dir = left(@dir,len(@dir) - charindex(N'\', reverse(@dir)))
			
			if left(@dir, 1) in (N'0', N'1')
			begin
				select @dir = right(@dir, len(@dir) - 1)
			end
		end
		
		-- Need to map unc to local drive for access problem
        exec @retcode = sys.sp_MSreplremoveuncdir @dir
        /* Abort the operation if the delete fails */
        if (@retcode <> 0 or @@error <> 0)
            return (1)

		-- build up a list of snapshot commands that will be deleted below
		-- this list is built because we must cleanup scripts, alt snap paths
		-- and regular snapshots prior to removing the commands for them...
		insert into @snapshot_xact_seqno(snap_xact_seqno) values (@xact_seqno)

	    fetch hCdirs into @dir, @xact_seqno, @command_id, @type
    end
    close hCdirs
    deallocate hCdirs

	-- delete all of the snapshot commands related to directories that were 
	-- cleaned up. SYNCINIT and SYNCDONE tokens for concurrent snapshot will 
	-- be cleaned up by retention period in the next section below... We do
	-- not attempt to remove the SYNCINIT or SYNCDONE tokens earlier because
	-- we have no safe way of associating them with a particular snapshot.
	-- Also, we can't tell if the tokens are needed by an existing snapshot.
	WHILE 1 = 1
    BEGIN
		DELETE TOP(2000) MSrepl_commands WITH (PAGLOCK) from MSrepl_commands with (INDEX(ucMSrepl_commands))
			WHERE publisher_database_id = @publisher_database_id 
				AND xact_seqno IN (SELECT DISTINCT snap_xact_seqno 
									FROM @snapshot_xact_seqno)
			OPTION (MAXDOP 1)

		SELECT @row_count = @@rowcount

		-- Update output parameter
    	SELECT @num_commands = @num_commands + @row_count
    
        IF @row_count < 2000 -- passed the result set.  We're done
            BREAK
	END

    -- Since we're cleaning up, we set the lock timeout to immediate
    --  this way we shouldn't interfere with the other agents using the table.

    -- Holding off for some testing on this
    --SET LOCK_TIMEOUT 1

    -- Delete all commans less than or equal to the @max_xact_seqno
    -- Delete in batch to reduce the transaction size

    WHILE 1 = 1
    BEGIN
		if @has_immediate_sync = 0
			DELETE TOP(2000) MSrepl_commands WITH (PAGLOCK) from MSrepl_commands with (INDEX(ucMSrepl_commands)) where
				publisher_database_id = @publisher_database_id and
				xact_seqno <= @max_xact_seqno and
				(type & ~@snapshot_bit) not in (@directory_type, @alt_directory_type) and
				(type & ~@replpost_bit) <> @scriptexec_type
				OPTION (MAXDOP 1)
		else
			-- Use nolock hint on subscription table to avoid deadlock
			-- with snapshot agent.
			DELETE TOP(2000) MSrepl_commands WITH (PAGLOCK) from MSrepl_commands with (INDEX(ucMSrepl_commands)) where
				publisher_database_id = @publisher_database_id and
				xact_seqno <= @max_xact_seqno and
				-- do not delete directory, alt directory or script exec commands. they are deleted 
				-- above. We have to do this because we use a (nolock) hint and we have to make sure we 
				-- don't delete dir commands when the file has not been cleaned up in the code above. It's
				-- ok to delete snap commands that are out of retention and perform lazy delete of dir
				(type & ~@snapshot_bit) not in (@directory_type, @alt_directory_type) and
				(type & ~@replpost_bit) <> @scriptexec_type and
				(
					-- Select the row if it is older than max retention.
					xact_seqno <= @max_immediate_sync_seqno or 
					-- Select the snap cmd if it is not for immediate_sync article
					-- We know the command is for immediate_sync publication if
					-- the snapshot tran include articles that has virtual
					-- subscritptions. (use subscritpion table to avoid join with
					-- article and publication table). We skip sync tokens because 
					-- they are never pointed to by subscriptions...
					(
						(type & @snapshot_bit) <> 0 and
						(type & ~@snapshot_bit) not in (@syncinit, @syncdone) and
						not exists (select * from MSsubscriptions s with (nolock) where
							s.publisher_database_id = @publisher_database_id and
							s.article_id = MSrepl_commands.article_id and
							s.subscriber_id < 0)
					)
				)
				OPTION (MAXDOP 1)

		select @row_count = @@rowcount
        -- Update output parameter
        select @num_commands = @num_commands + @row_count
    
        IF @row_count < 2000 -- passed the result set.  We're done
            BREAK
    END
    
    -- get the max transaction row
    select @last_log_xact_seqno = max(xact_seqno) from MSrepl_transactions
		where publisher_database_id = @publisher_database_id 
        	and xact_id <> 0x0  -- not initial sync transaction

    select @last_xact_seqno = max(xact_seqno) from MSrepl_transactions
		where publisher_database_id = @publisher_database_id

    -- Remove all transactions less than or equal to the @max_xact_seqno and leave the 
    -- last transaction row
    -- Note @max_xact_seqno might be null, in this case don't do any thing.
    -- Delete in batchs to reduce the transaction size

    -- Delete all commans less than or equal to the @max_xact_seqno
    -- Delete  rows to reduce the transaction size
    WHILE 1 = 1
    BEGIN
		exec dbo.sp_MSdelete_dodelete @publisher_database_id, 
										@max_xact_seqno, 
										@last_xact_seqno, 
										@last_log_xact_seqno,
										@has_immediate_sync


        select @row_count = @@rowcount

        -- Update output parameter
        select @num_transactions = @num_transactions + @row_count
        if @row_count < 5000
            BREAK
    END
GO

--
-- Name: sp_MSmaximum_cleanup_seqno
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSmaximum_cleanup_seqno')
go
CREATE PROCEDURE sp_MSmaximum_cleanup_seqno
	@publisher_database_id int,
	@min_cutoff_time datetime,
	@max_cleanup_xact_seqno varbinary(16) OUTPUT
	as

	declare @min_agent_sub_xact_seqno varbinary(16)
				,@max_agent_hist_xact_seqno varbinary(16)
				,@active int
				,@initiated int
				,@agent_id int
				,@min_xact_seqno varbinary(16)
                

	-- set @min_xact_seqno to NULL and reset it with the first prospect of min_seqno we found later
	select @min_xact_seqno = NULL

	set nocount on

	select @active = 2
	select @initiated = 3

	--
	-- cursor through each agent with it's smallest sub xact seqno
	--
	declare #tmpAgentSubSeqno cursor local forward_only  for
	select a.id, min(s2.subscription_seqno) from
                        MSsubscriptions s2 
                        join MSdistribution_agents a
                        on (a.id = s2.agent_id) 
                        where
	                        s2.status in( @active, @initiated ) and
	                        /* Note must filter out virtual anonymous agents !!!
                                      a.subscriber_id <> @virtual_anonymous and */
                            -- filter out subscriptions to immediate_sync publications
                            not exists (select * from MSpublications p where
                                        s2.publication_id = p.publication_id and
                                        p.immediate_sync = 1) and
	                        a.publisher_database_id = @publisher_database_id
	                        group by a.id
	open #tmpAgentSubSeqno 
	fetch #tmpAgentSubSeqno into @agent_id, @min_agent_sub_xact_seqno 
	
    if (@@fetch_status = -1) -- rowcount = 0 (no subscriptions)
    begin
        -- If we have a publication which allows for init from backup with a min_autonosync_lsn set
        --   we don't want this proc to signal cleanup of all commands
        -- Note that if we filter out immediate_sync publications here as they will already have the
        --   desired outcome.  The difference is that those with min_autonosync_lsn set have a watermark
        --   at which to begin blocking cleanup.
		if not exists (select * from dbo.MSpublications msp
                join MSpublisher_databases mspd ON mspd.publisher_id = msp.publisher_id 
                    and mspd.publisher_db = msp.publisher_db
                where mspd.id = @publisher_database_id and msp.immediate_sync = 1)
		begin
            select top(1) @min_xact_seqno = msp.min_autonosync_lsn from dbo.MSpublications msp
                    join MSpublisher_databases mspd ON mspd.publisher_id = msp.publisher_id 
                        and mspd.publisher_db = msp.publisher_db
                    where mspd.id = @publisher_database_id 
                        and msp.allow_initialize_from_backup <> 0
                        and msp.min_autonosync_lsn is not null
                        and msp.immediate_sync = 0
					order by msp.min_autonosync_lsn asc
		end
    end
    
    while (@@fetch_status <> -1)
	begin
	    --
	    --always clear the local variable, next query may not return any resultset
	    --
	    set @max_agent_hist_xact_seqno = NULL

	    --
	    --find last history entry for current agent, if no history then the query below should leave @max_agent_xact_seqno as NULL
	    --
	    select top 1 @max_agent_hist_xact_seqno = xact_seqno from MSdistribution_history where agent_id = @agent_id 
	             order by timestamp desc

	    --
	    --now find the last xact_seqno this agent has delivered:
	    --if last history was written after initsync, use histry xact_seqno otherwise use initsync xact_seqno        
	    --
	    if isnull(@max_agent_hist_xact_seqno, @min_agent_sub_xact_seqno) <= @min_agent_sub_xact_seqno 
	    begin
	         set @max_agent_hist_xact_seqno = @min_agent_sub_xact_seqno
	    end
	    --@min_xact_seqno was set to NULL to start with, the first time we get here, it'll gets set to a non-NULL value
	    --then we graduately move to the smallest hist/sub seqno
	    if ((@min_xact_seqno is null) or (@min_xact_seqno > @max_agent_hist_xact_seqno))
	    begin 
	        set @min_xact_seqno = @max_agent_hist_xact_seqno 
	    end
	    fetch #tmpAgentSubSeqno into @agent_id, @min_agent_sub_xact_seqno 
	end
	close #tmpAgentSubSeqno
	deallocate #tmpAgentSubSeqno

	/* 
	** Optimized query to get the maximum cleanup xact_seqno
	*/
	/* 
	** If the query below returns nothing, nothing can be deleted.
	** Reset @max_cleanup_xact_seqno to 0.
	*/
	select @max_cleanup_xact_seqno = 0x00
	-- Use top 1 to avoid warning message of "Null in aggregate..." which will make
	-- sqlserver agent job having failing status

	select top 1 @max_cleanup_xact_seqno = xact_seqno
	    from MSrepl_transactions with (nolock)
	    where
	        publisher_database_id = @publisher_database_id and
	        (xact_seqno < @min_xact_seqno
	        	or @min_xact_seqno IS NULL) and
	        entry_time <= @min_cutoff_time
	        order by xact_seqno desc
GO

--
-- Name: sp_MSdistribution_delete
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSdistribution_delete')
go
CREATE PROCEDURE sp_MSdistribution_delete
    @retention int = 0,
	-- Used for anon publications.
	@max_cutoff_time datetime
    as
    declare @min_cutoff_time datetime
    declare @subscriber sysname
    declare @subscriber_db sysname
    declare @max_cleanup_xact_seqno varbinary(16)   
    declare @num_transactions int
    declare @num_commands int
    declare @start_time datetime
    declare @num_seconds int
    declare @rate int
    declare @retcode int
    declare @publisher_database_id int

    set nocount on

    select @num_transactions = 0
    select @num_commands = 0

    select @start_time = getdate()
    select @min_cutoff_time = dateadd(hour, -@retention, getdate())

    -- For each publisher/publisherdb pair do cleanup
    declare hC CURSOR LOCAL FAST_FORWARD FOR select distinct publisher_database_id
        from MSrepl_transactions
        for read only
    -- With ANSI Defaults ON, the cursor will automatically
    -- be closed on commit.   Since this proc gets called recursively, 
    -- this can happen.  So check before opening. 
    IF CURSOR_STATUS('local','hC') = -1
    open hC

    fetch hC into @publisher_database_id 
    while (@@fetch_status <> -1)
    begin

        -- Find the maximum transaction to delete
        exec @retcode = dbo.sp_MSmaximum_cleanup_seqno @publisher_database_id, @min_cutoff_time, @max_cleanup_xact_seqno OUTPUT
        if @retcode <> 0
            goto FAIL           

        -- Delete transactions and commands
        exec @retcode = dbo.sp_MSdelete_publisherdb_trans @publisher_database_id, 
			@max_cleanup_xact_seqno, @max_cutoff_time,
            @num_transactions OUTPUT, @num_commands OUTPUT
        if @retcode <> 0
            goto FAIL

        IF CURSOR_STATUS('local','hC') = -1
            open hC
        
        fetch hC into @publisher_database_id 
    end
    close hC
    deallocate hC

    select @num_seconds = datediff(second, @start_time, getdate())
    if @num_seconds <> 0 
      select @rate = (@num_transactions+@num_commands)/@num_seconds
    else
      select @rate = 0
	-- raise more frequently (ie 2k rows or so)
	-- modify sp_MSdelete_publisherdb_trans (line 3500)
	-- snapshot history? job history?
	-- TODO TODO TODO
   RAISERROR(21010, 10, -1, @num_transactions, @num_commands, @num_seconds, @rate)

   return 0

FAIL:
   close hC
   deallocate hC
   return 1
GO

--
-- Name: sp_MSdistribution_cleanup
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSdistribution_cleanup')
GO
CREATE PROCEDURE sp_MSdistribution_cleanup
    @min_distretention int = 0,
    @max_distretention int = 24,
    @no_applock bit = 0
as
	SET DEADLOCK_PRIORITY LOW 
    declare @retcode int
    declare @agent_name nvarchar(255)
    declare @agent_type nvarchar(100)
    declare @message nvarchar(255)
	declare @cutoff_time datetime

     -- Check for invalid parameter values 
    if @min_distretention < 0 or @max_distretention < 0
    begin
        RAISERROR(14106, 16, -1)
        return (1)
    end

    declare @lockresource nvarchar(255),
            @acquiredapplicationlock bit

    -- 1) Acquire no-sync subscription setup lock up-front to prevent
    -- the cleanup task from interfering any no-sync subscription setup 
    -- task that may be in progress.
    
    -- WARNING: Before calling sp_MSdistribution_cleanup from another
    -- stored procedure or replication agent with @no_applock = 0,
    -- consider that the application lock acquired by 
    -- sp_MSdistribution_cleanup is owned by the current session and it may
    -- not be released properly by the time sp_MSdistribution_cleanup exits
    -- if the batch is aborted. It is ok for the distribution cleanup 
    -- job to call this procedure directly because SQLServerAgent makes a new
    -- connection every time a job runs.
    
    select @acquiredapplicationlock = 0

    if @no_applock = 0
    begin
        select @lockresource = db_name() + N'_nosync'
        exec @retcode = sys.sp_getapplock @Resource = @lockresource,
                                          @LockMode = 'Shared',
                                          @LockOwner = 'Session',
                                          @LockTimeout = -1,
                                          @DbPrincipal = 'db_owner' 
        -- No timeout! No-sync setup process should never take long and the 
        -- Transaction-owned lock acquired by the no-sync setup process has 
        -- to be released in the event of a catastrophic failure.  

        if @retcode < 0 or @@error <> 0 begin select @retcode = 1 goto FAIL end
        select @retcode = 0, @acquiredapplicationlock = 1
    end

	-- Update statistics on tables with norecompute flag
    -- to both update the statistics periodically and 
    -- to ensure that they are not updated too frequently
    -- since this slows performance.
    --
    -- Update statistics can only be performed when not in
    -- a transaction so predicate by transaction level check
    -- to avoid error.
    --
    if @@trancount = 0
    begin
        UPDATE STATISTICS MSrepl_commands WITH NORECOMPUTE
        UPDATE STATISTICS MSrepl_transactions WITH NORECOMPUTE
    end

	-- Note: we need to use the same cut_off time for sp_MSsubscription_cleanup
	-- and sp_MSdistribution_delete since sp_MSsubscription_cleanup need to disable
	-- all the dist agents that are lag behind (their pending trans will be removed)
    select @cutoff_time = dateadd(hour, -@max_distretention, getdate())

    -- Deactive any subscriptions which have been inactive beyond the maximum retention
    exec @retcode = dbo.sp_MSsubscription_cleanup @cutoff_time
    if @retcode <> 0
        goto FAIL
 
    -- Remove transactions and commands
    exec @retcode = dbo.sp_MSdistribution_delete @min_distretention, 
		-- used to cleanup trans for anon publications.
		@cutoff_time
    if @retcode <> 0
        goto FAIL

    -- Update statistics on cleaned tables with norecompute flag
    -- to both update the statistics periodically and 
    -- to ensure that they are not updated too frequently
    -- since this slows performance.
    --
    -- Update statistics can only be performed when not in
    -- a transaction so predicate by transaction level check
    -- to avoid error.
    --
    if @@trancount = 0
    begin
        UPDATE STATISTICS MSrepl_commands WITH NORECOMPUTE
        UPDATE STATISTICS MSrepl_transactions WITH NORECOMPUTE
    end

    if @acquiredapplicationlock = 1
    begin
        exec sys.sp_releaseapplock @Resource = @lockresource,
                                   @LockOwner = 'Session',
                                   @DbPrincipal = N'db_owner'
    end
    select @acquiredapplicationlock = 0
    return(0)

FAIL:
    if @acquiredapplicationlock = 1
    begin
        exec sys.sp_releaseapplock @Resource = @lockresource,
                                   @LockOwner = 'Session',
                                   @DbPrincipal = N'db_owner'
    end
    -- Raise the Agent Failure error
    set @agent_type  = formatmessage(20543)
    SELECT @agent_name = db_name() + @agent_type
    set @message  = formatmessage(20552)
    exec sys.sp_MSrepl_raiserror @agent_type, @agent_name, 5, @message
    return (1)  

GO

--
-- Name: sp_MShistory_cleanup
--
-- Descriptions: 
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MShistory_cleanup')
GO
CREATE PROCEDURE sp_MShistory_cleanup
(
	@history_retention int = 24
)
AS
BEGIN
    DECLARE @cutoff_time datetime
				,@replerr_cutoff datetime
				,@start_time datetime
				,@num_snapshot_rows int
				,@num_logreader_rows int
				,@num_distribution_rows int
				,@num_replerror_rows int
				,@num_queuereader_rows int
				,@num_alert_rows int
				,@num_tracer_record_rows int
				,@num_milliseconds int
				,@num_seconds float
				,@seconds_str nvarchar(10)
				,@rate int
				,@retcode int
				,@total_rows int
				,@num_merge_rows int
				,@num_merge_deleted_articlehistory int
				,@agent_name nvarchar(255)
				,@agent_type nvarchar(100)
				,@message nvarchar(255)
				,@agent_id int
				,@error int

    SET NOCOUNT ON

    -- Check for invalid parameter values
    IF @history_retention < 0
    BEGIN
        RAISERROR(14106, 16, -1)
        RETURN 1
    END
    
    -- Get start time for statistics at the end
	-- Get cutoff time
	-- cleanup MSrepl_error with HistoryRetention+30 days
    SELECT @start_time							= getdate(),
			@num_snapshot_rows					= 0,
			@num_logreader_rows					= 0,
			@num_distribution_rows				= 0,
			@num_merge_rows						= 0,
			@num_replerror_rows					= 0,
			@num_queuereader_rows				= 0,
			@num_merge_deleted_articlehistory	= 0,
			@cutoff_time						= dateadd(hour, -@history_retention, getdate()),
			@replerr_cutoff						= dateadd(hour, -@history_retention - 30*24, getdate())
	
	DECLARE #crSnapshotAgents CURSOR LOCAL FAST_FORWARD FOR
		SELECT id
			FROM MSsnapshot_agents
	
	OPEN #crSnapshotAgents
	
	FETCH #crSnapshotAgents INTO @agent_id
	WHILE @@FETCH_STATUS <> -1
	BEGIN
	 
		-- Delete sp_MSsnapshot_history (leave at least one row for monitoring)
		DELETE MSsnapshot_history 
			WHERE agent_id = @agent_id
				AND time <= @cutoff_time 
				AND timestamp not in (SELECT max(timestamp) 
										FROM MSsnapshot_history 
										WHERE agent_id = @agent_id)
			OPTION(MAXDOP 1)

		SELECT @error = @@error, @num_snapshot_rows = @num_snapshot_rows + @@rowcount
		IF @error <> 0
			GOTO FAILURE

		FETCH #crSnapshotAgents INTO @agent_id
	END

	CLOSE #crSnapshotAgents
	DEALLOCATE #crSnapshotAgents

    -- Delete sp_MSsnapshot_history that no longer has an MSsnapshot_agent entry
    DELETE FROM MSsnapshot_history 
		WHERE NOT EXISTS (SELECT * 
							FROM MSsnapshot_agents
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_snapshot_rows = @num_snapshot_rows + @@rowcount
	IF @error <> 0
		GOTO FAILURE

    -- Delete sp_MSlogreader_history (leave at least one row for monitoring)
	DECLARE #crLogreaderAgents CURSOR LOCAL FAST_FORWARD FOR
		SELECT id
			FROM MSlogreader_agents
	
	OPEN #crLogreaderAgents
	
	FETCH #crLogreaderAgents INTO @agent_id
	WHILE @@FETCH_STATUS <> -1
	BEGIN
	 
		-- Delete sp_MSsnapshot_history (leave at least one row for monitoring)
		DELETE MSlogreader_history 
			WHERE agent_id = @agent_id
				AND time <= @cutoff_time 
				AND timestamp not in (SELECT max(timestamp) 
										FROM MSlogreader_history 
										WHERE agent_id = @agent_id)
			OPTION(MAXDOP 1)
		SELECT @error = @@error, @num_logreader_rows = @num_logreader_rows + @@rowcount
		IF @error <> 0
			GOTO FAILURE

		FETCH #crLogreaderAgents INTO @agent_id
	END

	CLOSE #crLogreaderAgents
	DEALLOCATE #crLogreaderAgents

    -- Delete sp_MSlogreader_history that no longer has an MSlogreader_agent entry
	DELETE FROM MSlogreader_history 
		WHERE NOT EXISTS (SELECT * 
							FROM MSlogreader_agents
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_logreader_rows = @num_logreader_rows + @@rowcount
	IF @error <> 0
		GOTO FAILURE

    -- Delete sp_MSdistribution_history (leave at least one row for monitoring)
	DECLARE #crDistribAgents CURSOR LOCAL FAST_FORWARD FOR
		SELECT id
			FROM MSdistribution_agents
	
	OPEN #crDistribAgents
	
	FETCH #crDistribAgents INTO @agent_id
	WHILE @@FETCH_STATUS <> -1
	BEGIN
	 
		-- Delete sp_MSsnapshot_history (leave at least one row for monitoring)
		DELETE MSdistribution_history 
			WHERE agent_id = @agent_id
				AND time <= @cutoff_time 
				AND timestamp not in (SELECT max(timestamp) 
										FROM MSdistribution_history 
										WHERE agent_id = @agent_id)
			OPTION(MAXDOP 1)
		SELECT @error = @@error, @num_distribution_rows = @num_distribution_rows + @@rowcount
		IF @error <> 0
			GOTO FAILURE

		FETCH #crDistribAgents INTO @agent_id
	END

	CLOSE #crDistribAgents
	DEALLOCATE #crDistribAgents

    -- Delete sp_MSlogreader_history that no longer has an MSlogreader_agent entry
	DELETE FROM MSdistribution_history 
		WHERE NOT EXISTS (SELECT * 
							FROM MSdistribution_agents
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_distribution_rows = @num_distribution_rows + @@rowcount
	IF @error <> 0
		GOTO FAILURE

    -- Delete MSqreader_history (leave at least one row for monitoring)
	DECLARE #crQreaderAgents CURSOR LOCAL FAST_FORWARD FOR
		SELECT id
			FROM MSqreader_agents
	
	OPEN #crQreaderAgents
	
	FETCH #crQreaderAgents INTO @agent_id
	WHILE @@FETCH_STATUS <> -1
	BEGIN
	 
		-- Delete sp_MSsnapshot_history (leave at least one row for monitoring)
		DELETE MSqreader_history 
			WHERE agent_id = @agent_id
				AND time <= @cutoff_time 
				AND timestamp not in (SELECT max(timestamp) 
										FROM MSqreader_history 
										WHERE agent_id = @agent_id)
			OPTION(MAXDOP 1)
		SELECT @error = @@error, @num_queuereader_rows = @num_queuereader_rows + @@rowcount
		IF @error <> 0
			GOTO FAILURE

		FETCH #crQreaderAgents INTO @agent_id
	END

	CLOSE #crQreaderAgents
	DEALLOCATE #crQreaderAgents

    -- Delete sp_MSlogreader_history that no longer has an MSlogreader_agent entry
	DELETE FROM MSqreader_history 
		WHERE NOT EXISTS (SELECT * 
							FROM MSqreader_agents
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_queuereader_rows = @num_queuereader_rows + @@rowcount
	IF @error <> 0
		GOTO FAILURE

    -- Delete sp_MSmerge_history (leave at least one row for monitoring)
    -- Leave last record ONLY if the agent is not anonymous.  The current logic is to remove all history for anonymous
    -- subscription, the agent definition will also be removed below.
    -- use session id
    DELETE dbo.MSmerge_history
		FROM dbo.MSmerge_history msmh
			JOIN dbo.MSmerge_sessions msms 
				ON msmh.session_id = msms.session_id
		WHERE msms.end_time <= @cutoff_time
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_merge_rows = @num_merge_rows + @@rowcount
    IF @error <> 0
		GOTO FAILURE

    -- Delete sp_MSmerge_history that no longer has an MSmerge_agent entry
    DELETE FROM dbo.MSmerge_history 
		WHERE NOT EXISTS (SELECT * 
							FROM dbo.MSmerge_agents 
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_merge_rows = @num_merge_rows + @@rowcount
    IF @error <> 0
		GOTO FAILURE

    -- Delete MSrepl_error entries
    DELETE FROM MSrepl_errors 
		WHERE time <= @replerr_cutoff 
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_replerror_rows = @@rowcount
    IF @error <> 0
		GOTO FAILURE

	-- similiar to above time based cleanup, we need to clean up added tables
	DELETE dbo.MSmerge_articlehistory
		FROM dbo.MSmerge_articlehistory msmah 
			JOIN dbo.MSmerge_sessions msms
				ON msmah.session_id = msms.session_id
		WHERE msms.end_time <= @cutoff_time
		OPTION(MAXDOP 1)
	SELECT @error = @@error, @num_merge_deleted_articlehistory = @num_merge_deleted_articlehistory + @@rowcount
    IF @error <> 0
		GOTO FAILURE
        
    DELETE FROM dbo.MSmerge_sessions 
		WHERE end_time <= @cutoff_time
			AND session_id NOT IN (SELECT max(session_id) 
									from dbo.MSmerge_sessions 
									group by agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_merge_rows = @num_merge_rows + @@rowcount
    IF @error <> 0
		GOTO FAILURE
        
    -- Delete MSmerge_sessions that no longer has an MSmerge_agent entry
    DELETE FROM dbo.MSmerge_sessions 
		WHERE NOT EXISTS (SELECT * 
							FROM dbo.MSmerge_agents 
							WHERE id = agent_id)
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_merge_rows = @num_merge_rows + @@rowcount
    IF @error <> 0
		GOTO FAILURE
		
	-- Delete sysreplicationalerts table
    DELETE FROM msdb.dbo.sysreplicationalerts 
		WHERE time <= @cutoff_time 
		OPTION(MAXDOP 1)
    SELECT @error = @@error, @num_alert_rows = @@rowcount
    IF @error <> 0
		GOTO FAILURE

	-- Delete Tracer Record history rows
	EXEC @error = sys.sp_MSdelete_tracer_history @cutoff_date = @cutoff_time, @num_records_removed = @num_tracer_record_rows output
	IF @error <> 0
        GOTO FAILURE

    -- Calculate statistics for number of rows deleted
    SELECT @num_milliseconds = datediff(millisecond, @start_time, getdate())
    IF @num_milliseconds <> 0
        SELECT @num_seconds = @num_milliseconds*1.0/1000
    ELSE
        SELECT @num_seconds = 0

    SELECT @total_rows = @num_merge_rows + 
    						@num_merge_deleted_articlehistory +
    						@num_snapshot_rows + 
							@num_logreader_rows + 
							@num_distribution_rows +  
							@num_queuereader_rows +
							@num_replerror_rows + 
							@num_alert_rows + 
							@num_tracer_record_rows

    IF @num_seconds <> 0 
        SELECT @rate = @total_rows/@num_seconds
    ELSE
        SELECT @rate = @total_rows

    SELECT @seconds_str = CONVERT(nchar(10), @num_seconds)

    RAISERROR(14108, 10, -1, @num_merge_rows, 'MSmerge_history')
	RAISERROR(14108, 10, -1, @num_merge_deleted_articlehistory, 'MSmerge_articlehistory')
	RAISERROR(14108, 10, -1, @num_snapshot_rows, 'MSsnapshot_history')
    RAISERROR(14108, 10, -1, @num_logreader_rows, 'MSlogreader_history')
    RAISERROR(14108, 10, -1, @num_distribution_rows, 'MSdistribution_history')
    RAISERROR(14108, 10, -1, @num_queuereader_rows, 'MSqreader_history')
    RAISERROR(14108, 10, -1, @num_replerror_rows, 'MSrepl_errors')
    RAISERROR(14108, 10, -1, @num_alert_rows, 'sysreplicationalerts')
    RAISERROR(14108, 10, -1, @num_tracer_record_rows, 'MStracer_tokens')
	RAISERROR(14149, 10, -1, @total_rows, @seconds_str, @rate)
    
    RETURN 0
FAILURE:
    -- Raise the Agent Failure error
    SELECT @agent_type  = formatmessage(20544),
			@agent_name = db_name() + @agent_type,
			@message	= formatmessage(20553)

    EXEC sys.sp_MSrepl_raiserror @agent_type, @agent_name, 5, @message

    RETURN 1
END
GO
--
-- Name: sp_MSget_repl_version
--
-- Descriptions: 
-- BUGBUG: Obsolete SP ???
--
-- Parameters: as defined in create statement
--
-- Returns: 0 - success
--          1 - Otherwise
--
-- Security: Not public (db owner chaining)
--
raiserror(15339,-1,-1,'sp_MSget_repl_version')
GO
CREATE PROCEDURE sp_MSget_repl_version
@major_version int = 0 OUTPUT,
@minor_version int = 0 OUTPUT,
@revision int = 0 OUTPUT

as
SELECT @major_version = major_version,
       @minor_version = minor_version,
       @revision = revision FROM MSrepl_version
GO

-- View for delivered and undelivered commands.   RHS  6-4-98
-- Since the view is likely to change, just recreate it each time.
IF EXISTS (SELECT * FROM sys.objects where name='MSdistribution_status' and type='V')
    DROP VIEW dbo.MSdistribution_status

/****************************************************************************/
raiserror('Creating view MSdistribution_status', 0,1)
/****************************************************************************/    
go

CREATE VIEW MSdistribution_status (article_id,agent_id,UndelivCmdsInDistDB,DelivCmdsInDistDB)
as
-- Note that this view does not account for (i.e. exclude from counts) commands that do not need to be delivered 
-- because of loopback or syncronous updating subscribers, nor subscriptions never activated.
-- It also may not be exact due to use of NOLOCK - so that it does not cause blocking or deadlock issues.
SELECT t.article_id,s.agent_id,
'UndelivCmdsInDistDB'=SUM(CASE WHEN xact_seqno > h.maxseq THEN 1 ELSE 0 END),
'DelivCmdsInDistDB'=SUM(CASE WHEN xact_seqno <=  h.maxseq THEN 1 ELSE 0 END)
FROM	(SELECT	article_id,publisher_database_id, xact_seqno
	FROM MSrepl_commands with (NOLOCK) ) as t
JOIN (SELECT agent_id,article_id,publisher_database_id FROM MSsubscriptions with (NOLOCK) ) AS s 
ON (t.article_id = s.article_id AND t.publisher_database_id=s.publisher_database_id )
JOIN (SELECT agent_id,'maxseq'= isnull(max(xact_seqno),0x0) FROM MSdistribution_history with (NOLOCK) GROUP BY agent_id) as h
ON (h.agent_id=s.agent_id)
GROUP BY t.article_id,s.agent_id
go
    
-- As this view can add considerable overhead when queried, it intentionally is not granted public access by default.
-- A site may so grant it if it wants to of course
-- If the creator is DBO - this grant is redundant
-- GRANT SELECT ON MSdistribution_status to dbo
go

--
-- Name: 
--		sp_MSlog_agent_cancel
-- 
-- Description: 
--  
-- Parameters: 
--		as specified in create
--
-- Returns: 
--		0 - succeeded
--      1 - failed
--
-- Result: 
--		None
--
-- Security: 
--		Not public - db owner chaining 
--
raiserror(15339,-1,-1,'sp_MSlog_agent_cancel')
go
create procedure sp_MSlog_agent_cancel
@job_id binary(16),
@category_id int,
@message nvarchar(1024)
as
	-- This stored procedure is called by msdb proc, sp_sqlagent_log_jobhistory to
	-- log a agent cancel message to repl monitor (agent history tables) when the
	-- agent fails to log a complete message to repl monitor directly. 
	-- sp_MSdetect_nonlogged_shutdown would not help in this case, because that step
	-- will not be executed because the job is canceled before the step.
	declare @agent_id int

    if @category_id = 15
    begin
		-- Get agent_id
        select @agent_id = id from MSsnapshot_agents where job_id = @job_id
        if exists (select runstatus from MSsnapshot_history where 
            agent_id = @agent_id and
            runstatus <> 2 and 
			runstatus <> 5 and 
            runstatus <> 6 and
            timestamp = (select max(timestamp) from MSsnapshot_history where agent_id = @agent_id))
        begin
			-- Log error message.
			exec sys.sp_MSadd_snapshot_history @agent_id = @agent_id, @runstatus = 6,
					@comments = @message
        end
    end
    else if @category_id = 13
    begin
		-- Get agent_id
        select @agent_id = id from MSlogreader_agents where job_id = @job_id
        if exists (select runstatus from MSlogreader_history where 
            agent_id = @agent_id and
            runstatus <> 2 and 
			runstatus <> 5 and 
            runstatus <> 6 and
            timestamp = (select max(timestamp) from MSlogreader_history where agent_id = @agent_id))
            begin
				-- Log success message.
				exec sys.sp_MSadd_logreader_history @agent_id = @agent_id, @runstatus = 2,
						@comments = @message
            end
    end
    else if @category_id = 10
    begin
		-- Get agent_id
        select @agent_id = id from MSdistribution_agents where job_id = @job_id
        if exists (select runstatus from MSdistribution_history where 
            agent_id = @agent_id and
            runstatus <> 2 and 
			runstatus <> 5 and 
            runstatus <> 6 and
            timestamp = (select max(timestamp) from MSdistribution_history where agent_id = @agent_id))
            begin
				-- Log success message.
				exec sys.sp_MSadd_distribution_history @agent_id = @agent_id, @runstatus = 2,
						@comments = @message
            end
    end
    else if @category_id = 14
    begin
		-- Get agent_id
        select @agent_id = id from dbo.MSmerge_agents where job_id = @job_id
        if exists (select runstatus from dbo.MSmerge_sessions where 
            agent_id = @agent_id and
            runstatus <> 2 and 
			runstatus <> 5 and 
            runstatus <> 6 and
            session_id = (select top 1 session_id from dbo.MSmerge_sessions where agent_id = @agent_id order by session_id desc))
            begin
				declare @merge_session_id int
                               
                select top 1 @merge_session_id = session_id from dbo.MSmerge_sessions 
				where agent_id = @agent_id 
				order by session_id desc
            
				-- Log success message.
				exec sys.sp_MSadd_merge_history @agent_id = @agent_id, @runstatus = 2,
						@comments = @message, @session_id_override = @merge_session_id
            end
    end
    else if @category_id = 19
    begin
		-- Get agent_id
        select @agent_id = id from MSqreader_agents where job_id = @job_id
        if exists (select runstatus from MSqreader_history where 
            agent_id = @agent_id and
            runstatus <> 2 and 
			runstatus <> 5 and 
            runstatus <> 6 and
            timestamp = (select max(timestamp) from MSqreader_history where agent_id = @agent_id))
            begin
				-- Log success message.
				exec sys.sp_MSadd_qreader_history @agent_id = @agent_id, @runstatus = 2,
						@comments = @message
            end
    end

GO
--
-- Mark the local procedures, functions and necessary tables as
-- systemobjects
--
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSset_syncstate'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSadd_repl_commands27'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSadd_replcmds'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSremove_published_jobs'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSsubscription_cleanup'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSdelete_publisherdb_trans'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSmaximum_cleanup_seqno'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSdistribution_delete'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSdistribution_cleanup'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MShistory_cleanup'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSget_repl_version'
exec dbo.sp_MS_marksystemobject N'dbo.MSdistribution_status'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSlog_agent_cancel'
exec dbo.sp_MS_marksystemobject N'dbo.sp_MSdelete_dodelete'
exec dbo.sp_MS_marksystemobject N'dbo.fn_MSmask_agent_type'
go

/****************************************************************************/
print ''
print 'Adding user ''guest''.'
print ''
/****************************************************************************/
if not exists (select * from sysusers where
	name = N'guest' and
	hasdbaccess = 1)
	EXEC  dbo.sp_adduser 'guest'

/****************************************************************************/
print ''
print 'Adding role ''replmonitor''.'
print ''
/****************************************************************************/
if not exists (select * from sysusers where
	name = N'replmonitor' and
	issqlrole = 1)
	EXEC  dbo.sp_addrole 'replmonitor'

go 

checkpoint
go

EXEC dbo.sp_configure 'allow updates', 0
GO

reconfigure with override
GO
-- - ----
