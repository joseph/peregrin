# Any file that is a part of the book but not one of its linear sections (ie,
# Components) is a Resource.
#
# Resources can potentially be quite large, so as far as possible we don't
# store their contents in memory.
#
class Peregrin::Resource

  attr_accessor :src, :attributes
  attr_writer :media_type

  def initialize(src, media_type = nil, attributes = {})
    @src = src
    @media_type = media_type || MIME::Types.of(File.basename(@src))
    @media_type = @media_type.first  if @media_type.kind_of?(Array)
    @attributes = attributes
  end


  def media_type
    @media_type ? @media_type.to_s : nil
  end

end
