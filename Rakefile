
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'
require 'uri'
require 'net/http'
require 'json'
require 'zip'
require 'date'
require 'nokogiri'
require 'mixlib/shellout'
require './lib/chef/azure/helpers/erb.rb'

PACKAGE_NAME = "ChefExtensionHandler"
MANIFEST_NAME = "publishDefinitionXml"
EXTENSION_VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"
PESTER_VER_TAG = "2.0.4" # we lock down to specific tag version
PESTER_GIT_URL = 'https://github.com/pester/Pester.git'
PESTER_SANDBOX = './PESTER_SANDBOX'

GOV_REGIONS = ["USGov Iowa", "USGov Arizona", "USGov Texas", "USGov Virginia"]

# Array of hashes {src : dest} for files to be packaged
LINUX_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.sh" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.sh" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.py" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
  {"*.gem" => "#{CHEF_BUILD_DIR}/gems"},
  {"ChefExtensionHandler/HandlerManifest.json.nix" => "#{CHEF_BUILD_DIR}/HandlerManifest.json"}
]

WINDOWS_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.cmd" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.bat" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.ps1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.psm1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
  {"*.gem" => "#{CHEF_BUILD_DIR}/gems"},
  {"ChefExtensionHandler/HandlerManifest.json" => "#{CHEF_BUILD_DIR}/HandlerManifest.json"}
]

PREVIEW = "deploy_to_preview"
PRODUCTION = "deploy_to_production"
GOV = "deploy_to_gov"
DELETE_FROM_PREVIEW = "delete_from_preview"
DELETE_FROM_PRODUCTION = "delete_from_production"
DELETE_FROM_GOV = "delete_from_gov"
CONFIRM_PUBLIC = "confirm_public_deployment"
CONFIRM_INTERNAL = "confirm_internal_deployment"
DEPLOY_INTERNAL = "deploy_to_internal"
DEPLOY_PUBLIC = "deploy_to_public"

# Helpers
def windows?
  if RUBY_PLATFORM =~ /mswin|mingw|windows/
    true
  else
    false
  end
end

def error_and_exit!(message)
  puts "\nERROR: #{message}\n"
  exit
end

def confirm!(type)
  print "Do you wish to proceed? (y/n)"
  proceed = STDIN.gets.chomp() == 'y'
  if not proceed
    puts "Exiting #{type} request."
    exit
  end
end

def assert_publish_env_vars
  [{"publishsettings" => "Publish settings file for Azure."}].each do |var|
    if ENV[var.keys.first].nil?
      error_and_exit! "Please set the environment variable - \"#{var.keys.first}\" for [#{var.values.first}]"
    end
  end
end

def assert_environment_vars
  env_vars = {
    "azure_extension_cli" => "Path of azure-extension-cli binary. Download it from https://github.com/Azure/azure-extensions-cli/releases",
    "SUBSCRIPTION_ID" => "Subscription ID of the GOV Account from where extension is to be published.",
    "SUBSCRIPTION_CERT" => "Path to the Management Certificate",
    "MANAGEMENT_URL" => "Management URL for Public/Gov Cloud (e.g. https://management.core.windows.net/)",
    "EXTENSION_NAMESPACE" => "Publisher namespace (Chef.Bootstrap.WindowsAzure)"
  }

  env_vars.each do |var, desc|
    error_and_exit! "Please set the environment variable - \"#{var}\" for [#{desc}]" unless ENV[var]
  end
end

# sets the common environment varaibles for Chef Extension
def set_env_vars(deploy_type, subscription_id)
  env_vars = {
    "SUBSCRIPTION_ID" => subscription_id,
    "MANAGEMENT_URL" => get_mgmt_uri(deploy_type),
    "EXTENSION_NAMESPACE" => "Chef.Bootstrap.WindowsAzure"
  }

  env_vars.each do |var, value|
    ENV[var] = value
  end
end

