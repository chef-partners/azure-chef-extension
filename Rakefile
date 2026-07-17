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

LINUX_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.sh" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.sh" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.py" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/HandlerManifest.json.nix" => "#{CHEF_BUILD_DIR}/HandlerManifest.json"}
]

WINDOWS_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.cmd" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.bat" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.ps1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.psm1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
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

desc "Cleans up the package sandbox"
task :clean do
  puts "Cleaning Chef Package..."
  FileUtils.rm_f(Dir.glob("*.zip"))
  puts "Deleting #{CHEF_BUILD_DIR}"
  FileUtils.rm_rf(Dir.glob("#{CHEF_BUILD_DIR}"))
  puts "Deleting gem file..."
  FileUtils.rm_f(Dir.glob("*.gem"))
  FileUtils.rm_f(Dir.glob("publish-template.json"))
end

desc "Builds a azure chef extension gem."
  task :gem => [:clean] do
    puts "Building gem file..."
    puts %x{gem build *.gemspec}
end

desc "Builds the azure chef extension package Ex: build[platform, extension_version], default is build[windows]."
task :build, [:target_type, :extension_version, :confirmation_required] => [:gem] do |t, args|
  args.with_defaults(:target_type => "windows",
  :extension_version => "1216.16.6.1",
  :confirmation_required => "false")
  puts "Build called with args(#{args.target_type}, #{args.extension_version})"

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

  Zip::File.open("#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip", create: true) do |zipfile|
    Dir[File.join("#{CHEF_BUILD_DIR}/", '**', '**')].each do |file|
      zipfile.add(file.sub("#{CHEF_BUILD_DIR}/", ''), file)
    end
  end
end

def is_internal?(args)
  is_internal = if args.internal_or_public == CONFIRM_INTERNAL
    true
  elsif args.internal_or_public == CONFIRM_PUBLIC
    false
  end
end

def confirm!(type)
  print "Do you wish to proceed? (y/n)"
  proceed = STDIN.gets.chomp() == 'y'
  if not proceed
    puts "Exiting #{type} request."
    exit
  end
end

desc "List extension versions"
task :list_versions do
  resource_type = "Microsoft.Compute/sharedVMExtensions/versions"
  system("az resource list --resource-type #{resource_type}")
end

desc "Publishes the azure chef extension package using publish.json Ex: publish[deploy_type, platform, extension_version], default is build[preview,windows]."
task :publish, [:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required, :extension_name_override, :resource_group, :storage_account, :storage_container] => [:build] do |t, args|

  args.with_defaults(
    :deploy_type => PREVIEW,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :chef_deploy_namespace => "Chef.Bootstrap.WindowsAzure.Test",
    :operation => "new",
    :internal_or_public => CONFIRM_INTERNAL,
    :confirmation_required => "true",
    :extension_name_override => "",
    :resource_group => "",
    :storage_account => "azurechefextensions",
    :storage_container => "published-packages"
    )

  storageAccount=args.storage_account
  storageContainer=args.storage_container

  puts "**Publish called with args:\n#{args}\n\n"
  puts "Continuing with publish request..."

  puts <<-CONFIRMATION

*****************************************
This task creates a chef extension package and publishes to Azure #{args.deploy_type}.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Extension Version:  #{args.extension_version}
    Build branch:  #{%x{git rev-parse --abbrev-ref HEAD}}
    Type:  #{is_internal?(args) ? "Internal build" : "Public release"}
