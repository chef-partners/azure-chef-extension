set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

REM Moved the installation steps into enable phase for windows
REM Because n.settings file is not available during install phase.
REM We need to read some values like bootstrap_version(chef-client version)
REM And daemon from n.settings during install

REM Doing required settings if Powershell Version is less than 3
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\shared.ps1;Run-Powershell2-With-Dot-Net4

