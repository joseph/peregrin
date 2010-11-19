# A component is a section of the book's linear text.
#
class Peregrin::Component < Peregrin::Resource

  attr_accessor :contents

  def initialize(src, contents = nil, media_type = nil, attributes = {})
    @contents = contents
    super(src, media_type, attributes)
  end

end
