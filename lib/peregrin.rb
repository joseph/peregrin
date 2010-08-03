module Peregrin

  # Required gems
  require 'zip/zip'  # Name of gem is "rubyzip"
  require 'zip/zipfilesystem'
  require 'nokogiri'

  # Utility libs
  require 'utils/componentizer'
  require 'utils/outliner'

  # Format classes
  require 'formats/zhook'
  require 'formats/ochook'
  require 'formats/epub'


  class Book

    # An array of hashes:
    #   [
    #     uri => string-contents-of-component,
    #     ...
    #   ]
    attr_accessor :components

    # A hash hierarchy:
    #   [
    #     {
    #       :title => ...,
    #       :src => ...,
    #       :children => [
    #       ]
    #     }
    #   ]
    attr_accessor :contents

    # A simple hash:
    #   name => value
    attr_accessor :metadata


    # An array of filenames.
    attr_accessor :media


    def initialize
      @components = []
      @contents = []
      @metadata = {}
      @media = []
    end

  end

end
