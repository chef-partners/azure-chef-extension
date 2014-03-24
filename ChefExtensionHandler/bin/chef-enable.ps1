

#    - may start additional service or modified chef-service that is capable of
#      - read HandlerEnvironment.json from root folder and pass info like log location to chef-client run
#      - read <SequenceNumber>.settings to read settings like runlist passed by user
#        (SequenceNumber: is it specified in HandlerEnvironment.json? docs says but not in sample)
#      - reporting chef-client run status to status file to be read guest agent: “<SequenceNumber>.status”
#        (is SequenceNumber per new version of handler deployed to VM?
#        do we need to purge older sequencenumber.status files, say maintain max of 10 recent files?)
#      - reporting heartbeat i.e. this service is ready/notready with more info to heartbeat file
#      - service should manage file read/write conflicts with Guest Agent.

trap [Exception] {echo $_.Exception.Message;exit 1}

# XXX - this is repeated, we should find how not to
function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

function validate-client-rb-file ([string] $user_client_rb)
{
  $client_rb =  @"
    client_key    "$bootstrapDirectory/client.pem"
    validation_key    "$bootstrapDirectory/validation.pem"
    log_location    '$logFile'
"@

  # append client_rb to user_client rb to override client_key and validation_key
  $user_client_rb += "`r`n$client_rb"

  $user_client_rb
}

$scriptDir = Chef-Get-ScriptDirectory

# Source the shared PS
$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
. $chefExtensionRoot\\bin\\shared.ps1

Write-ChefStatus "configuring-chef-service" "transitioning" "Configuring Chef Service"

$bootstrapDirectory="C:\\chef"

$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

$handlerSettings = getHandlerSettings

# chef-client logs will be written to the folder provided by azure.
$logFile = Get-ChefLogFolder
$logFile = $logFile + "\\chef-client.log"

$firstRun = $false

# Setup the client.rb, validation.pem and first run of chef-client, do this only once post install.
# "node-registered" file also indicates that enabled was called once and configs are already generated.
if (! (Test-Path $bootstrapDirectory\\node-registered) ) {
  echo "Node not registered. Registering node..."
  if ( !(Test-Path $bootstrapDirectory) ) {
    echo "Existing $bootstrapDirectory directory not found, creating."
    mkdir $bootstrapDirectory
  } else {
    echo "Existing $bootstrapDirectory directory found, skipping creation."
  }

  # Write validation key
  $decryptedSettings = decryptProtectedSettings $handlerSettings.protectedSettings $handlerSettings.protectedSettingsCertThumbprint | ConvertFrom-Json

  $decryptedSettings.validation_key | Out-File -filePath $bootstrapDirectory\\validation.pem  -encoding "Default"
  echo "Created validation.pem"

  # Write client.rb
  $client_rb_file = $handlerSettings.publicSettings.client_rb
  $client_rb_file = validate-client-rb-file $client_rb_file
  $client_rb_file | Out-File -filePath $bootstrapDirectory\\client.rb -encoding "Default"
  echo "Created client.rb"

  # json
  $runList = $handlerSettings.publicSettings.runList

  # run chef-client for first time with no runlist to register it
  echo "Running chef client for first time with no runlist..."

  # Set flag for first run of chef-client
  $firstRun = $true

  chef-client -c $bootstrapDirectory\\client.rb -E _default -L $logFile
  if (!($?))
  {
    echo "Chef run failed. Exiting..."
    exit 1
  }

  @"
{
"run_list": [$runlist]
}
"@ | Out-File -filePath $bootstrapDirectory\\first-boot.json -encoding "Default"
  echo "Created first-boot.json"

  echo "Node registered." > $bootstrapDirectory\\node-registered
  echo "Node registered successfully"
}
else {
  echo "Node registered. Not re-configuring."
}

# check if service is already installed?
$serviceStatus = chef-service-manager -a status
IF ( $serviceStatus -eq "Service chef-client doesn't exist on the system." )
{
  chef-service-manager -a install -c $bootstrapDirectory\\client.rb -L $logFile
}

Write-ChefStatus "starting-chef-service" "transitioning" "Starting Chef Service"

# start the chef service
$result = chef-service-manager -a start

if ($result -match "Service 'chef-client' is now 'running'.")
{ Write-ChefStatus "chef-service-started" "success" "Chef Service started successfully"}
else
{ Write-ChefStatus "chef-service-start" "error" $result }

# Re-run chef-client with -j to set the runlist to the desired runlist
if ($firstRun)
{
    echo "Launching chef-client again to set the runlist"
    $chefClientProcess = start-process 'chef-client' -argumentlist @('-c', "$bootstrapDirectory\\client.rb","-j", "$bootstrapDirectory\first-boot.json", "-E", "_default", "-L", "$logFile") -verb 'runas' -passthru
    echo "Successfully launched process with PID $($chefClientProcess.Id) ."
}

echo "chef-enable.ps1 completed sucessfully"
