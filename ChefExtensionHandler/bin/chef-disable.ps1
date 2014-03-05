
# Call chef service manager to stop the chef service
$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

# start the chef service
chef-service-manager -a stop