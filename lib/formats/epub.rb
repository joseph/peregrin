class Peregrin::Epub

  FORMAT = "EPUB"

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


  def self.validate(path)
    raise FileNotFound.new(path)  unless File.file?(path)
    begin
      zf = Zip::ZipFile.open(path)
    rescue
      raise NotAZipArchive.new(path)
    end

    begin
      book = Peregrin::Book.new
      epub = new(book)
      epub.send(:load_config_documents, zf)
    rescue => e
      raise e.class.new(path)
    end
  ensure
    zf.close  if zf
  end


  def self.read(path)
    book = Peregrin::Book.new
    new(book, path)
  end


  def initialize(book, epub_path = nil)
    @component_lookup = []
    @metadata_lookup = []
    @book = book
    if epub_path
      load_from_path(epub_path)
    else
      process_book
    end
  end


  def write(path)
    with_working_dir(path) {
      build_ocf
      build_ncx
      write_components
      build_opf
      zip_it_up(File.basename(path))
    }
  end


  def to_book(options = {})
    bk = @book.deep_clone
  end


  protected

    def process_book
      @book.components.each { |cmpt|
        href = cmpt.keys.first
        register_component(href, :linear => 'yes')
      }

      @book.media.each { |href|
        register_component(href)
      }

      @book.metadata.each_pair { |name, content|
        register_metadata(name, content)
      }
    end


    def register_component(href, attributes = {})
      cmpt = attributes.merge(:href => href)
      cmpt[:id] ||= href.gsub(/[^\w]+/, '-').gsub(/^-+/, '')
      cmpt[:mimetype] ||= MIMETYPE_MAP[File.extname(href)]
      cmpt[:mimetype] ||= "application/unknown"
      @component_lookup << cmpt
      cmpt
    end


    def register_metadata(name, content, attributes = nil)
      @metadata_lookup << {
        :name => name,
        :content => content,
        :attributes => attributes
      }
    end


    #---------------------------------------------------------------------------
    # READING
    #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    def load_from_path(epub_path)
      docs = nil
      Zip::ZipFile.open(epub_path) { |zipfile|
        docs = load_config_documents(zipfile)
        extract_metadata(docs[:opf])
        extract_components(zipfile, docs[:opf], docs[:opf_root])
        extract_chapters(zipfile, docs[:ncx])
        extract_cover(zipfile, docs)
      }
      @book.read_media_proc = lambda { |media_path|
        media_path = File.join(docs[:opf_root], media_path)
        Zip::ZipFile.open(epub_path) { |zipfile|
          zipfile.read(media_path)
        }
      }
    end


    def load_config_documents(zipfile)
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
        docs[:opf_root] = File.dirname(docs[:opf_path])
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
        docs[:ncx_path] = File.join(docs[:opf_root], item['href'])
        docs[:ncx] = Nokogiri::XML::Document.parse(zipfile.read(docs[:ncx_path]))
      rescue
        raise FailureLoadingNCX
      end

      docs
    end


    def extract_metadata(opf_doc)
      @book.metadata = opf_doc.at_xpath(
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
        register_metadata(name, content, elem.attributes)

        acc[name] = (acc[name] ? "#{acc[name]}\n#{content}" : content)
        acc
      }
    end


    def extract_components(zipfile, opf_doc, opf_root)
      ids = {}
      manifest = opf_doc.at_xpath('//opf:manifest', NAMESPACES[:opf])
      spine = opf_doc.at_xpath('//opf:spine', NAMESPACES[:opf])

      spine.search('//opf:itemref', NAMESPACES[:opf]).each { |iref|
        id = iref['idref']
        item = manifest.at_xpath("//opf:item[@id='#{id}']", NAMESPACES[:opf])
        href = item['href']
        register_component(
          href,
          :id => id,
          :mimetype => item['media-type'],
          :linear => iref['linear'] || 'yes'
        )
        if iref['linear'] != 'no'
          cmpt_path = (opf_root== '.' ? href : File.join(opf_root, href))
          @book.components.push(href => zipfile.read(cmpt_path))
        end
      }

      manifest.search('//opf:item', NAMESPACES[:opf]).each { |item|
        id = item['id']
        next  if item['media-type'] == MIMETYPE_MAP['.ncx']
        next  if @component_lookup.any? { |cmpt| cmpt[:id] == id }
        href = item['href']
        register_component(href, :id => id, :mimetype => item['media-type'])
        @book.media.push(href)
      }

      opf_doc.search("//opf:guide/opf:reference", NAMESPACES[:opf]).each { |ref|
        it = @component_lookup.detect { |cmpt| cmpt[:href] == ref['href'] }
        it[:guide_type] = ref['type']
        it[:guide] = ref['title']
      }
    end


    def extract_chapters(zipfile, ncx_doc)
      curse = lambda { |point|
        ch = {
          :title => point.at_xpath('.//ncx:text', NAMESPACES[:ncx]).content,
          :src => point.at_xpath('.//ncx:content', NAMESPACES[:ncx])['src']
        }
        point.children.each { |pt|
          next  unless pt.element? && pt.name == "navPoint"
          ch[:children] ||= []
          ch[:children].push(curse.call(pt))
        }
        ch
      }
      ncx_doc.at_xpath("//ncx:navMap", NAMESPACES[:ncx]).children.each { |pt|
        next  unless pt.element? && pt.name == "navPoint"
        @book.contents.push(curse.call(pt))
      }
    end


    def extract_cover(zipfile, docs)
      @book.cover = nil

      # 1. Cover image referenced from metadata
      if id = @book.metadata['cover']
        cmpt = @component_lookup.detect { |c| c[:id] == id }
      end

      # 2. First image in a component listed in the guide as 'cover'
      cmpt ||= @component_lookup.detect {|c| c[:guide_type] == 'cover'}

      # 3. A component with the id of 'cover-image'.
      cmpt ||= @component_lookup.detect { |c| c[:id] == 'cover-image' }

      # 4. First image in component with the id of 'cover'.
      cmpt ||= @component_lookup.detect { |c| c[:id] == 'cover' }

      # 5. First image in first component.
      cmpt ||= @component_lookup.detect { |c| c[:linear] == "yes" }

      return  unless cmpt

      if cmpt[:mimetype].match(/^image\//)
        @book.cover = cmpt[:href]
      else
        path = File.join(docs[:opf_root], cmpt[:href])
        doc = Nokogiri::HTML::Document.parse(zipfile.read(path))
        img = doc.at_css('img')
        @book.cover = img['src']  if img
      end

      @book.cover
    end


    #---------------------------------------------------------------------------
    # WRITING
    #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    def with_working_dir(path)
      raise ArgumentError  unless block_given?
      @working_dir = File.join(
        File.dirname(path),
        File.basename(path, File.extname(path))
      )
      FileUtils.rm_rf(@working_dir)
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
      ncx_path = build_xml_file(working_dir(OEBPS, "#{NCX}.ncx")) { |xml|
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
      register_component(ncx_path, :id => NCX)
    end


    def write_components
      # Linear components.
      @book.components.each { |cmpt|
        cmpt.each_pair { |path, str|
          doc = Nokogiri::HTML::Document.parse(str)
          html = root_to_xhtml(doc.root)
          File.open(working_dir(OEBPS, path), 'w') { |f| f.write(html) }
          id = File.basename(path, File.extname(path))
        }
      }

      # Other components (@book.media)
      @book.media.each { |media_path|
        id = (
          "#{File.dirname(media_path)}-" +
          "#{File.basename(media_path, File.extname(media_path))}"
        ).gsub(/[^\w]+/, '-')
        # FIXME: id must begin with an alpha character, and must be unique.
        dest_path = working_dir(OEBPS, media_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        @book.copy_media_to(media_path, dest_path)
      }
    end


    def build_opf
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
            @component_lookup.each { |item|
              xml.item(
                'id' => item[:id],
                'href' => item[:href],
                'media-type' => item[:mimetype]
              )
            }
          }
          xml.spine(:toc => NCX) {
            @component_lookup.select { |item| item[:linear] }.each { |item|
              xml.itemref(:idref => item[:id], :linear => item[:linear])
            }
          }
          xml.guide {
            @component_lookup.select { |it| it[:guide] }.each { |guide_item|
              xml.reference(
                :type => guide_item[:guide_type] || guide_item[:id],
                :title => guide_item[:guide],
                :href => guide_item[:href]
              )
            }
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
      path.gsub(/^#{working_dir(OEBPS)}\//, '')
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
      path.gsub(/^#{working_dir(OEBPS)}\//, '')
    end


    def root_to_xhtml(root)
      root.remove_attribute('manifest')
      root.css(HTML5_TAGNAMES.join(', ')).each { |elem|
        k = elem['class']
        elem['class'] = "#{k.nil? || k.empty? ? '' : "#{k} " }#{elem.name}"
        elem.name = "div"
      }
      root.remove_attribute('xmlns')
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
