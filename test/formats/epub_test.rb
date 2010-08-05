require 'test/helper'

class Peregrin::Tests::EpubTest < Test::Unit::TestCase

  # A fairly trivial book-in, book-out test.
  def test_book_to_book
    epub = Peregrin::Epub.new(strunk_book)
    book = epub.to_book
    assert_equal(22, book.components.length)
    assert_equal(6, book.contents.length)
    assert_equal("William Strunk Jr.", book.metadata['creator'])
  end


  def test_write_to_epub
    epub = Peregrin::Epub.new(strunk_book)
    epub.write('test/fixtures/epubs/tmp/strunk_test.epub')
    assert(File.exists?('test/fixtures/epubs/tmp/strunk_test.epub'))
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
    metadata = epub.to_book.metadata
    assert_equal("The Elements of Style", metadata['title'])
  end


  def test_extracting_components
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    book = epub.to_book
    assert_equal(
      ["cover.xml", "title.xml", "about.xml", "main0.xml", "main1.xml", "main2.xml", "main3.xml", "main4.xml", "main5.xml", "main6.xml", "main7.xml", "main8.xml", "main9.xml", "main10.xml", "main11.xml", "main12.xml", "main13.xml", "main14.xml", "main15.xml", "main16.xml", "main17.xml", "main18.xml", "main19.xml", "main20.xml", "main21.xml", "similar.xml", "feedbooks.xml"],
      book.components.collect { |cmpt| cmpt.keys.first }
    )
    assert_equal(
      ["css/page.css", "css/feedbooks.css", "css/title.css", "css/about.css", "css/main.css", "images/logo-feedbooks-tiny.png", "images/logo-feedbooks.png", "images/cover.png"],
      book.media
    )
  end


  def test_extracting_contents
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    assert_equal(2, epub.send(:heading_depth))
  end


  def test_read_epub_to_write_epub
    epub = Peregrin::Epub.read("test/fixtures/epubs/strunk.epub")
    epub.write("test/fixtures/epubs/tmp/strunk_test2.epub")
    assert(File.exists?('test/fixtures/epubs/tmp/strunk_test2.epub'))
  end


  protected

    def strunk_book
      book = Peregrin::Book.new
      0.upto(21) { |i|
        path = "main#{i}.xml"
        book.components.push(
          path => IO.read("test/fixtures/epubs/strunk/OPS/#{path}")
        )
      }
      book.contents = [
        {
          :title => "Chapter 1 - Introductory",
          :src => "main0.xml"
        },
        {
          :title => "Chapter 2 - Elementary Rules of Usage",
          :src => "main1.xml",
          :children => [{
            :title => "1. Form the possessive singular of nounds with 's",
            :src => "main1.xml#section_98344"
          }]
        },
        {
          :title => "Chapter 3 - Elementary Principles of Composition",
          :src => "main9.xml"
        },
        {
          :title => "Chapter 4 - A Few Matters of Form",
          :src => "main19.xml"
        },
        {
          :title => "Chapter 5 - Words and Expressions Commonly Misused",
          :src => "main20.xml"
        },
        {
          :title => "Chapter 6 - Words Commonly Misspelled",
          :src => "main21.xml"
        }
      ]
      book.metadata = {
        "title" => "The Elements of Style",
        "creator" => "William Strunk Jr."
      }
      book.media = ["css/main.css"]
      book.media_copy_proc = lambda { |mpath, dpath|
        FileUtils.cp("test/fixtures/epubs/strunk/OPS/#{mpath}", dpath)
      }
      book
    end

end
