class Peregrin::Ochook < Peregrin::Zhook

  MANIFEST_PATH = "ochook.manifest"

  def self.validate(path)
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
    validate(path)
    book = Peregrin::Book.new
    book.components.push(INDEX_PATH => IO.read(File.join(path, INDEX_PATH)))
    Dir.glob(File.join(path, '**', '*')).each { |fpath|
      ex = [INDEX_PATH, MANIFEST_PATH]
      fpath = fpath.gsub(/^#{path}\//,'')
      unless File.directory?(fpath) || ex.include?(fpath)
        book.media.push(fpath)
      end
    }
    book.read_media_proc = lambda { |media_path|
      IO.read(File.join(path, media_path))
    }
    extract_metadata_from_index(book)
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

    # Media
    @book.media.each { |mpath|
      full_path = File.join(dir, mpath)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.open(full_path, 'w') { |f| f << @book.read_media(mpath) }
    }

    # Cover
    unless @book.cover == COVER_PATH
      cover_path = File.join(dir, COVER_PATH)
      File.open(cover_path, 'wb') { |f| f << to_png_data(@book.cover) }
      @book.media << COVER_PATH  unless @book.media.include?(COVER_PATH)
    end

    # Manifest
    manifest_path = File.join(dir, MANIFEST_PATH)
    File.open(manifest_path, 'w') { |f| f << manifest.join("\n") }
  end


  protected

    def manifest
      manifest = ["CACHE MANIFEST", "NETWORK:", "*", "CACHE:"]
      @book.media.inject(manifest) { |mf, mpath| mf << mpath; mf }
    end


    def insert_manifest_attribute
      index.at_xpath('/html').set_attribute('manifest', MANIFEST_PATH)
    end



  class DirectoryNotFound < ValidationError; end
  class MissingManifest < ValidationError; end
  class IndexHTMLRootHasNoManifest < ValidationError; end

end
