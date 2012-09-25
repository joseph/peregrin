class Peregrin::Book

  # Unique identifier for this book
  attr_accessor :identifier

  # An array of Components
  attr_accessor :components

  # A tree of Chapters. Top-level chapters in this array, each with
  # children arrays.
  attr_accessor :chapters

  # An array of Properties containg the ebook-supplied metadata.
  attr_accessor :properties

  # An array of Properties relating to the format of the ebook.
  attr_accessor :format_properties

  # An array of Resources.
  attr_accessor :resources

  # An array of Blueprints (ie, metadata files like the OPF or NCX).
  attr_accessor :blueprints

  # A Resource that is used for the book cover.
  attr_accessor :cover

  # A proc that copies a resource to the given destination.
  attr_writer :read_resource_proc


  def initialize
    @components = []
    @chapters = []
    @properties = []
    @format_properties = []
    @resources = []
    @blueprints = []
  end


  def all_files
    @components + @resources + @blueprints
  end


  def add_component(*args)
    @components.push(Peregrin::Component.new(*args)).last
  end


  def add_resource(*args)
    @resources.push(Peregrin::Resource.new(*args)).last
  end


  def add_blueprint(*args)
    @blueprints.push(Peregrin::Blueprint.new(*args)).last
  end


  def blueprint_for(rel)
    @blueprints.detect { |bp| bp.rel == rel }
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


  def add_format_property(*args)
    @format_properties.push(Peregrin::Property.new(*args)).last
  end


  def format_property_for(key)
    key = key.to_s
    prop = @format_properties.detect { |p| p.key == key }
    prop ? prop.value : nil
  end


  # The current version of document specifications.
  # Only used for EPUB for now.
  #
  def version
    v = format_property_for('version')
    v ? v.to_f : nil
  end


  # The page progression direction.
  # Can be "ltr" (left to right), "rtl" (right to left) or nil (omitted).
  # Only used for EPUB for now.
  #
  def direction
    format_property_for('page-progression-direction')
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
