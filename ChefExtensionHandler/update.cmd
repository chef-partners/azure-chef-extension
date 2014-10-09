
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-update.psm1;Update-ChefClient