****************************************
CONFIRMATION

  if args.confirmation_required == 'true'
    confirm!("publish")
  end

  date_tag = Date.today.strftime("%Y%m%d")
  package="#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip"

  puts "Creating template file"

  data=File.read(__dir__+"/publish-template-default.json")
  data_hash=JSON.parse(data)
  default_type_name = args.target_type=='windows' ? 'ChefClient' : 'LinuxChefClient'
  data_hash['variables']['typeName'] = args.extension_name_override.to_s.empty? ? default_type_name : args.extension_name_override
  data_hash['variables']['supportedOS'] = args.target_type=='windows' ? 'Windows' : 'Linux'
  if args.internal_or_public == CONFIRM_PUBLIC
    data_hash['variables']['isInternalExtension']= 'false'
  else
    data_hash['variables']['isInternalExtension']= 'true'
  end
  data_hash['variables']['version']=args.extension_version
  data_hash['variables']['regions']=["*"]
  if args.deploy_type == GOV
    data_hash['variables']['mediaLink']="https://#{storageAccount}.blob.core.usgovcloudapi.net/#{storageContainer}/#{package}"
    #https://azurechefextensions.blob.core.usgovcloudapi.net/published-packages/ChefExtensionHandler_1216.16.6.6_20220421_ubuntu.zip
  else
    data_hash['variables']['mediaLink']="https://#{storageAccount}.blob.core.windows.net/#{storageContainer}/#{package}"
  end
    # https://extpublish.blob.core.windows.net/extension/ChefExtensionHandler
  # puts(data_hash)
  File.write(__dir__+"/publish-template.json", JSON.dump(data_hash))
  puts "Deploying package to storage account"
  upload_to_storage(package,storageAccount,storageContainer)

  # CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  puts ("Deploying the template please confirm if you would like to continue")
  if args.confirmation_required == "true"
    confirm!("publish")
  end
  deploy_template(args)
end

# ponytail: minimal .env parser (KEY="VALUE" per line, # comments) so the
# adhoc publish task doesn't need a dotenv gem for a handful of variables.
def load_dotenv(path)
  return {} unless File.exist?(path)

  File.readlines(path).each_with_object({}) do |line, vars|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    next unless key && value

    value = value.strip
    # Quoted values may have a trailing "# comment" after the closing quote;
    # unquoted values are terminated by the first unescaped "#".
    if value =~ /\A"([^"]*)"/ || value =~ /\A'([^']*)'/
      value = $1
    else
      value = value.split("#", 2).first.to_s.strip
    end
    vars[key.strip] = value
  end
end

def prompt(label, default: nil)
  suffix = default && !default.to_s.empty? ? " [#{default}]" : ""
  print "#{label}#{suffix}: "
  answer = STDIN.gets.to_s.strip
  answer.empty? ? default.to_s : answer
end

