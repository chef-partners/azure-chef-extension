

#    - may start additional service or modified chef-service that is capable of
#      - read HandlerEnvironment.json from root folder and pass info like log location to chef-client run
#      - read <SequenceNumber>.settings to read settings like runlist passed by user
#        (SequenceNumber: is it specified in HandlerEnvironment.json? docs says but not in sample)
#      - reporting chef-client run status to status file to be read guest agent: “<SequenceNumber>.status”
#        (is SequenceNumber per new version of handler deployed to VM?
#        do we need to purge older sequencenumber.status files, say maintain max of 10 recent files?)
#      - reporting heartbeat i.e. this service is ready/notready with more info to heartbeat file
#      - service should manage file read/write conflicts with Guest Agent.

# XXX - For demo start service using existing service manager which cannot report any azure expected status

# XXX - this is repeated, we should find how not to
function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

# Source the shared PS
$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\..")
. $chefExtensionRoot\bin\shared.ps1

Write-ChefStatus "configuring-chef-service" "transitioning"

function validate-client-rb-file ([string] $client_rb)
{
  echo $client_rb

  #compulsory: chef_server_url, validation_client_name
  #log_location should be c:/chef/chef.log
  #org should be same in chef_server_url and validation_client_name
  #hard code validation_key and client_key to c:/chef/<v/c>.pem

}

$bootstrapDirectory="C:\\chef"

$handlerSettings = getHandlerSettings

# Setup the client.rb, validation.pem and first run of chef-client, do this only once post install.
# "node-registered" file also indicates that enabled was called once and configs are already generated.
if (! (Test-Path $bootstrapDirectory\node-registered) ) {
  echo "Checking for existing directory $bootstrapDirectory"
  if ( !(Test-Path $bootstrapDirectory) ) {
    echo "Existing directory not found, creating."
    mkdir $bootstrapDirectory
  } else {
    echo "Existing directory found, skipping creation."
  }

  # Write validation key
  $decryptedSettings = decryptProtectedSettings $handlerSettings.protectedSettings $handlerSettings.protectedSettingsCertThumbprint | ConvertFrom-Json

  $decryptedSettings.validation_key | Out-File -filePath $bootstrapDirectory\validation.pem  -encoding "Default"
  echo "Created validation.pem"

  # Write client.rb
  $client_rb_file = $handlerSettings.publicSettings.client_rb
  echo "Client.rb input by user: $client_rb_file"
  $client_rb_file = validate-client-rb-file $client_rb_file
  $client_rb_file | Out-File -filePath $bootstrapDirectory\client.rb -encoding "Default"
  echo "Created client.rb..."

  # json
  $runList = $handlerSettings.publicSettings.runList
  @"
{
"run_list": [$runlist]
}
"@ | Out-File -filePath $bootstrapDirectory\first-boot.json -encoding "Default"
  echo "created first-boot.json"

  # run chef-client for first time
  echo "Running chef client"
  chef-client -c $bootstrapDirectory\client.rb -j $bootstrapDirectory\first-boot.json -E _default

  echo "Node registered." > $bootstrapDirectory\node-registered
}

# check if service is already installed?
$serviceStatus = chef-service-manager -a status
IF ( $serviceStatus -eq "Service chef-client doesn't exist on the system." )
{
  chef-service-manager -a install -c $bootstrapDirectory\client.rb -L $bootstrapDirectory\logs
}

Write-ChefStatus "starting-chef-service" "transitioning"

# start the chef service
$result = chef-service-manager -a start

if ($result -match "Service 'chef-client' is now 'running'.")
{ Write-ChefStatus "chef-service-started" "success" }
else
{ Write-ChefStatus "chef-service" "error" $result }
