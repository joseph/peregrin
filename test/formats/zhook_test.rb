require 'test/helper'

class Peregrin::Tests::ZhookTest < Test::Unit::TestCase


  def test_validates
    # File does not exist
    assert_raise(Peregrin::Zhook::FileNotFound) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/missing.zhook')
    }

    # File extension is not .zhook
    assert_raise(Peregrin::Zhook::WrongExtension) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/wrongext.zip')
    }

    # File is not a zip archive
    assert_raise(Peregrin::Zhook::NotAZipArchive) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/notazip.zhook')
    }

    # Archive does not contain index.html
    assert_raise(Peregrin::Zhook::MissingIndexHTML) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/noindex.zhook')
    }

    # Archive does not contain cover.png
    assert_raise(Peregrin::Zhook::MissingCoverPNG) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/nocover.zhook')
    }

    # Index file has a HTML element with an id.
    assert_raise(Peregrin::Zhook::IndexHTMLRootHasId) {
      Peregrin::Zhook.validate('test/fixtures/zhooks/invalid/rootid.zhook')
    }

    # An actual valid .zhook
    assert_nothing_raised {
      Peregrin::Zhook.validate('test/fixtures/zhooks/basic.zhook')
    }
  end


  def test_read
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/basic.zhook')
    book = ook.to_book
    assert_equal(1, book.components.length)
    assert_equal(['cover.png'], book.media)
    assert_equal("A Basic Zhook", book.metadata['title'])
  end

end
