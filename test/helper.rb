require 'rubygems' # Rake should be doing this. But not for me. Weird.
require 'test/unit'
require 'peregrin'

module Peregrin::Tests

end



class Test::Unit::TestCase

  def whitewash(str)
    str.gsub(/\s+/, '')
  end

end
