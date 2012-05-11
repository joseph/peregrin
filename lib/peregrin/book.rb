class Peregrin::Book

  # Unique identifier for this book
  attr_accessor :identifier

  # An array of Components
  attr_accessor :components

  # A tree of Chapters. Top-level chapters in this array, each with
  # children arrays.
  attr_accessor :chapters

  # An array of Properties.
  attr_accessor :properties

  # An array of Resources.
  attr_accessor :resources

  # A Resource that is used for the book cover.
  attr_accessor :cover

  # The current version of document specifications
  # Only used for Epub for now
  attr_accessor :version

  # A proc that copies a resource to the given destination.
  attr_writer :read_resource_proc


  def initialize
    @components = []
    @chapters = []
    @properties = []
    @resources = []
  end


  def all_files
    @components + @resources
  end


  def add_component(*args)
    @components.push(Peregrin::Component.new(*args)).last
  end


  def add_resource(*args)
    @resources.push(Peregrin::Resource.new(*args)).last
  end


  def add_chapter(*args)
    @chapters.push(Peregrin::Chapter.new(*args)).last
  end


  def add_property(*args)
    @properties.push(Peregrin::Property.new(*args)).last
  end


  def property_for(key)
    key = key.to_s
    prop = @properties.detect { |p| p.key == key }
    prop ? prop.value : nil
  end


  def read_resource(resource_path)
    @read_resource_proc.call(resource_path)  if @read_resource_proc
  end


  def copy_resource_to(resource_path, dest_path)
    File.open(dest_path, 'w') { |f|
      f << read_resource(resource_path)
    }
  end


  def deep_clone
    @read_resource_proc ||= nil
    tmp = @read_resource_proc
    @read_resource_proc = nil
    clone = Marshal.load(Marshal.dump(self))
    clone.read_resource_proc = @read_resource_proc = tmp
    clone
  end

end