def assert_gov_regions(args)
  (error_and_exit! "Invalid Region. Valid regions for GOV Cloud are: #{GOV_REGIONS}" unless GOV_REGIONS.include? args.region) if args.region
  (error_and_exit! "Invalid Region. Valid regions for GOV Cloud are: #{GOV_REGIONS}" unless GOV_REGIONS.include? args.region1) if args.region1
  (error_and_exit! "Invalid Region. Valid regions for GOV Cloud are: #{GOV_REGIONS}" unless GOV_REGIONS.include? args.region2) if args.region2
end

def assert_deploy_params(deploy_type, internal_or_public)
  assert_publish_env_vars

  error_and_exit! "deploy_type parameter value should be \"#{PREVIEW}\" or \"#{PRODUCTION}\" or \"#{GOV}\"" unless (deploy_type == PREVIEW or deploy_type == PRODUCTION or deploy_type == GOV)

  error_and_exit! "internal_or_public parameter value should be \"#{CONFIRM_INTERNAL}\" or \"#{CONFIRM_PUBLIC}\"" unless (internal_or_public == CONFIRM_INTERNAL or internal_or_public == CONFIRM_PUBLIC)
end

def assert_publish_params(deploy_type, internal_or_public, operation)
  assert_deploy_params(deploy_type, internal_or_public)

  error_and_exit! "operation parameter should be \"new\" or \"update\"" unless (operation == "new" or operation == "update")
end

def assert_delete_params(type, chef_deploy_namespace, full_extension_version)
  assert_publish_env_vars

  error_and_exit! "deploy_type parameter value should be \"#{DELETE_FROM_PREVIEW}\" or \"#{DELETE_FROM_PRODUCTION}\" or \"#{DELETE_FROM_GOV}\"" unless (type == DELETE_FROM_PREVIEW or type == DELETE_FROM_PRODUCTION or type == DELETE_FROM_GOV)

  error_and_exit! "chef_deploy_namespace must be specified." if chef_deploy_namespace.nil?

  error_and_exit! "full_extension_version must be specified." if full_extension_version.nil?
end

def assert_update_params(definition_xml)
  assert_publish_env_vars
  error_and_exit! "definition_xml param must point to definitionXml file." if definition_xml.nil?
end

def assert_git_state
  is_crlf = %x{git config --global core.autocrlf}
  error_and_exit! "Please set the git crlf setting and clone, so git does not auto convert newlines to crlf. [ex: git config --global core.autocrlf false]" if is_crlf.chomp != "false"
end

def load_publish_settings
  doc = Nokogiri::XML(File.open(ENV["publishsettings"]))
  subscription_id =  doc.at_css("Subscription").attribute("Id").value
  subscription_name =  doc.at_css("Subscription").attribute("Name").value
  [subscription_id, subscription_name]
end

def load_publish_properties(target_type)
  publish_options = JSON.parse(File.read("Publish.json"))

  definitionParams = publish_options[target_type]["definitionParams"]
  storageAccount = definitionParams["storageAccount"]
  storageContainer = definitionParams["storageContainer"]
  extensionName = definitionParams["extensionName"]
  [storageAccount, storageContainer, extensionName]
end

