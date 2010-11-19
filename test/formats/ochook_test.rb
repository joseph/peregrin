require 'test_helper'

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
    assert_equal("index.html", book.components.first.src)
    assert_equal(['cover.png'], book.resources.collect { |res| res.src })
    assert_equal("A Basic Ochook", book.property_for('title'))
    assert_equal(1, book.chapters.size)

    chp = book.chapters.first
    assert_equal("A Basic Ochook", chp.title)
    assert_equal("index.html", chp.src)
    assert_equal("Part One", chp.children[0].title)
    assert_equal("index.html#part1", chp.children[0].src)
    assert_equal("Part Two", chp.children[1].title)
    assert_equal("index.html#part2", chp.children[1].src)
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


  def test_to_book_cover_html
    ook = Peregrin::Ochook.read("test/fixtures/ochooks/illustrated")
    book = ook.to_book(:componentize => true)
    cov_html = book.components.detect { |cmpt|
      cmpt.src == "cover.html"
    }.contents
    doc = Nokogiri::HTML::Document.parse(cov_html)
    assert_equal('cover.png', doc.at_xpath('/html/body/div/img')['src'])
  end


  def test_to_book_toc_html
    ook = Peregrin::Ochook.read("test/fixtures/ochooks/illustrated")
    book = ook.to_book(:componentize => true)
    toc_html = book.components.detect { |cmpt| cmpt.src == "toc.html" }.contents
    doc = Nokogiri::HTML::Document.parse(toc_html)
    assert_equal(3, doc.xpath('/html/body/ol/li').size)
  end


  def test_to_book_loi_html
    ook = Peregrin::Ochook.read("test/fixtures/ochooks/illustrated")
    book = ook.to_book(:componentize => true)
    loi_html = book.components.detect { |cmpt| cmpt.src == "loi.html" }.contents
    doc = Nokogiri::HTML::Document.parse(loi_html)
    assert_equal(2, doc.xpath('/html/body/ol/li').size)
  end


  def test_to_book_rel_links
    ook = Peregrin::Ochook.read("test/fixtures/ochooks/illustrated")
    book = ook.to_book(:componentize => true)
    cmpt_html = book.components[3].contents
    doc = Nokogiri::HTML::Document.parse(cmpt_html)
    assert_equal(
      "cover.html",
      doc.at_xpath('/html/head/link[@rel="start"]')['href']
    )
    assert_equal(
      "toc.html",
      doc.at_xpath('/html/head/link[@rel="contents"]')['href']
    )
    assert_equal(
      "index.html",
      doc.at_xpath('/html/head/link[@rel="first"]')['href']
    )
    assert_equal(
      "part002.html",
      doc.at_xpath('/html/head/link[@rel="last"]')['href']
    )
    assert_equal(
      "part001.html",
      doc.at_xpath('/html/head/link[@rel="prev"]')['href']
    )
  end

end
