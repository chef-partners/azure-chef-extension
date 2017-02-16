
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

REM Doing required settings if Powershell Version is less than 3
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\shared.ps1;Run-Powershell2-With-Dot-Net4

REM Installing chef-client
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-install.psm1;Install-ChefClient

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

ruby %CHEF_EXT_DIR%bin\chef-enable.rb