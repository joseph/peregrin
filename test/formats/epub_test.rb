require 'test_helper'

class Peregrin::Tests::EpubTest < Test::Unit::TestCase

  # A fairly trivial book-in, book-out test.
  def test_book_to_book
    epub = Peregrin::Epub.new(strunk_book)
    book = epub.to_book
    assert_equal(22, book.components.length)
    assert_equal(6, book.chapters.length)
    assert_equal("William Strunk Jr.", book.property_for('creator'))
  end


  def test_write_to_epub
    epub = Peregrin::Epub.new(strunk_book)
    epub.write('test/output/strunk_test.epub')
    assert(File.exists?('test/output/strunk_test.epub'))
    assert_nothing_raised {
      Peregrin::Epub.validate("test/output/strunk_test.epub")
    }
  end


  def test_heading_depth
    epub = Peregrin::Epub.new(strunk_book)
    assert_equal(2, epub.send(:heading_depth))
  end


  def test_epub_validation
    assert_nothing_raised {
      Peregrin::Epub.validate("test/fixtures/epubs/strunk.epub")
    }
  end


  def test_extracting_metadata
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal("The Elements of Style", epub.to_book.property_for('title'))
  end


  def test_extracting_components
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    book = epub.to_book
    assert_equal(
      ["cover.xml", "title.xml", "about.xml", "main0.xml", "main1.xml", "main2.xml", "main3.xml", "main4.xml", "main5.xml", "main6.xml", "main7.xml", "main8.xml", "main9.xml", "main10.xml", "main11.xml", "main12.xml", "main13.xml", "main14.xml", "main15.xml", "main16.xml", "main17.xml", "main18.xml", "main19.xml", "main20.xml", "main21.xml", "similar.xml", "feedbooks.xml"],
      book.components.collect { |cmpt| cmpt.src }
    )
    assert_equal(
      ["css/page.css", "css/feedbooks.css", "css/title.css", "css/about.css", "css/main.css", "images/logo-feedbooks-tiny.png", "images/logo-feedbooks.png", "images/cover.png"],
      book.resources.collect { |res| res.src }
    )
  end


  def test_extracting_contents
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal(2, epub.send(:heading_depth))
  end


  def test_extracting_cover
    # Cover image referenced from metadata
    epub = Peregrin::Epub.read("test/fixtures/epubs/covers/cover_in_meta.epub")
    assert_equal("cover.png", epub.to_book.cover.src)

    # First image in a component listed in the guide as 'cover'
    epub = Peregrin::Epub.read("test/fixtures/epubs/covers/cover_in_guide.epub")
    assert_equal("cover.png", epub.to_book.cover.src)

    # A component with the id of 'cover-image'.
    epub = Peregrin::Epub.read(
      "test/fixtures/epubs/covers/cover-image_in_manifest.epub"
    )
    assert_equal("cover.png", epub.to_book.cover.src)

    # First image in component with the id of 'cover'.
    epub = Peregrin::Epub.read(
      "test/fixtures/epubs/covers/cover_in_manifest.epub"
    )
    assert_equal("cover.png", epub.to_book.cover.src)

    # First image in first component.
    epub = Peregrin::Epub.read(
      "test/fixtures/epubs/covers/cover_in_first_cmpt.epub"
    )
    assert_equal("cover.png", epub.to_book.cover.src)
  end

  def test_extracting_epub3_fixed_layout_properties
    epub = Peregrin::Epub.read("test/fixtures/epubs/epub3_fixed_layout.epub")
    book = epub.to_book
    assert_equal("2012-05-09T08:58:00Z", book.property_for('dcterms:modified'))
    assert_equal("pre-paginated", book.property_for('rendition:layout'))
    assert_equal("auto", book.property_for('rendition:orientation'))
    assert_equal("both", book.property_for('rendition:spread'))
  end

  def test_extracting_version
    epub = Peregrin::Epub.read("test/fixtures/epubs/epub3_fixed_layout.epub")
    assert_equal(3.0, epub.to_book.version)

    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal(2.0, epub.to_book.version)
  end

  def test_extracting_chapters_from_ocx
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal(9, epub.to_book.chapters.count)
    assert_equal("Title", epub.to_book.chapters.first.title)
    assert_equal("title.xml", epub.to_book.chapters.first.src)
    assert_equal(1, epub.to_book.chapters.first.position)
    assert_equal("Recommendations", epub.to_book.chapters.last.title)
    assert_equal("similar.xml", epub.to_book.chapters.last.src)
    assert_equal(27, epub.to_book.chapters.last.position)
  end

  def test_extracting_chapters_from_nav
    epub = Peregrin::Epub.read("test/fixtures/epubs/epub3_fixed_layout.epub")
    assert_equal(3, epub.to_book.chapters.count)
    assert_equal("Images and Text", epub.to_book.chapters.first.title)
    assert_equal("page01.xhtml", epub.to_book.chapters.first.src)
    assert_equal(1, epub.to_book.chapters.first.position)
    assert_equal("Dragons", epub.to_book.chapters.last.title)
    assert_equal("page04.xhtml", epub.to_book.chapters.last.src)
    assert_equal(3, epub.to_book.chapters.last.position)
  end

  def test_extracting_nested_chapters_from_nav
    epub = Peregrin::Epub.read("test/fixtures/epubs/epub3_nested_nav.epub")
    assert_equal(11, epub.to_book.chapters.count)
    assert_equal(
      ["EPUB 3.0 Specification",
       "EPUB 3 Specifications - Table of Contents",
       "Terminology",
       "EPUB 3 Overview",
       "EPUB Publications 3.0",
       "EPUB Content Documents 3.0",
       "EPUB Media Overlays 3.0",
       "Acknowledgements and Contributors",
       "References",
       "EPUB Open Container Format (OCF) 3.0",
       "EPUB 3 Changes from EPUB 2.0.1"],
      epub.to_book.chapters.map(&:title)
    )
    assert_equal(
      [1, 2, 3, 4, 30, 85, 184, 230, 231, 232, 265],
      epub.to_book.chapters.map(&:position)
    )
    assert_equal(
      ["1. Introduction",
       "2. Features",
       "3. Global Language Support",
       "4. Accessibility"],
      epub.to_book.chapters[3].children.map(&:title)
    )
    assert_equal(
      [5, 8, 22, 29],
      epub.to_book.chapters[3].children.map(&:position)
    )
    assert_equal(
      ["3.1. Metadata",
       "3.2. Content Documents",
       "3.3. CSS",
       "3.4. Fonts",
       "3.5. Text-to-speech",
       "3.6. Container"],
      epub.to_book.chapters[3].children[2].children.map(&:title)
    )
    assert_equal(
      [23, 24, 25, 26, 27, 28],
      epub.to_book.chapters[3].children[2].children.map(&:position)
    )
  end

  def test_read_epub_to_write_epub
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    epub.write("test/output/strunk_test2.epub")
    assert(File.exists?('test/output/strunk_test2.epub'))
    assert_nothing_raised {
      Peregrin::Epub.validate("test/output/strunk_test2.epub")
    }
  end

  def test_extracting_direction
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal(nil, epub.to_book.direction)
    epub = Peregrin::Epub.read("test/fixtures/epubs/haruko-html-jpeg-20120524.epub")
    assert_equal("rtl", epub.to_book.direction)
  end


  protected

    def strunk_book
      book = Peregrin::Book.new
      0.upto(21) { |i|
        path = "main#{i}.xml"
        book.add_component(
          path,
          IO.read("test/fixtures/epubs/strunk/OPS/#{path}")
        )
      }
      pos = 0
      chp = book.add_chapter(
        "Chapter 1 - Introductory",
        pos+=1,
        "main0.xml"
      )
      chp = book.add_chapter(
        "Chapter 2 - Elementary Rules of Usage",
        pos+=1,
        "main1.xml"
      )
      chp.add_child(
        "1. Form the possessive singular of nounds with 's",
        pos+=1,
        "main1.xml#section_98344"
      )
      chp = book.add_chapter(
        "Chapter 3 - Elementary Principles of Composition",
        pos+=1,
        "main9.xml"
      )
      chp = book.add_chapter(
        "Chapter 4 - A Few Matters of Form",
        pos+=1,
        "main19.xml"
      )
      chp = book.add_chapter(
        "Chapter 5 - Words and Expressions Commonly Misused",
        pos+=1,
        "main20.xml"
      )
      chp = book.add_chapter(
        "Chapter 6 - Words Commonly Misspelled",
        pos+=1,
        "main21.xml"
      )
      book.add_property("title", "The Elements of Style")
      book.add_property("creator", "William Strunk Jr.")
      book.add_resource("css/main.css")
      book.read_resource_proc = lambda { |resource|
        IO.read("test/fixtures/epubs/strunk/OPS/#{resource.src}")
      }
      book
    end

end
