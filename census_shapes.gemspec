# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "census_shapes/version"
require "census_shapes"

Gem::Specification.new do |s|
  s.name        = "census_shapes"
  s.version     = CensusShapes::VERSION
  s.authors     = ["Ty Rauber"]
  s.email       = ["tyrauber@mac.com"]
  s.homepage    = "https://github.com/tyrauber/census_shapes"
  s.summary     = "A Ruby Gem for importing US Census Shapes into PostGIS"
  s.description = "Imports all the US Census Geographies into a PostGIS database."

  s.rubyforge_project = "census_shapes"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  
  s.add_dependency "rspec"
  s.add_dependency "pg"
  s.add_dependency "postgis_adapter"
  s.add_dependency "progress_bar"
  s.add_dependency "generator_spec"
end
