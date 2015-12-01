
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

if exist c:\chef\.auto_update_false (
    echo "Not doing extension enable as autoUpdateClient=false"
    del c:\chef\.auto_update_false
    exit
) else (
    ruby %CHEF_EXT_DIR%bin\chef-enable.rb
)