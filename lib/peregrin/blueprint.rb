# Some ebook formats contain 'metadata' files that describe the contents of
# the ebook package. Since Peregrin use 'metadata' to refer to key-value pairs
# of information about the book, we call these files 'blueprints'.
#
class Peregrin::Blueprint < Peregrin::Resource

  attr_accessor(:rel, :contents)

  def initialize(rel, src, contents, media_type = 'application/xml', atts = {})
    @rel = rel
    @contents = contents
    super(src, media_type, atts)
  end


  def document
    raise "Not an XML document: #{src}"  unless xml?
    @document ||= Nokogiri::XML::Document.parse(contents)
  end


  def xml?
    media_type.match(/xml$/) ? true : false
  end


  def marshal_dump
    instance_variables.inject({}) { |acc, v|
      v.to_s == '@document' ? acc : acc.update(v => instance_variable_get(v))
    }
  end


  def marshal_load(h)
    h.each_pair { |k, v| instance_variable_set(k, v) }
  end

end
