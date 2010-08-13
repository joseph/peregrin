$:.unshift('lib') unless $:.include?('lib')

require 'peregrin'

spec = Gem::Specification.new do |s|
  s.name = 'peregrin'
  s.version = Peregrin::VERSION
  s.summary = "Peregrin - ebook conversion"
  s.description = "Peregrin converts EPUBs, Zhooks and Ochooks."
  s.author = "Joseph Pearson"
  s.email = "joseph@inventivelabs.com.au"
  s.homepage = "http://inventivelabs.com.au"
  s.files = Dir['*.txt'] +
    Dir['bin/*'] +
    Dir['lib/**/*.rb'] +
    Dir['test/**/*.rb']
  s.executables = ["peregrin"]
  s.require_path = 'lib'
  s.has_rdoc = true
  #s.extra_rdoc_files = ['HISTORY', 'COPYING']
  s.rdoc_options += [
    '--title', 'Peregrin',
    '--main', 'README.md'
  ]
  s.add_dependency('nokogiri')
  s.add_dependency('rubyzip')
end
