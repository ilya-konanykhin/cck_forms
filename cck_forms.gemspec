$:.push File.expand_path('../lib', __FILE__)

require 'cck_forms/version'

Gem::Specification.new do |s|
  s.name        = 'cck_forms'
  s.version     = CckForms::VERSION
  s.authors     = ['Ilya Konanykhin']
  s.email       = ['ilya.konanykhin@gmail.com']
  s.homepage    = 'http://github.com/ilya-konanykhin/cck_forms'
  s.summary     = 'Content Construction Kit Forms'
  s.description = 'Custom field types for Mongoid objects'
  s.license     = 'MIT'

  s.files = Dir['{lib,vendor}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '4.0.0'
  s.add_dependency 'mongoid', '5.0.0'
  s.add_dependency 'neofiles', '1.0.0'
end
