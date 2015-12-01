
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

set uninstall_chef_client=false

if "%uninstall_chef_client%"=="true" (
  powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-uninstall.psm1;Uninstall-ChefClient
)