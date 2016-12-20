
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

REM Installing chef-client
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-install.psm1;Install-ChefClient

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

ruby %CHEF_EXT_DIR%bin\chef-enable.rb