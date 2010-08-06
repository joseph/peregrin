require 'rake/gempackagetask'
require 'rake/testtask'

task :default => [:test]

desc "Run unit tests"
Rake::TestTask.new("test") { |t|
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
  t.warning = true
}

desc "Build the peregrin gem"
Rake::GemPackageTask.new(eval(File.read('peregrin.gemspec'))) { |g|
  g.need_zip = true
}