def get_mgmt_uri(deploy_type)
  case deploy_type
  when /(^#{PRODUCTION}$|^#{DELETE_FROM_PRODUCTION}$)/
    "https://management.core.windows.net/"
  when /(^#{GOV}$|^#{DELETE_FROM_GOV}$)/
    "https://management.core.usgovcloudapi.net/"
  when /(^#{PREVIEW}$|^#{DELETE_FROM_PREVIEW}$)/
    "https://management-preview.core.windows-int.net/"
  end
end

def get_publish_uri(deploy_type, subscriptionid, operation)
  uri = get_mgmt_uri(deploy_type) + "#{subscriptionid}/services/extensions"
  uri = uri + "?action=update" if operation == "update"
  uri
end

def get_extension_pkg_name(args, date_tag = nil)
  if date_tag.nil?
    "#{PACKAGE_NAME}_#{args.extension_version}_#{Date.today.strftime("%Y%m%d")}_#{args.target_type}.zip"
  else
    "#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip"
  end
end

# Updates IsInternal as False for public release and True for internal release
def update_definition_xml(xml, args)
  doc = Nokogiri::XML(File.open(xml))
  internal = doc.at_css("IsInternalExtension")
  internal.content = is_internal?(args)
  File.write(xml, doc.to_xml)
end

def get_definition_xml_name(args)
  "#{MANIFEST_NAME}_#{args.target_type}_#{args.build_date_yyyymmdd}"
end

def get_definition_xml(args, date_tag = nil)
  storageAccount, storageContainer, extensionName = load_publish_properties(args.target_type)

  extensionZipPackage = get_extension_pkg_name(args, date_tag)

  chef_url = 'http://www.chef.io/about'
  supported_os = args.target_type == 'windows' ? 'windows' : 'linux'
  storage_base_url = args.deploy_type == GOV ? 'core.usgovcloudapi.net' : 'core.windows.net'

  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} new-extension-manifest --package #{extensionZipPackage} --storage-account #{storageAccount} --namespace #{args.chef_deploy_namespace} --name #{extensionName} --version #{args.extension_version} --label 'Chef Extension for #{args.target_type}' --description 'Chef Extension that sets up chef-client on VM' --eula-url #{chef_url} --privacy-url #{chef_url} --homepage-url #{chef_url} --company 'Chef Software, Inc.' --supported-os #{supported_os} --storage-base-url #{storage_base_url}")
    result = cli_cmd.run_command
    result.error!
    definitionXml = result.stdout
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} new-extension-manifest`: #{e}"
    exit
  end

  definitionXml
end

def is_internal?(args)
  is_internal = if args.internal_or_public == CONFIRM_INTERNAL
    true
  elsif args.internal_or_public == CONFIRM_PUBLIC
    false
  end
end

desc "Builds a azure chef extension gem."
task :gem => [:clean] do
  puts "Building gem file..."
  puts %x{gem build *.gemspec}
end

desc "Builds the azure chef extension package Ex: build[platform, extension_version], default is build[windows]."
task :build, [:target_type, :extension_version, :confirmation_required] => [:gem] do |t, args|
  args.with_defaults(:target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :confirmation_required => "true")
  puts "Build called with args(#{args.target_type}, #{args.extension_version})"

  assert_git_state

  # Get user confirmation if we are downloading correct version.
  if args.confirmation_required == "true"
    confirm!("build")
  end

  puts "Building #{args.target_type} package..."
  # setup the sandbox
  FileUtils.mkdir_p CHEF_BUILD_DIR
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/bin"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/gems"

  # Copy platform specific files to package dir
  puts "Copying #{args.target_type} scripts to package directory..."
  package_list = if args.target_type == "windows"
    WINDOWS_PACKAGE_LIST
  else
    LINUX_PACKAGE_LIST
  end

  package_list.each do |rule|
    src = rule.keys.first
    dest = rule[src]
    puts "Copy: src [#{src}] => dest [#{dest}]"
    if File.directory?(dest)
      FileUtils.cp_r Dir.glob(src), dest
    else
      FileUtils.cp Dir.glob(src).first, dest
    end
  end

  date_tag = Date.today.strftime("%Y%m%d")

  # Write a release tag file to zip. This will help during testing
  # to check if package was synced in PIR.
  FileUtils.touch "#{CHEF_BUILD_DIR}/version_#{args.extension_version}_#{date_tag}_#{args.target_type}"

  puts "\nCreating a zip package..."
  puts "#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip\n\n"

  Zip::File.open("#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip", Zip::File::CREATE) do |zipfile|
    Dir[File.join("#{CHEF_BUILD_DIR}/", '**', '**')].each do |file|
      zipfile.add(file.sub("#{CHEF_BUILD_DIR}/", ''), file)
    end
  end
end


desc "Cleans up the package sandbox"
task :clean do
  puts "Cleaning Chef Package..."
  FileUtils.rm_f(Dir.glob("*.zip"))
  puts "Deleting #{CHEF_BUILD_DIR} and #{PESTER_SANDBOX}"
  FileUtils.rm_rf(Dir.glob("#{CHEF_BUILD_DIR}"))
  FileUtils.rm_rf(Dir.glob("#{PESTER_SANDBOX}"))
  puts "Deleting gem file..."
  FileUtils.rm_f(Dir.glob("*.gem"))
  FileUtils.rm_f(Dir.glob("publishDefinitionXml_*"))
end

desc "Publishes the azure chef extension package using publish.json Ex: publish[deploy_type, platform, extension_version], default is build[preview,windows]."
task :publish, [:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required] => [:build] do |t, args|

  args.with_defaults(
    :deploy_type => PREVIEW,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :chef_deploy_namespace => "Chef.Bootstrap.WindowsAzure.Test",
    :operation => "new",
    :internal_or_public => CONFIRM_INTERNAL,
    :confirmation_required => "true")

  puts "**Publish called with args:\n#{args}\n\n"

  assert_publish_params(args.deploy_type, args.internal_or_public, args.operation)

  subscription_id, subscription_name = load_publish_settings

  set_env_vars(args.deploy_type, subscription_id)
  assert_environment_vars

  publish_uri = get_publish_uri(args.deploy_type, subscription_id, args.operation)

  definitionXml = get_definition_xml(args)

    puts <<-CONFIRMATION

*****************************************
This task creates a chef extension package and publishes to Azure #{args.deploy_type}.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Subscription Name:  #{subscription_name}
    Extension Version:  #{args.extension_version}
    Publish Uri:  #{publish_uri}
    Build branch:  #{%x{git rev-parse --abbrev-ref HEAD}}
    Type:  #{is_internal?(args) ? "Internal build" : "Public release"}
****************************************
CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  if args.confirmation_required == "true"
    confirm!("publish")
  end

  puts "Continuing with publish request..."

  date_tag = Date.today.strftime("%Y%m%d")
  manifestFile = File.new("#{MANIFEST_NAME}_#{args.target_type}_#{date_tag}", "w")
  definitionXmlFile = manifestFile.path
  puts "Writing publishDefinitionXml to #{definitionXmlFile}..."
  puts "[[\n#{definitionXml}\n]]"
  manifestFile.write(definitionXml)
  manifestFile.close

  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} new-extension-version --manifest #{definitionXmlFile}")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully published internally."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} new-extension-version`: #{e}"
    exit
  end
end

desc "Promotes the extension in single region for GOV Cloud"
task :promote_single_region, [:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :region, :confirmation_required] do |t, args|
  args.with_defaults(
    :deploy_type => PRODUCTION,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :build_date_yyyymmdd => nil,
    :region => "USGov Virginia",
    :confirmation_required => "true")

  puts "**Promote_single_region called with args:\n#{args}\n\n"

  assert_publish_env_vars
  subscription_id, subscription_name = load_publish_settings
  set_env_vars(args.deploy_type, subscription_id)
  # assert build date since we form the build tag
  error_and_exit! "Please specify the :build_date_yyyymmdd param used to identify the published build" if args.build_date_yyyymmdd.nil?
  assert_environment_vars
  assert_gov_regions(args) if args.deploy_type == GOV
  definitionXmlFile = get_definition_xml_name(args)

  puts <<-CONFIRMATION

*****************************************
This task promotes the chef extension package to '#{args.region}' region.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Subscription Name:  #{subscription_name}
    Extension Version:  #{args.extension_version}
    Build Date: #{args.build_date_yyyymmdd}
    Region:  #{args.region}
****************************************
CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  if args.confirmation_required == "true"
    confirm!("update")
  end

  puts "Promoting the extension to #{args.region}..."

  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} promote-single-region --manifest #{definitionXmlFile} --region-1 '#{args.region}'")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully published in #{args.region}."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} promote-single-region`: #{e}"
    exit
  end
