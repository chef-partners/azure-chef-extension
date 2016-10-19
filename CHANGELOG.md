# azure-chef-extension Change Log

## Latest Release: 1210.12.106.1000 (2016/10/19)
* [azure-chef-extension #161](https://github.com/chef-partners/azure-chef-extension/pull/161)Added code to read chef_service_interval from extension config file and process it.
* [azure-chef-extension #167](https://github.com/chef-partners/azure-chef-extension/pull/167)Adding support for setting custom json attributes in first_boot.json
* [azure-chef-extension #169](https://github.com/chef-partners/azure-chef-extension/pull/169)Fetching secret from protectedSettings instead of publicSettings
* [azure-chef-extension #172](https://github.com/chef-partners/azure-chef-extension/pull/172)Fixed bug to not generate empty encrypted_data_bag_secret file.


## Latest Release: 1210.12.105.1001 (2016/08/10)
* [azure-chef-extension #157](https://github.com/chef-partners/azure-chef-extension/pull/157) Fix for validation.pem file not generating
* [azure-chef-extension #158](https://github.com/chef-partners/azure-chef-extension/pull/158) Pinned rack to fix travis failure


## Latest Release: 1210.12.105.1000 (2016/06/27)
* [azure-chef-extension #149](https://github.com/chef-partners/azure-chef-extension/pull/149) Removed unrequired flags for Linux Platforms
* [azure-chef-extension #150](https://github.com/chef-partners/azure-chef-extension/pull/150) Removed unwanted flags for windows


## Release: 1210.12.104.1000 (2016/06/20)
* [azure-chef-extension #141](https://github.com/chef-partners/azure-chef-extension/pull/141) Added support to read environment variables from handler settings file
* [azure-chef-extension #143](https://github.com/chef-partners/azure-chef-extension/pull/143) Added retry logic for chef-client download issue on Windows platform.
* [azure-chef-extension #144](https://github.com/chef-partners/azure-chef-extension/pull/144) Added check for chef-client installation and to skip installation if exists


## Release: 1210.12.103.1000 (2016/05/24)
* [azure-chef-extension #127](https://github.com/chef-partners/azure-chef-extension/pull/127) Updated README for adding uninstallChefClient option
* [azure-chef-extension #133](https://github.com/chef-partners/azure-chef-extension/pull/133) Appending Environment path for ruby at the end
* [azure-chef-extension #128](https://github.com/chef-partners/azure-chef-extension/pull/128) Use opscode chef's install for chef installation
* [azure-chef-extension #122](https://github.com/chef-partners/azure-chef-extension/pull/122) Added code to write chef_client run logs in sub_status field of 0.status file
* [azure-chef-extension #135](https://github.com/chef-partners/azure-chef-extension/pull/135) Added support to read ohai_hints in extension
* [azure-chef-extension #136](https://github.com/chef-partners/azure-chef-extension/pull/136) Fixed bug when ohai_hints are not passed and modified RSpecs
* [azure-chef-extension #139](https://github.com/chef-partners/azure-chef-extension/pull/139) Used different way for downloading opscode install.ps1 file for windows


## Release: 1210.12.102.1000 (2016/03/28)
* [azure-chef-extension #115](https://github.com/chef-partners/azure-chef-extension/pull/115) Decrypting validation key if it's provided in Base64encoded format
* [azure-chef-extension #116](https://github.com/chef-partners/azure-chef-extension/pull/116) Added AzureChefExtension support for RHEL platform

## Release: 1210.12.101.1000 for Windows (2016/02/04) and 1210.12.101.1000 for Ubuntu (2016/02/12)
* [azure-chef-extension #104](https://github.com/chef-partners/azure-chef-extension/pull/104) Fixed pester specs
* [azure-chef-extension #103](https://github.com/chef-partners/azure-chef-extension/pull/103) Added uninstall_chef_client flag which determines whether to uninstall chef-client or not.
* [azure-chef-extension #107](https://github.com/chef-partners/azure-chef-extension/pull/107) Added code to delete node-registered file during update process as it was not allowing chef-client run during enable process after update.
* [azure-chef-extension #108](https://github.com/chef-partners/azure-chef-extension/pull/108) Installing chef from Omnitruck for ubuntu and centos
* [azure-chef-extension #109](https://github.com/chef-partners/azure-chef-extension/pull/109) Debian support in azure-chef-extension
* [azure-chef-extension #111](https://github.com/chef-partners/azure-chef-extension/pull/110) Modified parsing code which reads bootstrap_version and handled various cases like parsing the contents having new lines
* [azure-chef-extension #112](https://github.com/chef-partners/azure-chef-extension/pull/111) Modified sed command to read major version for centos plaform

## Release: 1210.12.100.1000 (2015/12/07)
* [azure-chef-extension #95](https://github.com/chef-partners/azure-chef-extension/pull/95) Tagging policy
* [azure-chef-extension #94](https://github.com/chef-partners/azure-chef-extension/pull/94) Functional RSpecs for ssl cert support under bootstrap protocol cloud-api
* [azure-chef-extension #99](https://github.com/chef-partners/azure-chef-extension/pull/99) Not removing chef-client on extension uninstall

## Release: 1210.12.100 (2015/11/19)
* [azure-chef-extension #80](https://github.com/chef-partners/azure-chef-extension/pull/80) Fix uninstall for deleteChefConfig flag
* [azure-chef-extension #86](https://github.com/chef-partners/azure-chef-extension/pull/86) Added code for Ubuntu and CentOS to accept version of Chef to download and install
* [azure-chef-extension #87](https://github.com/chef-partners/azure-chef-extension/pull/87) Passing bootstrap options to client.rb
* [azure-chef-extension #89](https://github.com/chef-partners/azure-chef-extension/pull/89) Moved call to function copy_settings_file after the bootstrap_directory is created
* [azure-chef-extension #90](https://github.com/chef-partners/azure-chef-extension/pull/90) Reduce time to install extension for ubuntu
* [azure-chef-extension #92](https://github.com/chef-partners/azure-chef-extension/pull/92) Implemented changes for Chef Extension usage examples
* [azure-chef-extension #91](https://github.com/chef-partners/azure-chef-extension/pull/91) Added SSL certificate bootstrap support in chef extension for cloud-api protocol

## Release: 1210.12.5.1000 (2015/10/27)
* [azure-chef-extension #71](https://github.com/chef-partners/azure-chef-extension/pull/71) Added chef.io url
* [azure-chef-extension #78](https://github.com/chef-partners/azure-chef-extension/pull/78) Readme update for centos support
* [azure-chef-extension #76](https://github.com/chef-partners/azure-chef-extension/pull/76) Decouple chef-client installation for windows - using omnitruck API
* [azure-chef-extension #79](https://github.com/chef-partners/azure-chef-extension/pull/79) Install chef via apt repo on ubuntu

## Release: 1210.12.4.1000 (2015/08/21)
* [azure-chef-extension #53](https://github.com/chef-partners/azure-chef-extension/pull/53) Fix for bootstrap_options Chef environment name setting
* [azure-chef-extension #52](https://github.com/chef-partners/azure-chef-extension/pull/52) Extension update happens for Linux even if AutoUpdateClient=false
* [azure-chef-extension #55](https://github.com/chef-partners/azure-chef-extension/pull/55) Updated version scheme for 1210.12.4.1000
* [azure-chef-extension #59](https://github.com/chef-partners/azure-chef-extension/pull/59) Update readme for unavailability of old extensions

## Release: 1210.12.4.1 (2015/07/22)
* [azure-chef-extension #25](https://github.com/chef-partners/azure-chef-extension/pull/25) Functional testcases for basic commands of azure chef extension
* [azure-chef-extension #39](https://github.com/chef-partners/azure-chef-extension/pull/39) Azure extension handler issue
* [azure-chef-extension #40](https://github.com/chef-partners/azure-chef-extension/pull/40) Fixed issue related to preserve runlist if first chef client run fails
* [azure-chef-extension #41](https://github.com/chef-partners/azure-chef-extension/pull/41) Functional testcase for disable command
* [azure-chef-extension #42](https://github.com/chef-partners/azure-chef-extension/pull/42) Implemented node verify cert bootstrap option
* [azure-chef-extension #46](https://github.com/chef-partners/azure-chef-extension/pull/46) Azure extension failing with timeout error
* [azure-chef-extension #43](https://github.com/chef-partners/azure-chef-extension/pull/43) Added support for validator less bootstrap
* [azure-chef-extension #48](https://github.com/chef-partners/azure-chef-extension/pull/48) Enable cmd fails when chef-client service is not already installed
* [azure-chef-extension #49](https://github.com/chef-partners/azure-chef-extension/pull/49) Fixed empty client_key/validation_key issue

## Release: 1207.12.3.0 (2015/05/15)
* [azure-chef-extension #36](https://github.com/chef-partners/azure-chef-extension/pull/36) Fixed escape runlist related issue
* [azure-chef-extension #31](https://github.com/chef-partners/azure-chef-extension/pull/31) Load azure attributes in hints file for ohai azure plugin

## Release: 1206.12.3.0 (2015/05/12)
* [azure-chef-extension #34](https://github.com/chef-partners/azure-chef-extension/pull/34) Fixed update extension process related issues
* [azure-chef-extension #33](https://github.com/chef-partners/azure-chef-extension/pull/33) Removed chef-client run with run_list part
* [azure-chef-extension #29](https://github.com/chef-partners/azure-chef-extension/pull/29) Updated README doc
* [azure-chef-extension #28](https://github.com/chef-partners/azure-chef-extension/pull/28) Implemented changes to append extension generated config to client_rb
* [azure-chef-extension #24](https://github.com/chef-partners/azure-chef-extension/pull/24) Fixed Azure chef extension uninstall should not delete c:\chef or /etc/chef by default
* [azure-chef-extension #22](https://github.com/chef-partners/azure-chef-extension/pull/22) Implemented changes to preserve runlist if first converge fails
* [azure-chef-extension #16](https://github.com/chef-partners/azure-chef-extension/pull/16) Testcases for azure-chef-extension
* [azure-chef-extension #23](https://github.com/chef-partners/azure-chef-extension/pull/23) Added log_level attribute and set it to info for detailed log
* [azure-chef-extension #21](https://github.com/chef-partners/azure-chef-extension/pull/21) Fix for providing multiple runlist item
* [azure-chef-extension #19](https://github.com/chef-partners/azure-chef-extension/pull/19) Updated Readme for using JSON object to pass options

## Previous  Release: 1205.12.2.1 (2014/04/01)

**See source control commit history for earlier changes.**
