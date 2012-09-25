class Peregrin::Epub

  FORMAT = "EPUB"

  NAMESPACES = {
    :ocf => { 'ocf' => 'urn:oasis:names:tc:opendocument:xmlns:container' },
    :opf => { 'opf' => 'http://www.idpf.org/2007/opf' },
    :dc => { 'dc' => 'http://purl.org/dc/elements/1.1/' },
    :ncx => { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' },
    :svg => { 'svg' => 'http://www.w3.org/2000/svg' },
    :nav => { 'nav' => 'http://www.w3.org/1999/xhtml'}
  }
  OCF_PATH = "META-INF/container.xml"
  HTML5_TAGNAMES = %w[section nav article aside hgroup header footer figure figcaption] # FIXME: Which to divify? Which to leave as-is?
  MIMETYPE_MAP = {
    '.xhtml' => 'application/xhtml+xml',
    '.odt' => 'application/x-dtbook+xml',
    '.odt' => 'application/x-dtbook+xml',
    '.ncx' => 'application/x-dtbncx+xml',
    '.epub' => 'application/epub+zip'
  }
  OEBPS = "OEBPS"
  NCX = 'content'
  OPF = 'content'


  def self.validate(path)
    raise FileNotFound.new(path)  unless File.file?(path)
    begin
      zf = Zip::Archive.open(path)
    rescue => e
      raise NotAZipArchive.new(path)
    end

    begin
      book = Peregrin::Book.new
      epub = new(book)
      epub.send(:load_blueprints, zf)
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
    @book = book
    if epub_path
      load_from_path(epub_path)
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
    @book.deep_clone
  end


  protected

    #---------------------------------------------------------------------------
    # READING
    #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    def load_from_path(epub_path)
      Zip::Archive.open(epub_path) { |zipfile|
        load_blueprints(zipfile)
        extract_properties
        extract_components(zipfile)
        extract_chapters(zipfile)
        extract_cover(zipfile)
      }
      @book.read_resource_proc = lambda { |resource|
        media_path = from_opf_root(resource.src)
        media_path = uri_unescape(media_path)
        Zip::Archive.open(epub_path) { |zipfile| zipfile.content(media_path) }
      }
    end


    def load_blueprints(zipfile)
      # The OCF file.
      begin
        ocf_content = zipfile.content(OCF_PATH)
        ocf = @book.add_blueprint(:ocf, OCF_PATH, ocf_content)
      rescue
        raise FailureLoadingOCF
      end

      # The OPF file.
      begin
        opf_xp = '//ocf:rootfile[@media-type="application/oebps-package+xml"]'
        opf_src = ocf.document.at_xpath(opf_xp, NAMESPACES[:ocf])['full-path']
        opf_content = zipfile.content(opf_src)
        opf = @book.add_blueprint(:opf, opf_src, opf_content)
      rescue
        raise FailureLoadingOPF
      end

      # EPUB version
      pkg_elem = opf.document.at_xpath('//opf:package', NAMESPACES[:opf])
      @epub_version = pkg_elem['version']

      # The NCX file.
      # Must be present only with Ebook < 3.0 but can be used
      # for forward compatibility
      begin
        spine = opf.document.at_xpath('//opf:spine', NAMESPACES[:opf])
        ncx_id = spine['toc'] ? spine['toc'] : 'ncx'
        ncx_xp = "//opf:manifest/opf:item[@id=#{escape_for_xpath(ncx_id)}]"
        ncx_href = opf.document.at_xpath(ncx_xp, NAMESPACES[:opf])['href']
        ncx_src = from_opf_root(ncx_href)
        ncx_content = zipfile.content(ncx_src)
        ncx = @book.add_blueprint(:ncx, ncx_src, ncx_content)
      rescue
        # Only raise an exeption for Ebook with version lower than 3.0
        raise FailureLoadingNCX if epub_version < 3
      end

      # The NAV file. (Epub3 only)
      if epub_version >= 3
        begin
          nav_xp = "//opf:manifest/opf:item[contains"+
            "(concat(' ', normalize-space(@properties), ' '), ' nav ')]"
          nav_href = opf.document.at_xpath(nav_xp, NAMESPACES[:opf])['href']
          nav_src = from_opf_root(nav_href)
          nav_content = zipfile.content(nav_src)
          nav = @book.add_blueprint(:nav, nav_src, nav_content)
        rescue => e
          raise FailureLoadingNAV
        end
      end

      # The others
      inf_rels = %w[container manifest metadata signature encryption rights]
      inf_rels.each { |rel|
        src = "META-INF/#{rel}.xml"
        next  unless zipfile.find(src)
        bp = @book.add_blueprint(rel.to_sym, src, zipfile.content(src))
      }
    end


    def extract_properties
      opf_doc = @book.blueprint_for(:opf).document
      meta_elems = opf_doc.at_xpath(
        '//opf:metadata',
        NAMESPACES[:opf]
      ).children.select { |ch|
        ch.element?
      }
      meta_elems.each { |elem|
        if elem.name == "meta"
          name = elem['name']
          content = elem['content']
        else
          name = elem.name
          content = elem.content
        end
        atts = elem.attributes.inject({}) { |acc, pair|
          key, attr = pair
          if !["name", "content", "property"].include?(key)
            acc[key] = attr.value
          elsif key == "property"
            @book.add_property(attr.value, elem.text)
          end
          acc
        }
        @book.add_property(name, content, atts) unless name.nil?
      }

      # Assign EPUB version
      @book.add_format_property('source', 'EPUB')
      @book.add_format_property('version', @epub_version)  if @epub_version

      # Extract page-turning direction
      if spine = opf_doc.at_xpath('//opf:spine', NAMESPACES[:opf])
        dir = spine['page-progression-direction']
        @book.add_format_property('page-progression-direction', dir)  if dir
      end
    end


    def extract_components(zipfile)
      opf_doc = @book.blueprint_for(:opf).document
      manifest = opf_doc.at_xpath('//opf:manifest', NAMESPACES[:opf])
      spine = opf_doc.at_xpath('//opf:spine', NAMESPACES[:opf])

      spine.search('//opf:itemref', NAMESPACES[:opf]).each { |iref|
        id = iref['idref']
        if item = manifest.at_xpath(
          "//opf:item[@id=#{escape_for_xpath(id)}]",
          NAMESPACES[:opf]
        )
          href = item['href']
          linear = iref['linear'] != 'no'
          begin
            content = zipfile.content(from_opf_root(href))
          rescue
            href = uri_unescape(href)
            content = zipfile.content(from_opf_root(href))
          end
          atts = { :id => id, :linear => linear ? "yes" : "no" }
          iref['properties'].split(/\s+/).each do |prop|
            if prop =~ /^rendition:(layout|orientation|spread)-(.+)$/
              atts["rendition:#{$1}"] = $2
            else
              atts[prop] = true
            end
          end if iref['properties']
          @book.add_component(href, content, item['media-type'], atts)
        end
      }

      manifest.search('//opf:item', NAMESPACES[:opf]).each { |item|
        id = item['id']
        next  if item['media-type'] == MIMETYPE_MAP['.ncx']
        next  if @book.components.detect { |cmpt| cmpt.attributes[:id] == id }
        @book.add_resource(item['href'], item['media-type'], :id => id)
      }

      opf_doc.search("//opf:guide/opf:reference", NAMESPACES[:opf]).each { |ref|
        if it = @book.all_files.detect { |cmpt| cmpt.src == ref['href'] }
          it.attributes[:guide_type] = ref['type']
          it.attributes[:guide] = ref['title']
        end
      }
    end


    def extract_chapters(zipfile)
      if epub_version >= 3 && nav = @book.blueprint_for(:nav)
        extract_nav_chapters(zipfile, nav.document)
      else
        extract_ncx_chapters(zipfile, @book.blueprint_for(:ncx).document)
      end
    end


    # Epub < 3.0 only
    def extract_ncx_chapters(zipfile, ncx_doc)
      curse = lambda { |point|
        chp = Peregrin::Chapter.new(
          point.at_xpath('.//ncx:text', NAMESPACES[:ncx]).content,
          point['playOrder'],
          point.at_xpath('.//ncx:content', NAMESPACES[:ncx])['src']
        )
        point.children.each { |pt|
          next  unless pt.element? && pt.name == "navPoint"
          chp.children.push(curse.call(pt))
        }
        chp
      }
      ncx_doc.at_xpath("//ncx:navMap", NAMESPACES[:ncx]).children.each { |pt|
        next  unless pt.element? && pt.name == "navPoint"
        @book.chapters.push(curse.call(pt))
      }
    end


    # Epub >= 3.0 only
    def extract_nav_chapters(zipfile, nav_doc)
      curse = lambda { |point, position|
        chp = Peregrin::Chapter.new(
          point.at_xpath('.//nav:a', NAMESPACES[:nav]).content,
          position,
          point.at_xpath('.//nav:a', NAMESPACES[:nav])['href']
        )
        ol = point.at_xpath('.//nav:ol', NAMESPACES[:nav])
        ol.children.each { |pt|
          next  unless pt.element? && pt.name == "li"
          position += 1
          position, chapter = curse.call(pt, position)
          chp.children.push chapter
        } if ol
        [position, chp]
      }
      position = 0
      nav_doc.at_xpath("//nav:nav/nav:ol", NAMESPACES[:nav]).children.each { |pt|
        next  unless pt.element? && pt.name == "li"
        position += 1
        position, chapter = curse.call(pt, position)
        @book.chapters.push chapter
      }
    end


    def extract_cover(zipfile)
      @book.cover = nil

      # 1. Cover image referenced from metadata
      if id = @book.property_for('cover')
        res = @book.all_files.detect { |r| r.attributes[:id] == id }
      end

      # 2. First image in a component listed in the guide as 'cover'
      res ||= @book.all_files.detect { |r| r.attributes[:guide_type] == 'cover' }

      # 3. A component with the id of 'cover-image', or 'cover', or 'coverpage'.
      ['cover-image', 'cover', 'coverpage'].each { |cvr_id|
        res ||= @book.all_files.detect { |r| r.attributes[:id] == cvr_id }
      }

      # 4. First image in first component.
      res ||= @book.all_files.first

      return  unless res

      if res.media_type.match(/^image\//)
        @book.cover = res
      else
        path = from_opf_root(res.src)
        begin
          doc = Nokogiri::XML::Document.parse(zipfile.content(path))
          src = nil
          if img = doc.at_css('img')
            src = img['src']
          elsif img = doc.at_xpath('//svg:image', NAMESPACES[:svg])
            src = img['href']
          end
          if src
            @book.cover = @book.resources.detect { |r| r.src == src }
          end
        rescue
          #puts "Cover component is not an image or an XML document."
        end
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
            xml.text_(@book.property_for('title'))
          }
          xml.navMap {
            i = 0
            curse = lambda { |children|
              children.each { |chapter|
                xml.navPoint(
                  :id => "navPoint#{i+=1}",
                  :playOrder => chapter.position
                ) {
                  xml.navLabel { xml.text_(chapter.title) }
                  xml.content(:src => chapter.src)
                  curse.call(chapter.children)  if chapter.children.any?
                }  unless chapter.empty_leaf?
              }
            }
            curse.call(@book.chapters)
          }
        }
      }
      @ncx_path = ncx_path
    end


    def write_components
      # Linear components.
      @book.components.each { |cmpt|
        cmpt.attributes[:id] ||= File.basename(cmpt.src, File.extname(cmpt.src))

        doc = Nokogiri::HTML::Document.parse(cmpt.contents)
        html = root_to_xhtml(doc.root)
        File.open(working_dir(OEBPS, cmpt.src), 'w') { |f| f.write(html) }
      }

      # Other components (@book.resources)
      @book.resources.each { |res|
        res.attributes[:id] ||= (
          "#{File.dirname(res.src)}-#{File.basename(res.src)}"
        ).gsub(/[^\w]+/, '-').gsub(/^-+/, '').gsub(/^(\d)/, 'a-\1')

        dest_path = working_dir(OEBPS, res.src)
        FileUtils.mkdir_p(File.dirname(dest_path))
        @book.copy_resource_to(res, dest_path)
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
            xml['dc'].title(@book.property_for('title') || 'Untitled')
            xml['dc'].identifier(unique_identifier, :id => 'bookid')
            xml['dc'].language(@book.property_for('language') || 'en')
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
              if val = @book.property_for(dc)
                val.split(/\n/).each { |v|
                  xml['dc'].send(dc, v)  if v
                }
              end
            }
            if @book.cover
              cover_id = @book.cover.attributes[:id] || "cover"
              xml.meta(:name => "cover", :content => cover_id)
            end
          }
          xml.manifest {
            @book.components.each { |item|
              xml.item(
                'id' => item.attributes[:id],
                'href' => item.src,
                'media-type' => MIMETYPE_MAP['.xhtml']
              )
            }
            @book.resources.each { |item|
              xml.item(
                'id' => item.attributes[:id],
                'href' => item.src,
                'media-type' => item.media_type
              )
            }
            xml.item(
              'id' => NCX,
              'href' => @ncx_path,
              'media-type' => MIMETYPE_MAP['.ncx']
            )
          }
          xml.spine(:toc => NCX) {
            @book.components.each { |item|
              xml.itemref(
                :idref => item.attributes[:id],
                :linear => item.attributes[:linear] || 'yes'
              )
            }
          }
          xml.guide {
            guide_items = @book.components.select { |it| it.attributes[:guide] }
            guide_items.each { |guide_item|
              xml.reference(
                :type => (
                  guide_item.attributes[:guide_type] ||
                  guide_item.attributes[:id]
                ),
                :title => guide_item.attributes[:guide],
                :href => guide_item.src
              )
            }
          }
        }
      }
    end


    def zip_it_up(filename)
      path = working_dir("..", filename)
      File.open(working_dir("mimetype"), 'w') { |f|
        f.write(MIMETYPE_MAP['.epub'])
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
      @uid ||= @book.property_for('bookid') || random_string(12)
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
        children.each { |chp|
          curr += 1
          max = [curr, max].max
          curse.call(chp.children)  if chp.children.any?
          curr -= 1
        }
      }
      curse.call(@book.chapters)
      max
    end


    def build_xml_file(path)
      raise ArgumentError  unless block_given?
      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') { |xml|
        yield(xml)
      }
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f|
        builder.doc.write_xml_to(f, :encoding => 'UTF-8', :indent => 2)
      }
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
      root.to_xhtml(:indent => 2, :encoding => root.document.encoding)
    end


    def from_opf_root(*args)
      opf = @book.blueprint_for(:opf)
      opf_root = File.dirname(opf.src)
      if opf_root && !opf_root.empty? && opf_root != '.'
        File.join(opf_root, *args)
      else
        File.join(*args)
      end
    end


    def escape_for_xpath(str)
      str.index("'") ? '"'+str+'"' : "'#{str}'"
    end


    def uri_unescape(str)
      @uri_parser ||= URI.const_defined?(:Parser) ? URI::Parser.new : URI
      @uri_parser.unescape(str)
    end


    def epub_version
      @epub_version ? @epub_version.to_f : 0
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
  class FailureLoadingNAV < ValidationError; end

end
