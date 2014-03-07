@ECHO OFF
IF NOT "%~f0" == "~f0" GOTO :WinNT
REM XXX @"ruby.exe" "C:/opscode/chef/embedded/bin/chef-service-manager" %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO :EOF
:WinNT
@"ruby.exe" "%~dpn0" %*
