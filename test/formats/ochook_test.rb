require 'test/helper'

class Peregrin::Tests::OchookTest < Test::Unit::TestCase

  def test_validates
    # FIXME: tests for:
    #  - DirectoryNotFound
    #  - MissingManifest
    #  - IndexHTMLRootHasNoManifest
    #
    # ???
    assert_nothing_raised {
      Peregrin::Ochook.validate('test/fixtures/ochooks/basic')
    }
  end


  def test_read
    ook = Peregrin::Ochook.read('test/fixtures/ochooks/basic')
    book = ook.to_book
    assert_equal(1, book.components.length)
    assert_equal("index.html", book.components.first.keys.first)
    assert_equal(['cover.png'], book.media)
    assert_equal("A Basic Ochook", book.metadata['title'])
    assert_equal([{
      :title => "A Basic Ochook",
      :src => "index.html",
      :children => [
        { :title => "Part One", :src => "index.html#part1" },
        { :title => "Part Two", :src => "index.html#part2" }
      ]
    }], book.contents)
  end


  def test_write_from_epub
    epub = Peregrin::Epub.read('test/fixtures/epubs/alice.epub')
    book = epub.to_book
    ook = Peregrin::Ochook.new(book)
    ook.write('test/output/alice_ochook')
    assert_nothing_raised {
      Peregrin::Ochook.validate('test/output/alice_ochook')
    }
  end

end
