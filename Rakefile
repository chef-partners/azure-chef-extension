
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
require './lib/chef/azure/helpers/erb.rb'

PACKAGE_NAME = "ChefExtensionHandler"
EXTENSION_VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"
PESTER_VER_TAG = "2.0.4" # we lock down to specific tag version
PESTER_GIT_URL = 'https://github.com/pester/Pester.git'
PESTER_SANDBOX = './PESTER_SANDBOX'

# Array of hashes {src : dest} for files to be packaged
LINUX_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.sh" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.sh" => "#{CHEF_BUILD_DIR}/bin"},
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
DELETE_FROM_PREVIEW = "delete_from_preview"
DELETE_FROM_PRODUCTION = "delete_from_production"
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

def download_chef(download_url, target)
  puts "Downloading from url [#{download_url}]"
  uri = URI(download_url)
  Net::HTTP.start(uri.host) do |http|
    begin
        file = open(target, 'wb')
        http.request_get(uri.request_uri) do |response|
          case response
          when Net::HTTPSuccess then
            file = open(target, 'wb')
            response.read_body do |segment|
              file.write(segment)
            end
          when Net::HTTPRedirection then
            location = response['location']
            puts "WARNING: Redirected to #{location}"
            download_chef(location, target)
          else
            puts "ERROR: Download failed. Http response code: #{response.code}"
          end
        end
    ensure
      file.close if file
    end
  end
end

def load_build_environment(platform, version)
  if platform == "windows"
    url = URI.parse('http://opscode.com/chef/metadata?v=' + version + "&prerelease=false&nightlies=false&p=windows&pv=7&m=x86_64")
  elsif platform == "ubuntu"
    url = URI.parse('http://opscode.com/chef/metadata?v=' + version + '&prerelease=false&nightlies=false&p=ubuntu&pv=14.04&m=x86_64')
  elsif platform == "centos"
    url = URI.parse('http://opscode.com/chef/metadata?v=' + version + '&prerelease=false&nightlies=false&p=centos&pv=7&m=x86_64')
  end
  request = Net::HTTP::Get.new(url.to_s)
  response = Net::HTTP.start(url.host, url.port) {|http|
    http.request(request)
  }
  if response.kind_of? Net::HTTPOK
    download_url = response.body.split(' ')[1]
    download_url
  else
    error_and_exit! "ERROR: Invalid chef-client version"
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
    puts "Exitting #{type} request."
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

def assert_deploy_params(deploy_type, internal_or_public)
  assert_publish_env_vars

  error_and_exit! "deploy_type parameter value should be \"#{PREVIEW}\" or \"#{PRODUCTION}\"" unless (deploy_type == PREVIEW or deploy_type == PRODUCTION)

  error_and_exit! "internal_or_public parameter value should be \"#{CONFIRM_INTERNAL}\" or \"#{CONFIRM_PUBLIC}\"" unless (internal_or_public == CONFIRM_INTERNAL or internal_or_public == CONFIRM_PUBLIC)
end

def assert_publish_params(deploy_type, internal_or_public, operation)
  assert_deploy_params(deploy_type, internal_or_public)

  error_and_exit! "operation parameter should be \"new\" or \"update\"" unless (operation == "new" or operation == "update")
end

def assert_delete_params(type, chef_deploy_namespace, full_extension_version)
  assert_publish_env_vars

  error_and_exit! "deploy_type parameter value should be \"#{DELETE_FROM_PREVIEW}\" or \"#{DELETE_FROM_PRODUCTION}\"" unless (type == DELETE_FROM_PREVIEW or type == DELETE_FROM_PRODUCTION)

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

