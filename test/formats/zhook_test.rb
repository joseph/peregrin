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
    assert_equal("index.html", book.components.first.keys.first)
    assert_equal(['cover.png'], book.media)
    assert_equal("A Basic Zhook", book.metadata['title'])
    assert_equal([{
      :title => "A Basic Zhook",
      :src => "index.html",
      :children => [
        { :title => "Part One", :src => "index.html#part1" },
        { :title => "Part Two", :src => "index.html#part2" }
      ]
    }], book.contents)
  end


  def test_to_book_componentization
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/basic.zhook')
    book = ook.to_book(:componentize => true)
    assert_equal(3, book.components.length)
    assert_equal([{
      :title => "A Basic Zhook",
      :src => "index.html",
      :children => [
        { :title => "Part One", :src => "part001.html#part1" },
        { :title => "Part Two", :src => "part002.html#part2" }
      ]
    }], book.contents)
  end


  def test_stitching_components
    book = Peregrin::Book.new
    book.components = [
      { "index.html" => %Q`
        <html><head><title>Index</title></head><body>
        <p>A para</p></body></html>
        ` },
      { "foo.html" => %Q`
        <html><head><title>Foo</title></head><body>
        <hgroup><h1>Part Foo</h1><h2>Peregrin Took</h2></hgroup>
        <cite>A cite tag</cite></body></html>
        ` },
      { "garply.html" => %Q`<p>A floating para.</p>` }
    ]
    ook = Peregrin::Zhook.new(book)
    assert_equal(
      whitewash(
        %Q`
        <!DOCTYPE html>
        <html><head><title>Index</title></head><body>
        <article>
          <p>A para</p>
        </article>
        <article>
          <hgroup><h1>Part Foo</h1><h2>Peregrin Took</h2></hgroup>
          <cite>A cite tag</cite>
        </article>
        <article>
          <p>A floating para.</p>
        </article>
        </body></html>`
      ),
      whitewash(ook.to_book.components.first.values.first)
    )
  end


  def test_consolidating_metadata
    book = Peregrin::Book.new
    book.components = [{
      "index.html" =>
        "<html><head><title>Foo</title></head><body><p>Foo</p></body></html>"
    }]
    book.metadata = {
      "title" => "Foo",
      "creator" => "Peregrin Took"
    }
    ook = Peregrin::Zhook.new(book)
    assert_equal(
      whitewash(%Q`
        <!DOCTYPE html>
        <html><head><title>Foo</title>
        <meta name="title" content="Foo">
        <meta name="creator" content="Peregrin Took">
        </head><body><p>Foo</p></body></html>
      `),
      whitewash(ook.to_book.components.first.values.first)
    )
  end

end
