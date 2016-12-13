
REM Moved the installation steps into enable phase for windows
REM Because n.settings file is not available during install phase.
REM We need to read some values like bootstrap_version(chef-client version)
REM And daemon from n.settings during install

ECHO "Doing Nothing in Install phase"
