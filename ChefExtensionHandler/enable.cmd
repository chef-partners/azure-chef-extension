
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%


REM Installing chef-client
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-install.psm1;Install-ChefClient

REM set envioronment variable CHEF_LICENSE to accept-no-persist if not defined (reference: https://docs.chef.io/chef_license_accept).
IF NOT DEFINED CHEF_LICENSE set CHEF_LICENSE=accept-no-persist

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

ruby %CHEF_EXT_DIR%bin\chef-enable.rb