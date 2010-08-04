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
    epub.mime_lookup = { Regexp.new("^.*\.xml$") => "application/xhtml+xml" }
    epub.write('test/fixtures/epubs/tmp/strunk_test.epub')
  end


  def test_heading_depth
    epub = Peregrin::Epub.new(strunk_book)
    assert_equal(2, epub.send(:heading_depth))
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
