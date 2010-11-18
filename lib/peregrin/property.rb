# Books have metadata. Each unit of metadata (each metadatum?) is a 'property'
# of the book.
#
# A property has a key, a value and an optional set of attributes.
#
class Peregrin::Property

  attr_accessor :key, :value, :attributes

  def initialize(key, value, attributes = {})
    @key = key
    @value = value
    @attributes = attributes
  end

end
