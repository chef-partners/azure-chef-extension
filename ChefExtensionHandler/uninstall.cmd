@echo off

set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

call:Get-Settings-File
call:Get-Uninstall-Chef-Client-Flag

if [%uninstall_chef_client_flag%] == [true] (
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
    set uninstall_chef_client_flag=false
  ) else (
      set ps_version_cmd=powershell -nologo -noprofile -executionpolicy unrestricted -Command "$PSVersionTable.PSVersion.Major"
      for /f "delims=" %%I in ('%ps_version_cmd%') do set "ps_version=%%I"
      if [%ps_version%] leq [2] (
        set uninstall_chef_client_ps2_cmd=powershell -nologo -noprofile -executionpolicy unrestricted -Command "[System.Reflection.Assembly]::LoadWithPartialName(\"System.Web.Extensions\") > $null;$config_json_contents = Get-Content %config_file_path% -Raw;$serObj = New-Object System.Web.Script.Serialization.JavaScriptSerializer;$psObj = New-Object PSObject -Property $serObj.DeserializeObject($config_json_contents);$uninstall_chef_client_ps2 = $psObj.runtimeSettings.handlerSettings.publicSettings.uninstallChefClient;$uninstall_chef_client_ps2"

        for /f "delims=" %%J in ('%uninstall_chef_client_ps2_cmd%') do set "uninstall_chef_client_flag=%%J"
      ) else if [%ps_version%] gtr [2] (
          set uninstall_chef_client_ps3_cmd=powershell -nologo -noprofile -executionpolicy unrestricted -Command "$settingsData = Get-Content %config_file_path% -Raw | ConvertFrom-Json;$uninstall_chef_client_ps3 = $settingsData.runtimesettings.handlersettings.publicsettings.uninstallChefClient;$uninstall_chef_client_ps3"

          for /f "delims=" %%K in ('%uninstall_chef_client_ps3_cmd%') do set "uninstall_chef_client_flag=%%K"
        )
    )
GOTO:EOF
