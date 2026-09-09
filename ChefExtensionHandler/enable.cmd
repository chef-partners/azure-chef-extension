
set CHEF_EXT_DIR=%~dp0

echo %CHEF_EXT_DIR%


REM Installing chef-client
powershell -nologo -noprofile -executionpolicy unrestricted Import-Module %CHEF_EXT_DIR%bin\chef-install.psm1;Install-ChefClient

REM set envioronment variable CHEF_LICENSE to accept-no-persist if not defined (reference: https://docs.chef.io/chef_license_accept).
IF NOT DEFINED CHEF_LICENSE set CHEF_LICENSE=accept-no-persist

set path=C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;%path%

REM chef-ice (Habitat) fallback: ruby and the chef gem live under C:\hab\pkgs\...,
REM not C:\opscode, so the omnibus PATH above never finds them.
where ruby >nul 2>nul
if not errorlevel 1 goto :ruby_found
for /f "delims=" %%R in ('dir /b /s /a-d "C:\hab\pkgs\core\ruby.exe" 2^>nul') do set "HAB_RUBY_EXE=%%R"
if not defined HAB_RUBY_EXE goto :ruby_found
for %%D in ("%HAB_RUBY_EXE%") do set "path=%%~dpD;%path%"
for /f "delims=" %%C in ('dir /b /s /a-d "C:\hab\pkgs\chef\chef-infra-client\chef-client.bat" 2^>nul ^| findstr /v /i "\\vendor\\"') do set "HAB_CHEF_BIN=%%~dpC"
if defined HAB_CHEF_BIN set "path=%HAB_CHEF_BIN%;%path%"
if defined HAB_CHEF_BIN set "GEM_PATH=%HAB_CHEF_BIN%..\vendor;%GEM_PATH%"

:ruby_found
ruby %CHEF_EXT_DIR%bin\chef-enable.rb