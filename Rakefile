require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "buscar"
    gem.summary = %Q{Searching, sorting, and pagination for Rails}
    gem.description = %Q{Simplifies searching, sorting, and pagination of ActiveRecord models. Includes a model class and a view helper.}
    gem.email = "jarrettcolby@gmail.com"
    gem.homepage = "http://github.com/jarrett/buscar"
    gem.authors = ["jarrett"]
    gem.add_dependency "activesupport", ">= 3.0.2"
    gem.add_dependency "activerecord", ">= 3.0.2"
    # Strictly speaking, you don't need ActionView to use the helpers. They rely on some methods ActionView provides,
    # but in principle, those methods could be defined by something other than ActionView. So, we make ActionView
    # (part of ActionPack) a development dependency for the sake of the specs.
    gem.add_development_dependency "actionpack", ">= 3.0.2"
    gem.add_development_dependency "rspec", ">= 2.1.0"
    gem.add_development_dependency "sqlite3-ruby", ">= 1.2.5"
    gem.add_development_dependency "machinist", ">= 1.0.6"
    gem.add_development_dependency "faker", ">= 0.3.1"
    gem.add_development_dependency "webrat", ">= 0.7.2"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "buscar #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
