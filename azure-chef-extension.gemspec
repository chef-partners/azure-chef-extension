# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "azure-chef-extension/version"

Gem::Specification.new do |s|
  s.name        = "azure-chef-extension"
  s.version     = ChefAzure::VERSION
  s.platform    = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.md", "LICENSE" ]
  s.authors     = ["Kaustubh Deorukhkar"]
  s.email       = ["contact@clogeny.com"]
  s.homepage    = "https://github.com/opscode/azure-chef-extension"
  s.summary     = %q{azure-chef-extension}
  s.description = s.summary

  s.files         = `git ls-files | grep -v ChefExtensionHandler | grep -v scripts`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib", "spec"]

  s.add_development_dependency "chef", '<= 16.13.16'
  s.add_development_dependency 'rubyzip', '>= 1.0.0'
  s.add_development_dependency 'nokogiri'

  %w(rspec-core rspec-expectations rspec-mocks rspec_junit_formatter).each { |gem| s.add_development_dependency gem }
end