end

desc "Promotes the extension in two regions for GOV Cloud"
task :promote_two_regions, [:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :region1, :region2, :confirmation_required] do |t, args|
  args.with_defaults(
    :deploy_type => PRODUCTION,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :build_date_yyyymmdd => nil,
    :region1 => "USGov Virginia",
    :region2 => "USGov Iowa",
    :confirmation_required => "true")

  puts "**Promote_two_regions called with args:\n#{args}\n\n"

  assert_publish_env_vars
  subscription_id, subscription_name = load_publish_settings
  set_env_vars(args.deploy_type, subscription_id)
  # assert build date since we form the build tag
  error_and_exit! "Please specify the :build_date_yyyymmdd param used to identify the published build" if args.build_date_yyyymmdd.nil?
  assert_environment_vars
  assert_gov_regions(args) if args.deploy_type == GOV
  definitionXmlFile = get_definition_xml_name(args)

  puts <<-CONFIRMATION

*****************************************
This task promotes the chef extension package to '#{args.region1}' and '#{args.region2}' regions.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Subscription Name:  #{subscription_name}
    Extension Version:  #{args.extension_version}
    Build Date: #{args.build_date_yyyymmdd}
    Region1:  #{args.region1}
    Region2:  #{args.region2}
****************************************
CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  if args.confirmation_required == "true"
    confirm!("update")
  end

  puts "Promoting the extension to #{args.region1} and #{args.region2}..."

  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} promote-two-regions --manifest #{definitionXmlFile} --region-1 '#{args.region1}' --region-2 '#{args.region2}'")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully published in #{args.region1} and #{args.region2}."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} promote-two-regions`: #{e}"
    exit
  end
