
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

powershell -File %CHEF_EXT_DIR%bin\chef-enable.ps1