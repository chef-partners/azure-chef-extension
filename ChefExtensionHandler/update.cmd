
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

powershell -nologo -noprofile -executionpolicy unrestricted -File %CHEF_EXT_DIR%bin\chef-update.ps1