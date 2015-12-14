
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

call:Get-Settings-File
call:Get-Uninstall-Chef-Client-Flag

if [%uninstall_chef_client%] == [true] (
  powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-uninstall.psm1;Uninstall-ChefClient
)
GOTO:EOF

:Get-Settings-File
  set config_root_path=%CHEF_EXT_DIR%\\RuntimeSettings
  set config_files_path=%config_root_path%\\*.settings
  set config_file=dir /b %config_files_path% | sort /r /+1 | head -1
  set config_file_path=%config_root_path%\\%config_file%
  echo %config_file_path%
GOTO:EOF

:Get-Uninstall-Chef-Client-Flag
  if [%config_file_path%] == [] (
    set uninstall_chef_client=false
    echo %uninstall_chef_client%
  ) else (
      ::TODO retrieve uninstall chef client flag from settings file
    )
GOTO:EOF
