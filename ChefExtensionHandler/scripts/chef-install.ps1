<#
Author:: Mukta Aphale (mukta.aphale@clogeny.com)
Copyright:: Copyright (c) 2014 Opscode, Inc.

// install chef-client with /i switch
// Actions: (do what windows bootstrap template)
//    - install chef-client
//    - create client.rb, validation.pem
//    - run chef-client
//      (run will need to pick up runlist from handlerSettings)

//    - may start additional service or modified chef-service that is capable of
//      - read HandlerEnvironment.json from root folder and pass info like log location to chef-client run
//      - read <SequenceNumber>.settings to read settings like runlist passed by user
//        (SequenceNumber: is it specified in HandlerEnvironment.json? docs says but not in sample)
//      - reporting chef-client run status to status file to be read guest agent: “<SequenceNumber>.status”
//        (is SequenceNumber per new version of handler deployed to VM? 
//        do we need to purge older sequencenumber.status files, say maintain max of 10 recent files?)
//      - reporting heartbeat i.e. this service is ready/notready with more info to heartbeat file
//      - service should manage file read/write conflicts with Guest Agent.

#>

$BOOTSTRAP_DIRECTORY="C:\chef"
echo "Checking for existing directory $BOOTSTRAP_DIRECTORY"
if ( !(Test-Path $BOOTSTRAP_DIRECTORY) ) {
echo "Existing directory not found, creating."
mkdir $BOOTSTRAP_DIRECTORY
} else {
echo "Existing directory found, skipping creation."
}

# TODO: Set MACHINE and MACHINE_ARCH dynamically
$MACHINE="2012"
$MACHINE_ARCH="x86_64"
$REMOTE_SOURCE_MSI_URL="https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/chef-client-11.10.4-1.windows.msi"
# TODO: Set the following paths dynamically
$LOCAL_DESTINATION_MSI_PATH="C:\Users\azure\AppData\Local\Temp\chef-client-latest.msi"
$CHEF_CLIENT_MSI_LOG_PATH="C:\Users\azure\AppData\Local\Temp\chef-client-msi806.log"

echo "Checking for existing downloaded package at $LOCAL_DESTINATION_MSI_PATH"
if (Test-Path $LOCAL_DESTINATION_MSI_PATH) {
  echo "Found existing downloaded package, deleting."
  rm -rf $LOCAL_DESTINATION_MSI_PATH
  # Handle above delete failure
}

if (Test-Path $CHEF_CLIENT_MSI_LOG_PATH) {
  rm -rf $CHEF_CLIENT_MSI_LOG_PATH
}

$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($REMOTE_SOURCE_MSI_URL, $LOCAL_DESTINATION_MSI_PATH)
# Handle download failure

echo "Installing chef"
msiexec /qn /log $CHEF_CLIENT_MSI_LOG_PATH /i $LOCAL_DESTINATION_MSI_PATH

