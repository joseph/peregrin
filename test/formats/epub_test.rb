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


  def test_read_epub_to_write_epub
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    epub.write("test/output/strunk_test2.epub")
    assert(File.exists?('test/output/strunk_test2.epub'))
    assert_nothing_raised {
      Peregrin::Epub.validate("test/output/strunk_test2.epub")
    }
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
