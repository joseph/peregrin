class Peregrin::Ochook < Peregrin::Zhook

  FORMAT = "Ochook"
  MANIFEST_PATH = "ochook.manifest"

  def self.validate(path)
    path = path.gsub(/\/$/, '')
    unless File.directory?(path)
      raise DirectoryNotFound.new(path)
    end
    unless File.exists?(File.join(path, INDEX_PATH))
      raise MissingIndexHTML.new(path)
    end
    unless File.exists?(File.join(path, COVER_PATH))
      raise MissingCoverPNG.new(path)
    end
    unless File.exists?(File.join(path, MANIFEST_PATH))
      raise MissingManifest.new(path)
    end

    doc = Nokogiri::HTML::Document.parse(IO.read(File.join(path, INDEX_PATH)))
    raise IndexHTMLRootHasId.new(path)  if doc.root['id']
    unless doc.root['manifest'] = MANIFEST_PATH
      raise IndexHTMLRootHasNoManifest.new(path)
    end
  end


  def self.read(path)
    path = path.gsub(/\/$/, '')
    validate(path)
    book = Peregrin::Book.new
    book.add_component(INDEX_PATH, IO.read(File.join(path, INDEX_PATH)))
    Dir.glob(File.join(path, '**', '*')).each { |fpath|
      ex = [INDEX_PATH, MANIFEST_PATH]
      mpath = fpath.gsub(/^#{path}\//,'')
      unless File.directory?(fpath) || ex.include?(mpath)
        book.add_resource(mpath)
      end
    }
    book.read_resource_proc = lambda { |resource|
      IO.read(File.join(path, resource.src))
    }
    extract_properties_from_index(book)
    new(book)
  end


  def initialize(book)
    super
    insert_manifest_attribute
  end


  def write(dir)
    FileUtils.rm_rf(dir)  if File.directory?(dir)
    FileUtils.mkdir_p(dir)

    # Index
    index_path = File.join(dir, INDEX_PATH)
    File.open(index_path, 'w') { |f| f << htmlize(index) }

    # Resources
    @book.resources.each { |resource|
      full_path = File.join(dir, resource.src)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.open(full_path, 'w') { |f| f << @book.read_resource(resource) }
    }

    # Cover
    unless @book.cover == COVER_PATH
      cover_path = File.join(dir, COVER_PATH)
      File.open(cover_path, 'wb') { |f| f << to_png_data(@book.cover) }
      unless @book.resources.detect { |r| r.src == COVER_PATH }
        @book.add_resource(COVER_PATH)
      end
    end

    # Manifest
    manifest_path = File.join(dir, MANIFEST_PATH)
    File.open(manifest_path, 'w') { |f| f << manifest.join("\n") }
  end


  def to_book(options = {})
    remove_manifest_attribute
    super(options)
  end


  protected

    def manifest
      manifest = ["CACHE MANIFEST", "", "NETWORK:", "*", "", "CACHE:", INDEX_PATH]
      @book.resources.inject(manifest) { |mf, resource| mf << resource.src; mf }
    end


    def insert_manifest_attribute
      index.at_xpath('/html').set_attribute('manifest', MANIFEST_PATH)
    end


    def remove_manifest_attribute
      index.at_xpath('/html').remove_attribute('manifest')
    end


  class DirectoryNotFound < ValidationError; end
  class MissingManifest < ValidationError; end
  class IndexHTMLRootHasNoManifest < ValidationError; end

end
