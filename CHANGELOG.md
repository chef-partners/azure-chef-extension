# azure-chef-extension Change Log

## Latest Release: 1210.14.1.0 (2021/09/01)
* [azure-chef-extension #353](https://github.com/chef-partners/azure-chef-extension/pull/353) Changing the default daemon setting to task for windows.
* [azure-chef-extension #357](https://github.com/chef-partners/azure-chef-extension/pull/357) Fix TLS for installs from Azure Blob Stores.
* [azure-chef-extension #358](https://github.com/chef-partners/azure-chef-extension/pull/358) Removing knife dependency from azure chef extension
* [azure-chef-extension #359](https://github.com/chef-partners/azure-chef-extension/pull/359) Unpinning Chef-Infra-Client-16 from azure-chef-extension.
* [azure-chef-extension #360](https://github.com/chef-partners/azure-chef-extension/pull/360) Unpinning chef-16 gem from gemspec file.

## Release: 1210.13.5.2 (2021/05/17)
* [azure-chef-extension #345](https://github.com/chef-partners/azure-chef-extension/pull/345) Pin to chef 16 until chef 17 is tested and verified in Azure.
* [azure-chef-extension #347](https://github.com/chef-partners/azure-chef-extension/pull/347) Pinned to chef-16 gem to fix rspec.
* [azure-chef-extension #344](https://github.com/chef-partners/azure-chef-extension/pull/344) Add MSI installer logging.

## Release: 1210.13.5.1 (2021/04/01)
* [azure-chef-extension #337](https://github.com/chef-partners/azure-chef-extension/pull/337) Fix for failing deployment of Azure Chef extension in Ubuntu 20.04.

## Release: 1210.13.4.3 (2021/03/16)
* [azure-chef-extension #339](https://github.com/chef-partners/azure-chef-extension/pull/339) Remove query params from chef_package_url.

## Release: 1210.13.4.2 (2021/02/02)
* [azure-chef-extension #333](https://github.com/chef-partners/azure-chef-extension/pull/333) Remove use of Get Win32_Product API Call.
* [azure-chef-extension #332](https://github.com/chef-partners/azure-chef-extension/pull/332) Fix for inconsistent behavior with System Path and error while running dameon as service.
* [azure-chef-extension #330](https://github.com/chef-partners/azure-chef-extension/pull/330) Improvement in code of chef-install.sh.

## Release: 1210.13.4.1 (2020/08/19)
* [azure-chef-extension #320](https://github.com/chef-partners/azure-chef-extension/pull/320) Fix python syntax error found while testing Redhat 8 for environment variable and Updated example of custom_json_attr.
* [azure-chef-extension #309](https://github.com/chef-partners/azure-chef-extension/pull/309) Unpin Chef 15 and pin to latest chef version.
* [azure-chef-extension #308](https://github.com/chef-partners/azure-chef-extension/pull/308) Add support for Chef Client 16.

## Release: 1210.13.3.3 (2020/07/30)
* [azure-chef-extension #304](https://github.com/chef-partners/azure-chef-extension/pull/304) Fix for #303: enable times out with chef_package_url param
* [azure-chef-extension #306](https://github.com/chef-partners/azure-chef-extension/pull/306) Fix for #305: Install fails on Linux when proxy does SSL int.

## Release: 1210.13.3.2 (2020/07/03)
* [azure-chef-extension #300](https://github.com/chef-partners/azure-chef-extension/pull/300) Added a new parameter called `chef_package_url` which specifies a url to download Chef Infra Client package (.msi .rpm .deb) and subsequently install.

## Release: 1210.13.3.1 (2020/06/04)
* [azure-chef-extension #293](https://github.com/chef-partners/azure-chef-extension/pull/293) Support azure chef extension to chef-15. For this added `CHEF_LICENSE` option 
which can be pass as [license acceptance](https://github.com/chef-partners/azure-chef-extension#arm-commands-for-azure-chef-extension)

## Release: 1210.13.2.3 (2020/02/13)
* [azure-chef-extension #287](https://github.com/chef-partners/azure-chef-extension/pull/287) Fix empty runlist issue while passing policy_name and policy_group.

## Release: 1210.13.2.2 (2019/11/26)
* [azure-chef-extension #284](https://github.com/chef-partners/azure-chef-extension/pull/284) Remove --no-ri and --no-rdoc options from chef-install.sh.
* [azure-chef-extension #281](https://github.com/chef-partners/azure-chef-extension/pull/281) Add compatible python path for Rhel8.
* [azure-chef-extension #279](https://github.com/chef-partners/azure-chef-extension/pull/279) Fix null-valued expression error.
* [azure-chef-extension #278](https://github.com/chef-partners/azure-chef-extension/pull/278) Set path in cron for chef client environment.

## Release: 1210.13.2.1 (2019/08/23)
* [azure-chef-extension #274](https://github.com/chef-partners/azure-chef-extension/pull/274) Added `chef_package_path` option to allow custom path of downloaded chef client.
* [azure-chef-extension #266](https://github.com/chef-partners/azure-chef-extension/pull/266) Fixes failing specs in recent merge which has wrong check of error code.

## Release: 1210.13.1.1 (2019/08/23)
* [azure-chef-extension #269](https://github.com/chef-partners/azure-chef-extension/pull/269) Pin to Chef 14 until Chef 15 is tested and verified on Azure later this year

## Release: 1210.13.1.0 (2019/02/05)
* [azure-chef-extension #261](https://github.com/chef-partners/azure-chef-extension/pull/261) Fixes the duplicate node_name in client.rb
* [azure-chef-extension #255](https://github.com/chef-partners/azure-chef-extension/pull/255) Fixes environment and run_list params not recognised.

## Release: 1210.12.110.1002 (2018/08/23)
* [azure-chef-extension #271](https://github.com/chef-partners/azure-chef-extension/pull/271) Pin to Chef 14 until Chef 15 is tested and verified on Azure later this year.

## Release: 1210.12.110.1001 (2018/04/30)
* [azure-chef-extension #245](https://github.com/chef-partners/azure-chef-extension/pull/245) Added `bootstrap_channel` option to install chef client version from `stable`, `current` or `unstable` channel.

## Release: 1210.12.110.1000 (2017/11/15)
* [azure-chef-extension #237](https://github.com/chef-partners/azure-chef-extension/pull/237) Updated document for extension sequencing in ARM template.
* [azure-chef-extension #236](https://github.com/chef-partners/azure-chef-extension/pull/236) Added support for Oracle Linux.
* [azure-chef-extension #234](https://github.com/chef-partners/azure-chef-extension/pull/234) Updated rake task to use azure-extension-cli to publish/unpublish extension in Public cloud
* [azure-chef-extension #229](https://github.com/chef-partners/azure-chef-extension/pull/229) Updated rake task to support publishing extension on Gov Cloud
* [azure-chef-extension #228](https://github.com/chef-partners/azure-chef-extension/pull/228) Removed backup logic and using n.settings file from C:/Chef during update to fix error coming while upgrading Chef extension version on Windows.

## Release: 1210.12.109.1005 (2017/07/03)
* [azure-chef-extension #217](https://github.com/chef-partners/azure-chef-extension/pull/217) Chef-service enable failed, make sure that Azure Chef extension start the chef-client service, If service StartMode is disabled.

## Release: 1210.12.109.1004 (2017/05/18)
* [azure-chef-extension #213](https://github.com/chef-partners/azure-chef-extension/pull/213) Fixed runlist conflicts with policy_name and policy_group settings in first-boot.json
* [azure-chef-extension #210](https://github.com/chef-partners/azure-chef-extension/pull/210) Update readme with microsoft image
* [azure-chef-extension #209](https://github.com/chef-partners/azure-chef-extension/pull/209) Added changes for spliting multiple certificates
* [azure-chef-extension #208](https://github.com/chef-partners/azure-chef-extension/pull/208) Fixing OpenSSL `header too long` issue.

## Release: 1210.12.109.1003 (2017/03/31)
* [azure-chef-extension #205](https://github.com/chef-partners/azure-chef-extension/pull/205) Fixed extension failure issue for Windows 8.

## Release: 1210.12.109.1002 (2017/03/28)
* [azure-chef-extension #203](https://github.com/chef-partners/azure-chef-extension/pull/203) Fixed nested backup issue.
* [azure-chef-extension #200](https://github.com/chef-partners/azure-chef-extension/pull/200) Fixed extension bad format issue.
* [azure-chef-extension #197](https://github.com/chef-partners/azure-chef-extension/pull/197) Optimized extension install and enable for windows.
* [azure-chef-extension #196](https://github.com/chef-partners/azure-chef-extension/pull/196) Renamed chef-service-interval option name to chef-daemon-interval.

## Release: 1210.12.109.1000 (2017/03/17)
* [azure-chef-extension #193](https://github.com/chef-partners/azure-chef-extension/pull/193) Added support for environment_variables in windows extension.

## Release: 1210.12.108.1000 (2017/02/17)
* [azure-chef-extension #188](https://github.com/chef-partners/azure-chef-extension/pull/188) Add support for chef-client scheduled task

## Release: 1210.12.106.1001 (2017/01/30)
* [azure-chef-extension #187](https://github.com/chef-partners/azure-chef-extension/pull/187) add python script to parse env variables

## Release: 1210.12.107.1001 (2017/01/03)
* [azure-chef-extension #185](https://github.com/chef-partners/azure-chef-extension/pull/185) Parsing json on Windows 2008

## Release: 1210.12.107.1000 (2016/12/26)
* [azure-chef-extension #178](https://github.com/chef-partners/azure-chef-extension/pull/178) Added -daemon option in chef-client service install
* [azure-chef-extension #181](https://github.com/chef-partners/azure-chef-extension/pull/181) Moving install steps to enable
* [azure-chef-extension #183](https://github.com/chef-partners/azure-chef-extension/pull/183) Skipping reading azure config json file for powershell V2.0
* [azure-chef-extension #184](https://github.com/chef-partners/azure-chef-extension/pull/184) Accepting daemon=none instead of auto

## Release: 1210.12.106.1000 (2016/10/19)
* [azure-chef-extension #161](https://github.com/chef-partners/azure-chef-extension/pull/161) Added code to read chef_service_interval from extension config file and process it.
* [azure-chef-extension #167](https://github.com/chef-partners/azure-chef-extension/pull/167) Adding support for setting custom json attributes in first_boot.json
* [azure-chef-extension #169](https://github.com/chef-partners/azure-chef-extension/pull/169) Fetching secret from protectedSettings instead of publicSettings
* [azure-chef-extension #172](https://github.com/chef-partners/azure-chef-extension/pull/172) Fixed bug to not generate empty encrypted_data_bag_secret file.


## Release: 1210.12.105.1001 (2016/08/10)
* [azure-chef-extension #157](https://github.com/chef-partners/azure-chef-extension/pull/157) Fix for validation.pem file not generating
* [azure-chef-extension #158](https://github.com/chef-partners/azure-chef-extension/pull/158) Pinned rack to fix travis failure


## Release: 1210.12.105.1000 (2016/06/27)
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
