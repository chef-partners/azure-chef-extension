
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

ruby %CHEF_EXT_DIR%bin\chef-disable.rb