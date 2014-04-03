
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'

PACKAGE_NAME = "ChefExtensionHandler"
VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"

task :build, [:chef_version, :machine_os, :machine_arch] => [:clean] do |t, args|
  args.with_defaults(:chef_version => nil, :machine_os => "2008r2", :machine_arch => "x86_64")
  puts "Building Chef Package..."
  puts %x{powershell -executionpolicy unrestricted "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME} #{args.machine_os} #{args.machine_arch} #{args.chef_version}"}
end

task :clean do
  puts %x{ powershell -executionpolicy unrestricted -Command if (Test-Path "#{CHEF_BUILD_DIR}") { Remove-Item -Recurse -Force "#{CHEF_BUILD_DIR}"}}
end