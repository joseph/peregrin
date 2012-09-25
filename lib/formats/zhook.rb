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
      zf = Zip::Archive.open(path)
    rescue
      raise NotAZipArchive.new(path)
    end

    unless zf.find(INDEX_PATH)
      raise MissingIndexHTML.new(path)
    end

    unless zf.find(COVER_PATH)
      raise MissingCoverPNG.new(path)
    end

    doc = Nokogiri::HTML::Document.parse(zf.content(INDEX_PATH), nil, 'UTF-8')
    raise IndexHTMLRootHasId.new(path)  if doc.root['id']

  ensure
    zf.close  if zf
  end


  # Unzips the file at path, generates a simple book object, passes to new.
  #
  def self.read(path)
    validate(path)
    book = Peregrin::Book.new
    Zip::Archive.open(path) { |zf|
      book.add_component(INDEX_PATH, zf.content(INDEX_PATH))
      zf.each { |entry|
        ze = entry.name
        book.add_resource(ze)  unless ze == INDEX_PATH || entry.directory?
      }
    }
    book.read_resource_proc = lambda { |resource|
      Zip::Archive.open(path) { |zipfile| zipfile.content(resource.src) }
    }

    extract_properties_from_index(book)

    new(book)
  end


  # Stitches together components of the internal book.
  #
  def initialize(book)
    @book = book

    if @book.components.length > 1
      stitch_components(@book)
    end

    consolidate_properties(@book)

    @book.chapters = outline_book(index)

    @book.cover ||= (
      @book.resources.detect { |r| r.src == COVER_PATH } ||
      @book.add_resource(COVER_PATH)
    )
  end


  # Writes the internal book object to a .zhook file at the given path.
  #
  def write(path)
    File.unlink(path)  if File.exists?(path)
    Zip::Archive.open(path, Zip::CREATE) { |zipfile|
      zipfile.add_buffer(INDEX_PATH, htmlize(index))
      @book.resources.each { |resource|
        zipfile.add_buffer(resource.src, @book.read_resource(resource))
      }
      unless @book.cover.src == COVER_PATH
        zipfile.add_buffer(COVER_PATH, to_png_data(@book.cover))
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
        Peregrin::Component.new(uri_for_xpath(xpath, cmpt_xpaths), doc)
      }

      # Add rel links and convert to html string
      boilerplate_rel_links <<
        '<link rel="first" href="'+bk.components.first.src+'" />' +
        '<link rel="last" href="'+bk.components.last.src+'" />'
      bk.components.each_with_index { |cmpt, i|
        head = cmpt.contents.at_xpath(HEAD_XPATH)
        prev_path = bk.components[i-1].src  if (i-1) >= 0
        next_path = bk.components[i+1].src  if (i+1) < bk.components.size
        head.add_child(boilerplate_rel_links)
        head.add_child('<link rel="prev" href="'+prev_path+'" />')  if prev_path
        head.add_child('<link rel="next" href="'+next_path+'" />')  if next_path
        cmpt.contents = htmlize(cmpt.contents)
      }
    else
      cmpt_xpaths.push(BODY_XPATH)
      bk.components.clear
      bk.add_component(uri_for_xpath(BODY_XPATH), htmlize(index))
    end

    # Outlining.
    bk.chapters = outline_book(index, cmpt_xpaths)

    if options[:componentize]
      # Table of Contents
      doc = Nokogiri::HTML::Builder.new(:encoding => 'UTF-8') { |html|
        curse = lambda { |children|
          parts = children.collect { |chp|
            chp.empty_leaf? ? nil : [chp.title, chp.src, chp.children]
          }.compact

          html.ol {
            parts.each { |part|
              html.li {
                html.a(part[0], :href => part[1])
                curse.call(part[2])  if part[2].any?
              }
            }
          }  if parts.any?
        }
        curse.call(bk.chapters)
      }.doc
      if doc.root
        toc_doc = componentizer.generate_document(doc.root)
        toc_doc.at_xpath(HEAD_XPATH).add_child(boilerplate_rel_links)
        bk.add_component(
          "toc.html",
          htmlize(toc_doc),
          nil,
          :linear => "no",
          :guide => "Table of Contents",
          :guide_type => "toc"
        )
      end

      # List of Illustrations
      figures = index.css('figure[id], div.figure[id]')
      if figures.any?
        doc = Nokogiri::HTML::Builder.new(:encoding => 'UTF-8') { |html|
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
        bk.add_component(
          "loi.html",
          htmlize(loi_doc),
          nil,
          :linear => "no",
          :guide => "List of Illustrations",
          :guide_type => "loi"
        )
      end

      # Cover
      doc = Nokogiri::HTML::Builder.new(:encoding => 'UTF-8') { |html|
        html.div(:id => "cover") {
          html.img(:src => bk.cover.src, :alt => bk.property_for("title"))
        }
      }.doc
      cover_doc = componentizer.generate_document(doc.root)
      cover_doc.at_xpath(HEAD_XPATH).add_child(boilerplate_rel_links)
      bk.components.unshift(
        Peregrin::Component.new(
          "cover.html",
          htmlize(cover_doc),
          nil,
          :linear => "no",
          :guide => "Cover",
          :guide_type => "cover"
        )
      )
    end

    bk
  end


  protected

    def index
      @index_document ||= Nokogiri::HTML::Document.parse(
        @book.components.first.contents
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
        str = cmpt.contents
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
      book.components.clear
      book.add_component(uri_for_xpath(BODY_XPATH), htmlize(index))
    end


    # Takes the properties out of the book and ensures that there are matching
    # meta tags in the index document.
    #
    def consolidate_properties(book)
      head = index.at_xpath('/html/head')
      head.css('meta[name]').each { |meta| meta.remove }
      book.properties.each { |property|
        # FIXME: handle properties with attributes?
        meta = Nokogiri::XML::Node.new('meta', index)
        meta['name'] = property.key
        meta['content'] = property.value
        head.add_child(meta)
      }
    end


    def outline_book(doc, cmpt_xpaths = [BODY_XPATH])
      unless defined?(@outliner) && @outliner
        @outliner = Peregrin::Outliner.new(doc)
        @outliner.process(doc.at_css('body'))
      end

      i = 0
      curse = lambda { |sxn|
        chapter = Peregrin::Chapter.new(sxn.heading_text, i+=1)

        # identify any relevant child sections
        children = sxn.sections.collect { |ch|
          curse.call(ch) unless ch.empty?
        }.compact
        chapter.children = children  if children.any?

        # Find the component parent
        n = sxn.node || sxn.heading
        while n && n.respond_to?(:parent)
          break if cmpt_uri = uri_for_xpath(n.path, cmpt_xpaths)
          n = n.parent
        end

        if cmpt_uri
          # get URI for section
          sid = sxn.heading['id']  if sxn.heading
          cmpt_uri += "#"+sid  if sid && !sid.empty?
          chapter.src = cmpt_uri
        end

        chapter
      }

      result = curse.call(@outliner.result_root).children
      while result && result.length == 1 && result.first.title.nil?
        result = result.first.children
      end
      result
    end


    def uri_for_xpath(xpath, cmpt_xpaths = [BODY_XPATH])
      return nil  unless cmpt_xpaths.include?(xpath)
      i = cmpt_xpaths.index(xpath)
      (i == 0) ? "index.html" : "part#{"%03d" % i}.html"
    end


    def htmlize(doc)
      "<!DOCTYPE html>\n"+doc.root.to_html
    end


    def to_png_data(resource)
      return  if resource.nil?
      if File.extname(resource.src) == ".png"
        return @book.read_resource(resource)
      else
        raise ConvertUtilityMissing  unless `which convert`
        out = nil
        IO.popen("convert - png:-", "r+") { |io|
          io.write(@book.read_resource(resource))
          io.close_write
          out = io.read
        }
        out
      end
    end


    def self.extract_properties_from_index(book)
      book.add_format_property('source', 'Zhook')
      doc = Nokogiri::HTML::Document.parse(
        book.components.first.contents
      )
      doc.css('html head meta[name]').each { |meta|
        name = meta['name']
        content = meta['content']
        book.add_property(name, content)
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