def get_definition_xml(args, date_tag = nil)
  storageAccount, storageContainer, extensionName = load_publish_properties(args.target_type)

  extensionZipPackage = get_extension_pkg_name(args, date_tag)

  # Process the erb
  definitionXml = ERBHelpers::ERBCompiler.run(
      File.read("build/templates/definition.xml.erb"),
      {:chef_namespace => args.chef_deploy_namespace,
      :extension_name => extensionName,
      :extension_version => args.extension_version,
      :target_type => args.target_type,
      :package_storage_account => storageAccount,
      :package_container =>  storageContainer,
      :package_name => extensionZipPackage,
      :is_internal => is_internal?(args)
    })

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

  download_url = load_build_environment(args.target_type,args.extension_version)
  unless download_url.nil?
    puts <<-CONFIRMATION

    **********************************************
    Downloading specific chef-client version using
    #{download_url}.
    Please confirm the correct chef-client version in url.
    **********************************************
    CONFIRMATION

  # Get user confirmation if we are downloading correct version.
  if args.confirmation_required == "true"
    confirm!("build")
  end

  puts "Building #{args.target_type} package..."
  # setup the sandbox
  FileUtils.mkdir_p CHEF_BUILD_DIR
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/bin"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/gems"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/installer"

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

  puts "\nDownloading chef installer..."
  target_chef_pkg = case args.target_type
                    when "ubuntu"
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.deb"
                    when "centos"
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.rpm"
                    else
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.msi"
                    end

  date_tag = Date.today.strftime("%Y%m%d")

  # Write a release tag file to zip. This will help during testing
  # to check if package was synced in PIR.
  FileUtils.touch "#{CHEF_BUILD_DIR}/version_#{args.extension_version}_#{date_tag}_#{args.target_type}"

  download_chef(download_url, target_chef_pkg)

  puts "\nCreating a zip package..."
  puts "#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip\n\n"

  Zip::File.open("#{PACKAGE_NAME}_#{args.extension_version}_#{date_tag}_#{args.target_type}.zip", Zip::File::CREATE) do |zipfile|
    Dir[File.join("#{CHEF_BUILD_DIR}/", '**', '**')].each do |file|
      zipfile.add(file.sub("#{CHEF_BUILD_DIR}/", ''), file)
    end
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

  tempFile = Tempfile.new("publishDefinitionXml")
  definitionXmlFile = tempFile.path
  puts "Writing publishDefinitionXml to #{definitionXmlFile}..."
  puts "[[\n#{definitionXml}\n]]"
  tempFile.write(definitionXml)
  tempFile.close

  # Upload the generated package to Azure storage as a blob.
  puts "\n\nUploading zip package..."
  puts "------------------------"
  storageAccount, storageContainer, extensionName = load_publish_properties(args.target_type)
  extensionZipPackage = get_extension_pkg_name(args)

  system("powershell -nologo -noprofile -executionpolicy unrestricted Import-Module .\\scripts\\uploadpkg.psm1;Upload-ChefPkgToAzure #{ENV["publishsettings"]} #{storageAccount} #{storageContainer} #{extensionZipPackage}")

  # Publish the uploaded package to PIR using azure cmdlets.
  puts "\n\nPublishing the package..."
  puts "-------------------------"
  postOrPut = if args.operation == "new"
      "POST"
    elsif args.operation == "update"
      "PUT"
    end

  system("powershell -nologo -noprofile -executionpolicy unrestricted Import-Module .\\scripts\\publishpkg.psm1;Publish-ChefPkg #{ENV["publishsettings"]} \"\'#{subscription_name}\'\" #{publish_uri} #{definitionXmlFile} #{postOrPut}")

  tempFile.unlink
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

  delete_uri = get_mgmt_uri(args.deploy_type) + "#{subscription_id}/services/extensions/#{args.chef_deploy_namespace}/#{extensionName}/#{args.full_extension_version}"

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
    Delete Uri:  #{delete_uri}
****************************************
CONFIRMATION

  if args.confirmation_required == "true"
    confirm!("delete")
  end

  puts "Continuing with delete request..."

  system("powershell -nologo -noprofile -executionpolicy unrestricted Import-Module .\\scripts\\deletepkg.psm1;Delete-ChefPkg #{ENV["publishsettings"]} \"\'#{subscription_name}\'\" #{delete_uri}")
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

  definitionXml = get_definition_xml(args, args.build_date_yyyymmdd)

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

  tempFile = Tempfile.new("updateDefinitionXml")
  definitionXmlFile = tempFile.path
  puts "Writing updateDefinitionXml to #{definitionXmlFile}..."
  puts "[[\n#{definitionXml}\n]]"
  tempFile.write(definitionXml)
  tempFile.close

  system("powershell -nologo -noprofile -executionpolicy unrestricted Import-Module .\\scripts\\publishpkg.psm1;Publish-ChefPkg #{ENV["publishsettings"]} \"\'#{subscription_name}\'\" #{publish_uri} #{definitionXmlFile} PUT")

  tempFile.unlink
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
    t.rspec_opts = ["--format", "nested"]
    t.pattern = 'spec/unit/**/*_spec.rb'
  end
rescue LoadError
  STDERR.puts "\n*** RSpec not available. (sudo) gem install rspec to run unit tests. ***\n\n"
end