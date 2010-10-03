class Peregrin::Book

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
  attr_writer :read_media_proc


  def initialize
    @components = []
    @contents = []
    @metadata = {}
    @media = []
  end


  def read_media(media_path)
    @read_media_proc.call(media_path)  if @read_media_proc
  end


  def copy_media_to(media_path, dest_path)
    File.open(dest_path, 'w') { |f|
      f << read_media(media_path)
    }
  end


  def deep_clone
    @read_media_proc ||= nil
    tmp = @read_media_proc
    @read_media_proc = nil
    clone = Marshal.load(Marshal.dump(self))
    clone.read_media_proc = @read_media_proc = tmp
    clone
  end

end
