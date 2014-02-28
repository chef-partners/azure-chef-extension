

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

$bootstrapDirectory="C:\\chef"

# check if service is already installed?
$serviceStatus = chef-service-manager -a status
IF ( $serviceStatus -eq "Service chef-client doesn't exist on the system." )
{
  chef-service-manager -a install -c $bootstrapDirectory\client.rb -L $bootstrapDirectory\logs
}

# start the chef service
chef-service-manager -a start