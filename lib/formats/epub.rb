class Peregrin::Epub

  NAMESPACES = {
    :ocf => { 'ocf' => 'urn:oasis:names:tc:opendocument:xmlns:container' },
    :opf => { 'opf' => 'http://www.idpf.org/2007/opf' },
    :dc => { 'dc' => 'http://purl.org/dc/elements/1.1/' },
    :ncx => { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' }
  }
  OCF_PATH = "META-INF/container.xml"
  HTML5_TAGNAMES = %w[section nav article aside hgroup header footer figure figcaption] # FIXME: Which to divify? Which to leave as-is?
  MIMETYPE_MAP = {
    '.gif' => 'image/gif',
    '.jpg' => 'image/jpeg',
    '.png' => 'image/png',
    '.svg' => 'image/svg+xml',
    '.html' => 'application/xhtml+xml',
    '.odt' => 'application/x-dtbook+xml',
    '.css' => 'text/css',
    '.xml' => 'application/xml',
    '.ncx' => 'application/x-dtbncx+xml'
  }
  OEBPS = "OEBPS"
  NCX = 'content'
  OPF = 'content'

  attr_writer :mime_lookup


  def self.validate(path)
    raise FileNotFound.new(path)  unless File.file?(path)
    begin
      zf = Zip::ZipFile.open(path)
    rescue
      raise NotAZipArchive.new(path)
    end

    begin
      load_config_documents(zf)
    rescue => e
      raise e.class.new(path)
    end
  ensure
    zf.close  if zf
  end


  def self.read(path)
    book = Peregrin::Book.new
    Zip::ZipFile.open(path) { |zipfile|
      docs = load_config_documents(zipfile)
      book.metadata = extract_metadata(docs[:opf])
      book.components, book.media = extract_components(
        zipfile,
        docs[:opf],
        docs[:opf_path]
      )
      book.contents = extract_chapters(zipfile, docs[:ncx])
    }
    new(book)
  end


  def initialize(book)
    @book = book
  end


  def write(path)
    with_working_dir(path) {
      manifest_items = []
      build_ocf
      manifest_items += build_ncx
      manifest_items += write_components
      build_opf(manifest_items)
      zip_it_up(File.basename(path))
    }
  end


  def to_book(options = {})
    bk = @book.deep_clone
  end


  protected

    def self.load_config_documents(zipfile)
      # The OCF file.
      begin
        docs = { :ocf => Nokogiri::XML::Document.parse(zipfile.read(OCF_PATH)) }
      rescue
        raise FailureLoadingOCF
      end

      # The OPF file.
      begin
        docs[:opf_path] = docs[:ocf].at_xpath(
          '//ocf:rootfile[@media-type="application/oebps-package+xml"]',
          NAMESPACES[:ocf]
        )['full-path']
        docs[:opf] = Nokogiri::XML::Document.parse(zipfile.read(docs[:opf_path]))
      rescue
        raise FailureLoadingOPF
      end

      # The NCX file.
      begin
        spine = docs[:opf].at_xpath('//opf:spine', NAMESPACES[:opf])
        ncx_id = spine['toc'] ? spine['toc'] : 'ncx'
        item = docs[:opf].at_xpath(
          "//opf:manifest/opf:item[@id='#{ncx_id}']",
          NAMESPACES[:opf]
        )
        docs[:ncx_path] = File.join(File.dirname(docs[:opf_path]), item['href'])
        docs[:ncx] = Nokogiri::XML::Document.parse(zipfile.read(docs[:ncx_path]))
      rescue
        raise FailureLoadingNCX
      end

      docs
    end


    def self.extract_metadata(opf_doc)
      opf_doc.at_xpath(
        '//opf:metadata',
        NAMESPACES[:opf]
      ).children.select { |ch|
        ch.element?
      }.inject({}) { |acc, elem|
        if elem.name == "meta"
          name = elem['name']
          content = elem['content']
        else
          name = elem.name
          content = elem.content
        end

        acc[name] = (acc[name] ? "#{acc[name]}\n#{content}" : content)
        acc
      }
    end


    def self.extract_components(zipfile, opf_doc, opf_path)
      content_root = File.dirname(opf_path)
      ids = {}
      components = []
      media = []
      manifest = opf_doc.at_xpath('//opf:manifest', NAMESPACES[:opf])
      spine = opf_doc.at_xpath('//opf:spine', NAMESPACES[:opf])

      spine.search('//opf:itemref', NAMESPACES[:opf]).each { |iref|
        next  if iref['linear'] == 'no'
        id = iref['idref']
        item = manifest.at_xpath("//opf:item[@id='#{id}']", NAMESPACES[:opf])
        href = item['href']
        cmpt_path = (content_root == '.' ? href : File.join(content_root, href))
        components.push(href => zipfile.read(cmpt_path))
        ids.update(id => href)
      }

      manifest.search('//opf:item', NAMESPACES[:opf]).each { |item|
        id = item['id']
        next  if ids.keys.include?(id)
        href = item['href']
        ids.update(id => href)
        media.push(href)
      }
      [components, media]
    end


    def self.extract_chapters(zipfile, ncx_doc)
      # TODO
    end


    def with_working_dir(path)
      raise ArgumentError  unless block_given?
      @working_dir = File.join(
        File.dirname(path),
        File.basename(path, File.extname(path))
      )
      FileUtils.mkdir_p(@working_dir)
      yield
    ensure
      #FileUtils.rm_rf(@working_dir)
      @working_dir = nil
    end


    def working_dir(*args)
      File.join(*([@working_dir, args].flatten.compact))
    end


    def build_ocf
      build_xml_file(working_dir(OCF_PATH)) { |xml|
        xml.container(:xmlns => NAMESPACES[:ocf]["ocf"], :version => "1.0") {
          xml.rootfiles {
            xml.rootfile(
              "full-path" => "OEBPS/#{OPF}.opf",
              "media-type" => "application/oebps-package+xml"
            )
          }
        }
      }
    end


    def build_ncx
      p = build_xml_file(working_dir(OEBPS, "#{NCX}.ncx")) { |xml|
        xml.ncx('xmlns' => NAMESPACES[:ncx]["ncx"], :version => "2005-1") {
          xml.head {
            xml.meta(:name => "dtb:uid", :content => unique_identifier)
            xml.meta(:name => "dtb:depth", :content => heading_depth)
            xml.meta(:name => "dtb:totalPageCount", :content => "0")
            xml.meta(:name => "dtb:maxPageNumber", :content => "0")
          }
          xml.docTitle {
            xml.text_(@book.metadata['title'])
          }
          xml.navMap {
            x = 0
            curse = lambda { |children|
              children.each { |chapter|
                xml.navPoint(:id => "navPoint#{x+=1}", :playOrder => x) {
                  xml.navLabel { xml.text_(chapter[:title]) }
                  xml.content(:src => chapter[:src])
                  curse.call(chapter[:children])  if chapter[:children]
                }
              }
            }
            curse.call(@book.contents)
          }
        }
      }
      [manifest_item(NCX, p)]
    end


    def write_components
      manifest_items = []

      # Linear components.
      @book.components.each { |cmpt|
        cmpt.each_pair { |path, str|
          doc = Nokogiri::HTML::Document.parse(str)
          html = root_to_xhtml(doc.root)
          File.open(working_dir(OEBPS, path), 'w') { |f| f.write(html) }
          id = File.basename(path, File.extname(path))
          manifest_items << manifest_item(id, path, 'yes')
        }
      }

      # Other components (@book.media)
      @book.media.each { |media_path|
        id = "#{File.dirname(media_path)}-" +
          "#{File.basename(media_path, File.extname(media_path))}".gsub(
            /[^A-Za-z]+/,
            '-'
          )
        dest_path = working_dir(OEBPS, media_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        @book.copy_media_to(media_path, dest_path)
        manifest_items << manifest_item(id, dest_path)
      }

      # Table of Contents
      unless manifest_items.detect { |it| it[:id] == "toc" }
        path = build_html_file(working_dir(OEBPS, "toc.html")) { |html|
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
          curse.call(@book.contents)
        }
        manifest_items << manifest_item("toc", path, "no")
      end

      # Cover page
      unless manifest_items.detect { |it| it[:id] == "cover" }
        path = build_html_file(working_dir(OEBPS, "cover.html")) { |html|
          html.div(:id => "cover") {
            # TODO: get filename of cover image...
            html.img(:src => "cover.png", :alt => @book.metadata["title"])
          }
        }
        manifest_items << manifest_item("cover", path, 'no')
      end

      manifest_items
    end


    def build_opf(manifest_items)
      build_xml_file(working_dir(OEBPS, "#{OPF}.opf")) { |xml|
        xml.package(
          'xmlns' => "http://www.idpf.org/2007/opf",
          'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
          'version' => "2.0",
          'unique-identifier' => 'bookid'
        ) {
          xml.metadata {
            xml['dc'].title(@book.metadata['title'] || 'Untitled')
            xml['dc'].identifier(unique_identifier, :id => 'bookid')
            xml['dc'].language(@book.metadata['language'] || 'en')
            [
              'creator',
              'subject',
              'description',
              'publisher',
              'contributor',
              'date',
              'source',
              'relation',
              'coverage',
              'rights'
            ].each { |dc|
              val = @book.metadata[dc]
              xml['dc'].send(dc, val)  if val
            }
            xml.meta(:name => "cover", :content => "cover")
          }
          xml.manifest {
            manifest_items.each { |item|
              xml.item(
                'id' => item[:id],
                'href' => item[:path],
                'media-type' => item[:mimetype]
              )
            }
          }
          xml.spine(:toc => NCX) {
            manifest_items.select { |item| item[:spine] }.each { |item|
              xml.itemref(:idref => item[:id], :linear => item[:spine])
            }
          }
          xml.guide {
            if item = manifest_items.detect { |it| it[:id] == "cover" }
              xml.reference(
                :type => "cover",
                :title => "Cover",
                :href => item[:path]
              )
            end
            if item = manifest_items.detect { |it| it[:id] == "toc" }
              xml.reference(
                :type => "toc",
                :title => "Table of Contents",
                :href => item[:path]
              )
            end
            if item = manifest_items.detect { |it| it[:id] == "loi" }
              xml.reference(
                :type => "loi",
                :title => "List of Illustrations",
                :href => item[:path]
              )
            end
          }
        }
      }
    end


    def zip_it_up(filename)
      path = working_dir("..", filename)
      File.open(working_dir("mimetype"), 'w') { |f|
        f.write('application/epub+zip')
      }
      File.unlink(path)  if File.exists?(path)
      cmd = [
        "cd #{working_dir}",
        "zip -0Xq ../#{filename} mimetype",
        "zip -Xr9Dq ../#{filename} *"
      ]
      `#{cmd.join(" && ")}`
      path
    end


    def manifest_item(id, path, spine = nil, mimetype = nil)
      path = path.gsub(/^#{working_dir(OEBPS)}\//, '')
      cmpt = { :id => id, :path => path, :mimetype => mimetype, :spine => spine }
      unless cmpt[:mimetype]
        @mime_lookup.detect { |pattern, mt|
          cmpt[:mimetype] = mt  if path.match(pattern)
        }  if defined?(@mime_lookup) && @mime_lookup

        ext = File.extname(path)
        cmpt[:mimetype] ||= MIMETYPE_MAP[ext] || 'application/unknown'
      end
      cmpt
    end


    def unique_identifier
      @uid ||= @book.metadata['bookid'] || random_string(12)
    end


    def random_string(len)
      require 'digest/sha1'
      s = Digest::SHA1.new
      s << Time.now.to_s
      s << String(Time.now.usec)
      s << String(rand(0))
      s << String($$)
      str = s.hexdigest
      str.slice(rand(str.size - len), len)
    end


    def heading_depth
      max = 0
      curr = 0
      curse = lambda { |children|
        children.each { |ch|
          curr += 1
          max = [curr, max].max
          curse.call(ch[:children])  if ch[:children]
          curr -= 1
        }
      }
      curse.call(@book.contents)
      max
    end


    def build_xml_file(path)
      raise ArgumentError  unless block_given?
      builder = Nokogiri::XML::Builder.new { |xml| yield(xml) }
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f|
        builder.doc.write_xml_to(f, :encoding => 'UTF-8', :indent => 2)
      }
      path
    end


    def build_html_file(path)
      @shell_document ||= Nokogiri::HTML::Document.parse(
        @book.components.first.values.first
      )
      bdy = @shell_document.at_xpath('/html/body')
      bdy.children.remove
      doc = Nokogiri::HTML::Builder.new { |html| yield(html) }.doc
      bdy.add_child(doc.root)
      File.open(path, 'w') { |f| f.write(root_to_xhtml(@shell_document.root)) }
      path
    end


    def root_to_xhtml(root)
      root.remove_attribute('manifest')
      root.css(HTML5_TAGNAMES.join(', ')).each { |elem|
        k = elem['class']
        elem['class'] = "#{k.nil? || k.empty? ? '' : "#{k} " }#{elem.name}"
        elem.name = "div"
      }
      root.remove_attribute('xmlns')#, "http://www.w3.org/1999/xhtml")
      root.to_xhtml(:indent => 2)
    end


  class ValidationError < ::RuntimeError

    def initialize(path = nil)
      @path = path
    end

  end

  class FileNotFound < ValidationError; end
  class NotAZipArchive < ValidationError; end
  class FailureLoadingOCF < ValidationError; end
  class FailureLoadingOPF < ValidationError; end
  class FailureLoadingNCX < ValidationError; end

end
