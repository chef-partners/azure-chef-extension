

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

# Source the shared PS
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\..")
. $chefExtensionRoot\bin\shared.ps1

$bootstrapDirectory="C:\\chef"

$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

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
  $handlerSettings.protectedSettings.validation_key | Out-File -filePath $bootstrapDirectory\validation.pem  -encoding "Default"

  echo "Created validation.pem"

  # Write client.rb
  $chefServerUrl = $handlerSettings.publicSettings.chefServerUrl
  $chefOrgName = $handlerSettings.publicSettings.chefOrgName
  $hostName = hostname

  @"
log_level    :info
log_location    STDOUT

chef_server_url    "$chefServerUrl/$chefOrgName"
validation_client_name    "$chefOrgName-validator"
client_key    "$bootstrapDirectory/client.pem"
validation_key    "$bootstrapDirectory/validation.pem"

node_name    "$hostName"
"@ | Out-File -filePath $bootstrapDirectory\client.rb -encoding "Default"

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

# start the chef service
chef-service-manager -a start