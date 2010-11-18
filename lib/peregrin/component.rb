# A component is a section of the book's linear text.
#
class Peregrin::Component

  attr_accessor :src, :contents, :media_type, :attributes

  def initialize(src, contents = nil, media_type = nil, attributes = {})
    @src = src
    @contents = contents
    @media_type = media_type || MIME::Types.of(File.basename(@src))
    @attributes = attributes
  end

end