# Write validation key
echo "-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAxwWuU8H7u361HlE4RfAFaOpQDvp3A5EvXbu/R6gvsBiJgLVJ
uiGdswKouyMUJX0LGLdHpdnShCsTR2tQd8ILwy5F31NpjhtflPMx7oqt9zrSyY/D
KqNTmXLlLOoOuDgzXXxse/qtI3AAKXYbWcxTC6o6XK/nrKxxOeK6v/BgVp0nCLNw
kh0j68uXz9JidqmuD+42oYv+ArdricGvJ5tHxrjWmRVL5S96UW4YDZGgElEp1wvI
cfItooC7QOwy+lh2cpYkrxSVssSQyx2UEaYVzPeuh/ieMtES0q04al40ObhnhnRJ
b/rxaLTqSj7HybldEpChKrVQj307huxNwUoSwQIDAQABAoIBADZQIZPwA1/Wo1zj
s2S6rO9FypVb2vDZRUDiRMAscN8www2h673lAKFin2N6njvg1Q9orR/gwueYzckW
yz3zcbxRO3ZH0C2c4MfIWp8Lr5AhuHaTSiKvsdfVmB9avKufgr0HgJ+Q+IEMRq8J
8UrfTOaJDSZQRvxDjx7J9kb9NX1NKAH4swA5o5DOu6Pi63O7EtUnLce8gk3R4etJ
V9fcKYh5umYfZujK/LtpxqrXQRUE6q1zQQvPCo1HGCHM6Cvlio5R6N4td/WU0MFJ
InGEzUTOIqoqbRzf2cVaDdMOwnj6mteTHtdzohdW7a9iQYYk3Eg0MPp0Wc4VhVUY
T3CeyHECgYEA+rE4q3UWabU0fVz9i+PBfjvuhh/p5lb8JeQiO6M8yt/YVcLAPSg9
c6lyQvrvkeIVQZ78dY2JroyI02YBl1dkQjdD1E4qll8xlmkJUCV4k9sj8dHuD0uT
/iWcaqEs6DlVMI2+h1Oclrn/WjzXCVD8khtSJSyWk/+hoc2JLlp5cW0CgYEAyzxm
/ScJZIoe3LDF4CPwnAlGK8M6hKaBHo3NGH5XzDvA193SN0HdF4a5zVz6tySgKhXS
kckcW1q1K2N34mCkjmjrERi5s3pEZ89HnMIXkVoNr70VD3qKhdZG9tmow/fXWBc9
2L8xsBQFZ2z6fTW6zBEoy+kz/RiXdiGuhPjwpiUCgYEA2J0RTnWZrDU66afUHW/q
3VyDubkRrkozDbqWKdneyZ2pnFDvMuj2UF51sJKLNw6XN2Bc3GY0NXKRN7jIXzDQ
HLcMEQKJoe0XN9QCjBIUog2UfXrbrLOtaMiu4yPpXa9MgOu5Wc1RXJvSnPI9DHvC
Aa1ByYVBhxg3XUvv4PGkRfECgYEAuqhUModK0iMk6y4T3qNDlhvSbdkVgsVl60jz
KF7JhlMO73PUYVnFlJjxRxLxVYl27JA0YB7kQ2cQ47OsZKa8G+tykbYywAs4jltK
e0er25xo25H+qMO0O+2sKYWIwct75XUbIVmgagZJXE8z1BGn6UqNPJKHZBnU6fNP
VONKKl0CgYEAnKpVLMKm3WDW6c4Un0kGONFSIEx9fpGx67gFcSfCICpiip9Tc4oC
Ob6kpa+odBPUKG8ufm/dIE//BMiZXeb4B5HAHHegJbGUE7LROarE8u8wFsB5Nbt4
HzvvPMxrgt7MOIGbTdoHclPo8+V0Yonh4EBid9wdV12iSc0rG6LT8nA=
-----END RSA PRIVATE KEY-----" | Out-File C:\chef\validation.pem

echo "Validation key written"

# Write client.rb
echo 'log_level        :info
log_location     STDOUT

chef_server_url  "https://api.opscode.com/organizations/mukta_training"
validation_client_name "mukta_training-validator"
client_key        "c:/chef/client.pem"
validation_key    "c:/chef/validation.pem"

file_cache_path   "c:/chef/cache"
file_backup_path  "c:/chef/backup"
cache_options     ({:path => "c:/chef/cache/checksums", :skip_expires => true})

node_name "i-41938e61"' | Out-File C:\chef\client.rb

echo "Client.rb written"

# json
echo '"run_list":["git::default"]' | Out-File C:\chef\first-boot.json
echo "first-boot.json written"

# set path
$PATH="$PATH;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files\Amazon\cfn-bootstrap\;C:\ruby\bin;C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"
echo "PATH set = $PATH"

# run chef-client
echo "Running chef client"
chef-client -c c:/chef/client.rb -j c:/chef/first-boot.json -E _default