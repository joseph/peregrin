class Peregrin::Zhook

  FORMAT = "Zhook"

  FILE_EXT = ".zhook"
  INDEX_PATH = "index.html"
  COVER_PATH = "cover.png"
  BODY_XPATH = '/html/body'
  HEAD_XPATH = '/html/head'

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
        book.media.push(ze)  unless ze == INDEX_PATH || entry.directory?
      }
    }
    book.read_media_proc = lambda { |media_path|
      Zip::ZipFile.open(path) { |zipfile|
        zipfile.read(media_path)
      }
    }

    extract_metadata_from_index(book)

    new(book)
  end


  # Stitches together components of the internal book.
  #
  def initialize(book)
    @book = book

    if @book.components.length > 1
      stitch_components(@book)
    end

    consolidate_metadata(@book)

    @book.contents = outline_book(index)

    unless @book.cover || !@book.media.include?(COVER_PATH)
      @book.cover = COVER_PATH
    end
  end


  # Writes the internal book object to a .zhook file at the given path.
  #
  def write(path)
    File.unlink(path)  if File.exists?(path)
    Zip::ZipFile.open(path, Zip::ZipFile::CREATE) { |zipfile|
      zipfile.get_output_stream("index.html") { |f| f << htmlize(index) }
      @book.media.each { |mpath|
        zipfile.get_output_stream(mpath) { |f| f << @book.read_media(mpath) }
      }
      unless @book.cover == COVER_PATH
        zipfile.get_output_stream(COVER_PATH) { |cfz|
          cfz << to_png_data(@book.cover)
        }
      end
    }
    path
  end


  # Returns the internal book object.
  #
  def to_book(options = {})
    bk = @book.deep_clone

    # XPath => URI mapping tools
    cmpt_xpaths = []

    boilerplate_rel_links =
      '<link rel="start" href="cover.html" />' +
      '<link rel="contents" href="toc.html" />'


    # Componentizing.
    if options[:componentize]
      componentizer = Peregrin::Componentizer.new(index)
      componentizer.process(index.root.at_css('body'))
      bk.components = componentizer.component_xpaths.collect { |xpath|
        cmpt_xpaths.push(xpath)
        doc = componentizer.generate_component(xpath)
        { uri_for_xpath(xpath, cmpt_xpaths) => doc }
      }

      # Add rel links and convert to html string
      first_path = bk.components.first.keys.first
      last_path = bk.components.last.keys.first
      boilerplate_rel_links <<
        '<link rel="first" href="'+bk.components.first.keys.first+'" />' +
        '<link rel="last" href="'+bk.components.last.keys.first+'" />'
      bk.components.each_with_index { |cmpt, i|
        path = cmpt.keys.first
        doc = cmpt.values.first
        head = doc.at_xpath(HEAD_XPATH)
        prev_path = bk.components[i-1].keys.first if (i-1) >= 0
        next_path = bk.components[i+1].keys.first if (i+1) < bk.components.size
        head.add_child(boilerplate_rel_links)
        head.add_child('<link rel="prev" href="'+prev_path+'" />') if prev_path
        head.add_child('<link rel="next" href="'+next_path+'" />') if next_path
        cmpt[path] = htmlize(doc)
      }
    else
      cmpt_xpaths.push(BODY_XPATH)
      bk.components = [{ uri_for_xpath(BODY_XPATH) => htmlize(index) }]
    end

    # Outlining.
    bk.contents = outline_book(index, cmpt_xpaths)


    if options[:componentize]
      # List of Illustrations
      figures = index.css('figure[id], div.figure[id]')
      if figures.any?
        doc = Nokogiri::HTML::Builder.new { |html|
          html.ol {
            figures.each { |fig|
              next  unless caption = fig.at_css('figcaption, .figcaption')
              n = fig
              while n && n.respond_to?(:parent)
                break if cmpt_uri = uri_for_xpath(n.path, cmpt_xpaths)
                n = n.parent
              end
              next  unless cmpt_uri
              html.li {
                html.a(caption.content, :href => "#{cmpt_uri}##{fig['id']}")
              }
            }
          }
        }.doc
        loi_doc = componentizer.generate_document(doc.root)
        loi_doc.at_xpath(HEAD_XPATH).add_child(boilerplate_rel_links)
        bk.components.unshift("loi.html" => htmlize(loi_doc))
      end

      # Table of Contents
      doc = Nokogiri::HTML::Builder.new { |html|
        curse = lambda { |children|
          html.ol {
            children.each { |sxn|
              html.li {
                html.a(sxn[:title], :href => sxn[:src])
                curse.call(sxn[:children])  if sxn[:children]
              }
            }
          }
        }
        curse.call(bk.contents)
      }.doc
      toc_doc = componentizer.generate_document(doc.root)
      toc_doc.at_xpath(HEAD_XPATH).add_child(boilerplate_rel_links)
      # FIXME: this should set guide to "Table of Contents",
      # guide_type to "toc" and linear to "no"
      bk.components.unshift("toc.html" => htmlize(toc_doc))

      # Cover
      doc = Nokogiri::HTML::Builder.new { |html|
        html.div(:id => "cover") {
          html.img(:src => bk.cover, :alt => bk.metadata["title"])
        }
      }.doc
      cover_doc = componentizer.generate_document(doc.root)
      cover_doc.at_xpath(HEAD_XPATH).add_child(boilerplate_rel_links)
      # FIXME: this should set guide to "Cover",
      # guide_type to "cover" and linear to "no"
      bk.components.unshift("cover.html" => htmlize(cover_doc))
    end

    bk
  end


  protected

    def index
      @index_document ||= Nokogiri::HTML::Document.parse(
        @book.components.first.values.first
      )
    end


    # Takes a book with multiple components and joins them together,
    # by creating article elements from every body element and appending them
    # to the body of the first component.
    #
    def stitch_components(book)
      node = Nokogiri::XML::Node.new('article', index)
      bdy = index.at_xpath(BODY_XPATH)
      head = index.at_xpath(HEAD_XPATH)
      bdy.children.each { |ch|
        node.add_child(ch)
      }
      bdy.add_child(node)

      book.components.shift
      while cmpt = book.components.shift
        str = cmpt.values.first
        doc = Nokogiri::HTML::Document.parse(str)
        art = doc.at_xpath(BODY_XPATH)
        art.name = 'article'
        bdy.add_child(art)

        # Import all other unique elements from the head, like link & meta tags.
        if dhead = doc.at_xpath(HEAD_XPATH)
          dhead.children.each { |foreign_child|
            next  if foreign_child.name.downcase == "title"
            next  if head.children.any? { |index_child|
              index_child.to_s == foreign_child.to_s
            }
            head.add_child(foreign_child.dup)
          }
        end
      end
      book.components = [{ uri_for_xpath(BODY_XPATH) => htmlize(index) }]
    end


    # Takes the metadata out of the book and ensures that there are matching
    # meta tags in the index document.
    #
    def consolidate_metadata(book)
      head = index.at_xpath('/html/head')
      head.css('meta[name]').each { |meta| meta.remove }
      book.metadata.each_pair { |name, content|
        content.split(/\n/).each { |val|
          meta = Nokogiri::XML::Node.new('meta', index)
          meta['name'] = name
          meta['content'] = val
          head.add_child(meta)
        }
      }
    end


    def outline_book(doc, cmpt_xpaths = [BODY_XPATH])
      unless defined?(@outliner) && @outliner
        @outliner = Peregrin::Outliner.new(doc)
        @outliner.process(doc.root)
      end

      curse = lambda { |sxn|
        chapter = {}

        chapter[:title] = sxn.heading_text  if sxn.heading_text

        # identify any relevant child sections
        children = sxn.sections.collect { |ch|
          curse.call(ch) unless ch.empty?
        }.compact

        chapter[:children] = children  if children.any?

        # Find the component parent
        n = sxn.node || sxn.heading
        while n && n.respond_to?(:parent)
          break if cmpt_uri = uri_for_xpath(n.path, cmpt_xpaths)
          n = n.parent
        end

        if cmpt_uri
          # get URI for section
          sid = sxn.heading['id']  if sxn.heading
          sid ||= sxn.node['id']  if sxn.node
          cmpt_uri += "#"+sid  if sid && !sid.empty?
          chapter[:src] = cmpt_uri

          # if sid && !sid.empty?
          #   chapter[:src] = (cmpt_uri + "#" + sid)
          # elsif children.any?
          #   chapter[:src] = cmpt_uri
          # end
        end
        chapter

        # Slight algorithm change: only show chapters with URIs and ids.
        #chapter[:src] || children.any? ? chapter : nil
      }

      result = curse.call(@outliner.result_root)[:children]
      while result && result.length == 1 && result.first[:title].nil?
        result = result.first[:children]
      end
      result
    end


    def uri_for_xpath(xpath, cmpt_xpaths = [BODY_XPATH])
      return nil  unless cmpt_xpaths.include?(xpath)
      i = cmpt_xpaths.index(xpath)
      (i == 0) ? "index.html" : "part#{"%03d" % i}.html"
    end


    def htmlize(doc)
      "<!DOCTYPE html>\n"+ doc.root.to_html
    end


    def to_png_data(path)
      return  if path.nil?
      if File.extname(path) == ".png"
        return @book.read_media(path)
      else
        raise ConvertUtilityMissing  unless `which convert`
        out = nil
        IO.popen("convert - png:-", "r+") { |io|
          io.write(@book.read_media(path))
          io.close_write
          out = io.read
        }
        out
      end
    end


    def self.extract_metadata_from_index(book)
      doc = Nokogiri::HTML::Document.parse(book.components.first.values.first)
      doc.css('html head meta[name]').each { |meta|
        name = meta['name']
        content = meta['content']
        if book.metadata[name]
          book.metadata[name] += "\n" + content
        else
          book.metadata[name] = content
        end
      }
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

  class ConvertUtilityMissing < RuntimeError; end

end