end

desc "Unpublishes the azure chef extension package which was publised in some Regions."
task :unpublish_version, [:deploy_type, :target_type, :full_extension_version, :confirmation_required] do |t, args|

  args.with_defaults(
    :deploy_type => DELETE_FROM_PRODUCTION,
    :target_type => "windows",
    :full_extension_version => nil,
    :confirmation_required => "true")

  puts "**unpublish_version called with args:\n#{args}\n\n"

  assert_publish_env_vars
  error_and_exit! "This task is supported on for deploy_types: \"#{DELETE_FROM_GOV}\" and \"#{DELETE_FROM_PRODUCTION}\"" unless (args.deploy_type == DELETE_FROM_GOV || args.deploy_type == DELETE_FROM_PRODUCTION)
  subscription_id, subscription_name = load_publish_settings
  set_env_vars(args.deploy_type, subscription_id)
  assert_environment_vars

  publish_options = JSON.parse(File.read("Publish.json"))
  extensionName = publish_options[args.target_type]["definitionParams"]["extensionName"]

  # Get user confirmation, since we are deleting from Azure.
  puts <<-CONFIRMATION

*****************************************
This task unpublishes a published chef extension package from Azure #{args.deploy_type}.
  Details:
  -------
    Delete from:  ** #{args.deploy_type.gsub(/delete_from_/, "")} **
    Subscription Name:  #{subscription_name}
    Publisher Name:     #{ENV['EXTENSION_NAMESPACE']}
    Extension Name:     #{extensionName}
****************************************
CONFIRMATION

  if args.confirmation_required == "true"
    confirm!("delete")
  end

  puts "Continuing with unpublish request..."
  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} unpublish-version --name #{extensionName} --version #{args.full_extension_version}")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully unpublished."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} unpublish-version`: #{e}"
    exit
  end
end

desc "Deletes the azure chef extension package which was publised as internal Ex: publish[deploy_type, platform, extension_version], default is build[preview,windows]."
task :delete, [:deploy_type, :target_type, :chef_deploy_namespace, :full_extension_version, :confirmation_required] do |t, args|

  args.with_defaults(
    :deploy_type => DELETE_FROM_PREVIEW,
    :target_type => "windows",
    :chef_deploy_namespace => nil,
    :full_extension_version => nil,
    :confirmation_required => "true")

  puts "**Delete called with args:\n#{args}\n\n"

  assert_delete_params(args.deploy_type, args.chef_deploy_namespace, args.full_extension_version)

  subscription_id, subscription_name = load_publish_settings

  publish_options = JSON.parse(File.read("Publish.json"))
  extensionName = publish_options[args.target_type]["definitionParams"]["extensionName"]

  # Get user confirmation, since we are deleting from Azure.
  puts <<-CONFIRMATION

*****************************************
This task deletes a published chef extension package from Azure #{args.deploy_type}.
  Details:
  -------
    Delete from:  ** #{args.deploy_type.gsub(/delete_from_/, "")} **
    Subscription Name:  #{subscription_name}
    Publisher Name:     #{args.chef_deploy_namespace}
    Extension Name:     #{extensionName}
