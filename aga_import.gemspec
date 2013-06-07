# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "aga_import/version"

Gem::Specification.new do |s|

  s.name              = 'aga_import'
  s.version           = AgaImport::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['redfield', 'Tyralion']
  s.email             = ['info@dancingbytes.ru']
  s.homepage          = 'https://github.com/dancingbytes/aga_import'
  s.summary           = 'Import from 1c (xml) to mongodb.'
  s.description       = 'Import from 1c (xml) to mongodb.'

  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.extra_rdoc_files  = ['README.md']
  s.require_paths     = ['lib']

  s.licenses          = ['BSD']

  s.add_dependency 'rails', '~> 4.0.0.rc1'
  s.add_dependency 'nokogiri', '~> 1.5.0'
  s.add_dependency 'rubyzip'
  s.add_dependency 'logger'
  s.add_dependency 'listen'

end
