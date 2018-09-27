ECHO OFF
echo Installing SQL Server 2008 R2 x86
date/t
time /t
"%CD%\SQLEXPRWT_x86_ENU\setup.exe" /ConfigurationFile="%CD%\SQLEXPRWT_x86_ENU\ConfigurationFile.ini"
date/t
time /t

set PORT=1433
set RULE_NAME="SQL Server %PORT%"

netsh advfirewall firewall show rule name=%RULE_NAME% >nul
if not ERRORLEVEL 1 (
    rem Rule %RULE_NAME% already exists.
    echo Hey, you already got a out rule by that name, you cannot put another one in!
) else (
    echo Rule %RULE_NAME% does not exist. Creating...
    netsh advfirewall firewall add rule name=%RULE_NAME% dir=in action=allow protocol=TCP localport=%PORT%
)