****************************************
CONFIRMATION

  if args.confirmation_required == "true"
    confirm!("delete")
  end

  puts "Continuing with delete request..."

  set_env_vars(args.deploy_type, subscription_id)
  assert_environment_vars
  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} delete-version --name #{extensionName} --version #{args.full_extension_version}")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully deleted."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} delete-version`: #{e}"
    exit
  end
end

desc "Updates the azure chef extension package metadata which was publised Ex: update[\"definitionxml.xml\"]."
task :update, [:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :chef_deploy_namespace, :internal_or_public, :confirmation_required] do |t, args|

  args.with_defaults(
    :deploy_type => PREVIEW,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :build_date_yyyymmdd => nil,
    :chef_deploy_namespace => "Chef.Bootstrap.WindowsAzure.Test",
    :internal_or_public => CONFIRM_INTERNAL,
    :confirmation_required => "true")

  puts "**Update called with args:\n#{args}\n\n"

  assert_deploy_params(args.deploy_type, args.internal_or_public)

  # assert build date since we form the build tag
  error_and_exit! "Please specify the :build_date_yyyymmdd param used to identify the published build" if args.build_date_yyyymmdd.nil?

  definitionXmlFile = get_definition_xml_name(args)
  update_definition_xml(definitionXmlFile, args) # Updates IsInternal as False for public release and True for internal release

  subscription_id, subscription_name = load_publish_settings

  publish_uri = get_publish_uri(args.deploy_type, subscription_id, "update")

  puts <<-CONFIRMATION

*****************************************
This task updates the chef extension package which is already published to Azure #{args.deploy_type}.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Subscription Name:  #{subscription_name}
    Extension Version:  #{args.extension_version}
    Build Date: #{args.build_date_yyyymmdd}
    Publish Uri:  #{publish_uri}
    Type:  #{is_internal?(args) ? "Internal build" : "Public release"}
****************************************
CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  if args.confirmation_required == "true"
    confirm!("update")
  end

  puts "Continuing with udpate request..."

  set_env_vars(args.deploy_type, subscription_id)
  assert_environment_vars

  begin
    cli_cmd = Mixlib::ShellOut.new("#{ENV['azure_extension_cli']} promote-all-regions --manifest #{definitionXmlFile}")
    result = cli_cmd.run_command
    result.error!
    puts "The extension has been successfully published externally."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "Failure while running `#{ENV['azure_extension_cli']} promote-all-regions`: #{e}"
    exit
  end
end

task :init_pester do
  puts "Initializing Pester to run powershell unit tests..."
  puts %x{powershell -Command if (Test-Path "#{PESTER_SANDBOX}") {Remove-Item -Recurse -Force #{PESTER_SANDBOX}"}}
  puts %x{powershell "mkdir #{PESTER_SANDBOX}; cd #{PESTER_SANDBOX}; git clone --branch #{PESTER_VER_TAG} \'#{PESTER_GIT_URL}\'"; cd ..}
end

# Its runs pester unit tests
# have a winspec task that can be used to trigger tests in jenkins
desc "Runs pester unit tests ex: rake spec[\"spec\\ps_specs\\sample.Tests.ps1\"]"
task :winspec, [:spec_path] => [:init_pester] do |t, args|
  puts "\nRunning unit tests for powershell scripts..."
  # Default: runs all tests under spec dir,
  # user can specify individual test file
  # Ex: rake spec["spec\ps_specs\sample.Tests.ps1"]
  args.with_defaults(:spec_path => "spec/ps_specs")

  # run pester tests
  puts %x{powershell -ExecutionPolicy Unrestricted Import-Module #{PESTER_SANDBOX}/Pester/Pester.psm1; Invoke-Pester -relative_path #{args.spec_path}}
end

# rspec
begin
  require 'rspec/core/rake_task'
  desc "Run all specs in spec directory"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = ["--format", "documentation"]
    t.pattern = 'spec/**/**/*_spec.rb'
  end
rescue LoadError
  STDERR.puts "\n*** RSpec not available. (sudo) gem install rspec to run unit tests. ***\n\n"
end
