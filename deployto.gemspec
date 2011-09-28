$:.unshift File.expand_path("../lib", __FILE__)
require "deploytool/version"

Gem::Specification.new do |gem|
  gem.name    = "deployto"
  gem.version = DeployTool::VERSION

  gem.author      = "Efficient Cloud Ltd"
  gem.email       = "hello@platformdirectory.com"
  gem.homepage    = "http://platformdirectory.com/"
  gem.summary     = "Multi-platform deployment tool."
  gem.description = "Deployment tool with support for multiple Platform-as-a-Service providers."
  gem.executables = "deploy"

  gem.files = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }
  
  gem.add_dependency "inifile",        ">= 0.4.1"
  gem.add_dependency "addressable"
  gem.add_dependency "multipart-post"
  gem.add_dependency "highline",       ">= 1.6.2"
  gem.add_dependency "zip"
  gem.add_dependency "json_pure"
  gem.add_dependency "oauth2"
end
