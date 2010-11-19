require 'test_helper'

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
      Peregrin::Zhook.validate('test/fixtures/zhooks/flat.zhook')
    }
  end


  def test_read
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/2level.zhook')
    book = ook.to_book
    assert_equal(1, book.components.length)
    assert_equal("index.html", book.components.first.src)
    assert_equal(['cover.png'], book.resources.collect { |res| res.src })
    assert_equal("A Two-Level Zhook", book.property_for('title'))
    assert_equal(1, book.chapters.size)
    chp = book.chapters.first
    assert_equal("A Two-Level Zhook", chp.title)
    assert_equal("index.html", chp.src)
    assert_equal("Part One", chp.children[0].title)
    assert_equal("index.html#part1", chp.children[0].src)
    assert_equal("Part Two", chp.children[1].title)
    assert_equal("index.html#part2", chp.children[1].src)
  end


  def test_to_book_componentization
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/flat.zhook')
    book = ook.to_book(:componentize => true)
    assert_equal(
      ["cover.html", "index.html", "part001.html", "part002.html", "toc.html"],
      book.components.collect { |cmpt| cmpt.src }
    )
    assert_equal(3, book.chapters.size)
    assert_equal("A Flat Zhook", book.chapters[0].title)
    assert_equal("Part One", book.chapters[1].title)
    assert_equal("Part Two", book.chapters[2].title)
  end


  def test_2_level_componentization
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/2level.zhook')
    book = ook.to_book(:componentize => true)
    assert_equal(1, book.chapters.size)
    chp = book.chapters.first
    assert_equal("A Two-Level Zhook", chp.title)
    assert_equal("index.html", chp.src)
    assert_equal("Part One", chp.children[0].title)
    assert_equal("part001.html#part1", chp.children[0].src)
    assert_equal("Part Two", chp.children[1].title)
    assert_equal("part002.html#part2", chp.children[1].src)
  end


  def test_3_level_componentization
    ook = Peregrin::Zhook.read('test/fixtures/zhooks/3level.zhook')
    book = ook.to_book(:componentize => true)
    assert_equal(1, book.chapters.size)
    chp = book.chapters.first
    assert_equal("A Three-Level Zhook", chp.title)
    assert_equal("index.html", chp.src)
    assert_equal("Part One", chp.children[0].title)
    assert_equal("part001.html#part1", chp.children[0].src)
    assert_equal("Part Two", chp.children[1].title)
    assert_equal("part003.html#part2", chp.children[1].src)
    assert_equal("Sub-part One Dot Two", chp.children[0].children[0].title)
    assert_equal("part002.html", chp.children[0].children[0].src)
    assert_equal("Sub-part Two Dot Two", chp.children[1].children[0].title)
    assert_equal("part004.html", chp.children[1].children[0].src)
  end


  def test_stitching_components
    book = Peregrin::Book.new
    book.add_component(
      "index.html",
      %Q`
        <html><head><title>Index</title>
        <meta http-equiv="Content-Type" content="text/html;charset=US-ASCII">
        </head><body>
        <p>A para</p></body></html>
      `
    )
    book.add_component(
      "foo.html",
      %Q`
        <html><head><title>Foo</title>
        <link rel="stylesheet" href="main.css" />
        </head><body>
        <hgroup><h1>Part Foo</h1><h2>Peregrin Took</h2></hgroup>
        <cite>A cite tag</cite></body></html>
      `
    )
    book.add_component("garply.html", %Q`<p>A floating para.</p>`)
    ook = Peregrin::Zhook.new(book)
    assert_equal(
      whitewash(
        %Q`
        <!DOCTYPE html>
        <html><head>
          <title>Index</title>
          <meta http-equiv="Content-Type" content="text/html;charset=US-ASCII">
          <link rel="stylesheet" href="main.css">
        </head><body>
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
      whitewash(ook.to_book.components.first.contents)
    )
  end


  def test_consolidating_metadata
    book = Peregrin::Book.new
    book.add_component(
      "index.html",
      "<html><head><title>Foo</title>" +
      "<meta http-equiv=\"Content-Type\" content=\"text/html;charset=US-ASCII\">" +
      "</head><body><p>Foo</p></body></html>"
    )
    book.add_property("title", "Foo")
    book.add_property("creator", "Peregrin Took")
    ook = Peregrin::Zhook.new(book)
    assert_equal(
      whitewash(%Q`
        <!DOCTYPE html>
        <html><head><title>Foo</title>
        <meta http-equiv="Content-Type" content="text/html;charset=US-ASCII">
        <meta name="title" content="Foo">
        <meta name="creator" content="Peregrin Took">
        </head><body><p>Foo</p></body></html>
      `),
      whitewash(ook.to_book.components.first.contents)
    )
  end


  def test_write_from_epub
    epub = Peregrin::Epub.read('test/fixtures/epubs/alice.epub')
    book = epub.to_book
    ook = Peregrin::Zhook.new(book)
    ook.write('test/output/alice.zhook')
    assert_nothing_raised {
      Peregrin::Zhook.validate('test/output/alice.zhook')
    }
  end


  def test_convert_jpg_cover_on_write
    # Create an epub object, convert it to a book, and verify that the cover
    # is a JPEG.
    epub = Peregrin::Epub.read('test/fixtures/epubs/alice.epub')
    book = epub.to_book
    assert_equal(
      "www.gutenberg.org@files@19033@19033-h@images@cover_th.jpg",
      book.cover.src
    )

    # Write the book to file as a Zhook, which should convert the cover to PNG.
    ook = Peregrin::Zhook.new(book)
    ook.write('test/output/alice.zhook')

    # Load the Zhook from file, and check that it has a cover.png.
    ook2 = Peregrin::Zhook.read('test/output/alice.zhook')
    book2 = ook2.to_book
    assert_equal("cover.png", book2.cover.src)

    # Validate the cover.png using ImageMagick's identify
    IO.popen("identify -", "r+") { |io|
      io.write(book2.read_resource(book2.cover))
      io.close_write
      assert_match(/^[^\s]+ PNG /, io.read)
    }
  end

end