# Adhoc/test-only helper: the production storage account is not reachable from
# personal Azure subscriptions, so create a scratch account/container for the
# adhoc publish task if one doesn't already exist in the target resource group.
def ensure_storage_account!(account, container, resource_group)
  puts "\nChecking storage account '#{account}' in resource group '#{resource_group}'..."
  exists = system("az storage account show --name #{account} --resource-group #{resource_group} -o none 2>/dev/null")
  unless exists
    puts "Storage account '#{account}' not found, creating it..."
    location = %x{az group show --name #{resource_group} --query location -o tsv}.strip
    location = "eastus" if location.empty?
    system("az storage account create --name #{account} --resource-group #{resource_group} --location #{location} --sku Standard_LRS") or
      abort("Unable to create storage account '#{account}'")
  end

  container_exists = system("az storage container show --account-name #{account} --name #{container} -o none 2>/dev/null")
  unless container_exists
    puts "Container '#{container}' not found, creating it..."
    system("az storage container create --account-name #{account} --name #{container}") or
      abort("Unable to create container '#{container}'")
  end
end

namespace :testing do
  desc "Adhoc test publish: logs in with .env creds and publishes under an alternate name. Prompts for all fields interactively."
  task :publish_adhoc do
    dotenv = load_dotenv(File.join(__dir__, ".env"))

    puts <<-BANNER

*****************************************
Adhoc test publish (modeled on `make publish.internally`)
Uses .env for Azure login instead of vault, and always publishes
under an alternate extension name so it can't collide with the real
published extension.
*****************************************
BANNER

    cloud = prompt("Azure cloud (public/government)", default: "public")
    deploy_type = cloud.strip.downcase.start_with?("gov") ? GOV : PRODUCTION

    tenant = dotenv["AZURE_TENANT"]
    subscription = dotenv["AZURE_SUBSCRIPTION"]
    use_device_code = dotenv["AZURE_USE_DEVICE_CODE"].to_s.downcase == "true"

    puts "\nLogging in to Azure (from .env: tenant=#{tenant || "(none)"}, subscription=#{subscription || "(none)"})..."
    system("az cloud set --name #{deploy_type == GOV ? "AzureUSGovernment" : "AzureCloud"}")
    login_cmd = ["az", "login"]
    login_cmd += ["--tenant", tenant] if tenant
    login_cmd << "--use-device-code" if use_device_code
    system(*login_cmd) or abort("az login failed")
    if subscription
      system("az", "account", "set", "--subscription", subscription) or
        abort("Unable to select Azure subscription '#{subscription}'")
    end
    system("az account show")

    platform = prompt("Platform (windows/linux)", default: "windows")
    extension_version = prompt("Extension version", default: File.exist?("VERSION") ? File.read("VERSION").strip : EXTENSION_VERSION)
    chef_deploy_namespace = prompt("Chef deploy namespace", default: "Chef.Bootstrap.WindowsAzure")
    default_override = "#{ENV["USER"] || "adhoc"}-adhoc-test-#{Date.today.strftime("%Y%m%d")}"
    extension_name_override = prompt("Alternate extension name (typeName override, required)", default: default_override)
    resource_group = prompt("Resource group to deploy the extension version into", default: dotenv["RESOURCE_GROUP"] || default_resource_group(platform))
    location = dotenv["LOCATION"] || "eastus"
    puts "\nEnsuring resource group '#{resource_group}' exists in '#{location}' (mirrors testing/test-azure-extension.sh)..."
    system("az group create --name #{resource_group} --location #{location} --output none") or
      abort("Unable to create/verify resource group '#{resource_group}'")

    default_storage_account = (dotenv["STORAGE_ACCOUNT"] || "#{ENV["USER"] || "adhoc"}adhocteststorage").downcase.gsub(/[^a-z0-9]/, "")[0, 24]
    storage_account = prompt("Storage account for the uploaded package (created if missing)", default: default_storage_account)
    storage_container = prompt("Storage container for the uploaded package (created if missing)", default: dotenv["STORAGE_CONTAINER"] || "published-packages")
    ensure_storage_account!(storage_account, storage_container, resource_group)

    Rake::Task[:publish].invoke(
      deploy_type,
      platform,
      extension_version,
      chef_deploy_namespace,
      "update",
      CONFIRM_INTERNAL,
      "true",
      extension_name_override,
      resource_group,
      storage_account,
      storage_container
    )
  end
end

desc "Publishes the azure chef extension package using publish.json Ex: publish[deploy_type, platform, extension_version], default is build[preview,windows]."
task :promote_regions, [:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required, :region1, :region2, :extension_name_override, :resource_group, :storage_account, :storage_container] => [:build] do |t, args|

  args.with_defaults(
    :deploy_type => PREVIEW,
    :target_type => "windows",
    :extension_version => EXTENSION_VERSION,
    :chef_deploy_namespace => "Chef.Bootstrap.WindowsAzure.Test",
    :operation => "new",
    :internal_or_public => CONFIRM_INTERNAL,
    :confirmation_required => "true",
    :region1 => "East US",
    :extension_name_override => "",
    :resource_group => "",
    :storage_account => "azurechefextensions",
    :storage_container => "published-packages"
    )

  storageAccount=args.storage_account
  storageContainer=args.storage_container

  puts "**Publish called with args:\n#{args}\n\n"
  puts "Continuing with publish request..."

  puts <<-CONFIRMATION

*****************************************
This task creates a chef extension package and publishes to Azure #{args.deploy_type}.
  Details:
  -------
    Publish To:  ** #{args.deploy_type.gsub(/deploy_to_/, "")} **
    Extension Version:  #{args.extension_version}
    Build branch:  #{%x{git rev-parse --abbrev-ref HEAD}}
    Type:  #{is_internal?(args) ? "Internal build" : "Public release"}
****************************************
CONFIRMATION

  if args.confirmation_required == 'true'
    confirm!("publish")
  end

  date_tag = Date.today.strftime("%Y%m%d")
  package="#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip"

  puts "Creating template file"

  data=File.read(__dir__+"/publish-template-default.json")
  data_hash=JSON.parse(data)
  default_type_name = args.target_type=='windows' ? 'ChefClient' : 'LinuxChefClient'
  data_hash['variables']['typeName'] = args.extension_name_override.to_s.empty? ? default_type_name : args.extension_name_override
  data_hash['variables']['supportedOS'] = args.target_type=='windows' ? 'Windows' : 'Linux'
  if args.internal_or_public == CONFIRM_PUBLIC
    data_hash['variables']['isInternalExtension']= 'false'
  else
    data_hash['variables']['isInternalExtension']= 'true'
  end
  data_hash['variables']['version']=args.extension_version
  if args.region2 == nil
    data_hash['variables']['regions']=["#{args.region1}"]
  else
   data_hash['variables']['regions']=args.region1,args.region2
  end
  if args.deploy_type == GOV
    data_hash['variables']['mediaLink']="https://#{storageAccount}.blob.core.usgovcloudapi.net/#{storageContainer}/#{package}"
    #https://azurechefextensions.blob.core.usgovcloudapi.net/published-packages/ChefExtensionHandler_1216.16.6.6_20220421_ubuntu.zip
  else
    data_hash['variables']['mediaLink']="https://#{storageAccount}.blob.core.windows.net/#{storageContainer}/#{package}"
  end
  #puts(data_hash)
  File.write(__dir__+"/publish-template.json", JSON.dump(data_hash))
  puts "Deploying package to storage account"
  upload_to_storage(package,storageAccount,storageContainer)

  # CONFIRMATION
  # Get user confirmation, since we are publishing a new build to Azure.
  puts ("Deploying the template please confirm if you would like to continue")
  if args.confirmation_required == "true"
    confirm!("publish")
  end
  deploy_template(args)
end

def deploy_template(args)
  template=__dir__+"/publish-template.json"
  group_name = "ExtensionPublishing"
  resgrp = args.resource_group.to_s.empty? ? default_resource_group(args.target_type) : args.resource_group
  os_label = args.target_type == "windows" ? "windows" : "linux"
  begin
    cli_cmd = Mixlib::ShellOut.new("az deployment group create --name #{group_name} --resource-group #{resgrp} --template-file #{template}")
    result = cli_cmd.run_command
    result.error!
    puts "The #{os_label} extension has been successfully published."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "The #{os_label} extension publishing failed while deploying #{template} to resource group '#{resgrp}':"
    puts e.message
    puts result.stdout unless result.nil? || result.stdout.to_s.empty?
    puts result.stderr unless result.nil? || result.stderr.to_s.empty?
    raise
  end
end

def default_resource_group(target_type)
  target_type == "windows" ? "azure-chef-extension-window" : "azure-chef-extension-linux"
end

def upload_to_storage(package,storageAccount,storageContainer)
  begin
    cli_cmd = Mixlib::ShellOut.new("az storage blob upload --account-name #{storageAccount} --container-name #{storageContainer} --name #{package} --file #{package} --overwrite")
    result = cli_cmd.run_command
    result.error!
    puts "The #{package} has been succesfully uploaded to storage account #{storageAccount} in #{storageContainer} container."
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    puts "The upload has failed for #{package} to storage account #{storageAccount} in #{storageContainer} container:"
    puts e.message
    puts result.stdout unless result.nil? || result.stdout.to_s.empty?
    puts result.stderr unless result.nil? || result.stderr.to_s.empty?
    raise
  end
end
