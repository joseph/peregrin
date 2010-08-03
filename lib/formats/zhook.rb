class Peregrin::Zhook

  FILE_EXT = ".zhook"
  INDEX_PATH = "index.html"
  COVER_PATH = "cover.png"

  # Raises an exception if file at path is not a valid Zhook. Otherwise
  # returns true.
  #
  def self.validate(path)
    raise FileNotFound.new(path)  unless File.file?(path)
    raise WrongExtension.new(path)  unless File.extname(path) == FILE_EXT
    begin
      zf = Zip::ZipFile.open(path)
    rescue
      raise NotAZipArchive.new(path)
    end

    unless zf.find_entry(INDEX_PATH)
      raise MissingIndexHTML.new(path)
    end

    unless zf.find_entry(COVER_PATH)
      raise MissingCoverPNG.new(path)
    end

    doc = Nokogiri::HTML::Document.parse(zf.read(INDEX_PATH))
    raise IndexHTMLRootHasId.new(path)  if doc.root['id']

  ensure
    zf.close  if zf
  end


  # Unzips the file at path, generates a simple book object, passes to new.
  #
  def self.read(path)
    validate(path)
    book = Peregrin::Book.new
    Zip::ZipFile.open(path) { |zf|
      book.components.push(INDEX_PATH => zf.read(INDEX_PATH))
      Zip::ZipFile.foreach(path) { |entry|
        ze = entry.to_s
        book.media.push(ze)  unless ze == INDEX_PATH
      }
    }
    doc = Nokogiri::HTML::Document.parse(book.components.first.values.first)
    doc.css('head meta').each { |meta|
      name = meta['name']
      content = meta['content']
      if book.metadata[name]
        book.metadata[name] += "\n" + content
      else
        book.metadata[name] = content
      end
    }

    new(book)
  end


  # Stitches together components of the internal book.
  #
  def initialize(book)
    @book = book.clone
    # TODO: stitch components together.
    # TODO: build outline from component.
  end


  # Writes the internal book object to a .zhook file at the given path.
  #
  def write(path)
  end


  # Returns the internal book object.
  #
  def to_book(options = {})
    @book
  end


  class ValidationError < ::RuntimeError

    def initialize(path = nil)
      @path = path
    end

  end

  class FileNotFound < ValidationError; end
  class WrongExtension < ValidationError; end
  class NotAZipArchive < ValidationError; end
  class MissingIndexHTML < ValidationError; end
  class MissingCoverPNG < ValidationError; end
  class IndexHTMLRootHasId < ValidationError; end

end
