
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

set get_config_file_path_cmd=powershell -nologo -noprofile -executionpolicy unrestricted -Command ". %CHEF_EXT_DIR%bin\shared.ps1;Get-HandlerSettingsFilePath"

for /f "delims=" %%I in ('%get_config_file_path_cmd%') do set "config_file_path=%%I"

powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-uninstall.psm1;Uninstall-ChefClient 0 %config_file_path%
