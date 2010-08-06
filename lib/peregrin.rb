module Peregrin

  VERSION = "1.0.0"

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

    # A string filename, should match one found in media.
    attr_accessor :cover

    # A proc that copies media to the given destination.
    attr_writer :media_copy_proc


    def initialize
      @components = []
      @contents = []
      @metadata = {}
      @media = []
    end


    def copy_media_to(media_path, dest_path)
      if @media_copy_proc
        @media_copy_proc.call(media_path, dest_path)
      end
    end


    def deep_clone
      @media_copy_proc ||= nil
      tmp = @media_copy_proc
      @media_copy_proc = nil
      clone = Marshal.load(Marshal.dump(self))
      clone.media_copy_proc = @media_copy_proc = tmp
      clone
    end

  end

end
