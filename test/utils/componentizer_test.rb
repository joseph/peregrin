require 'test_helper'

class Peregrin::Tests::ComponentizerTest < Test::Unit::TestCase

  def test_processing
    cz = process_fixture("components1.html")
    assert_equal(
      [
        '/html/body',
        '/html/body/article[1]',
        '/html/body/article[1]/article[1]',
        '/html/body/article[1]/article[2]',
        '/html/body/article[2]'
      ],
      cz.component_xpaths
    )
  end


  def test_processing_where_body_should_be_empty
    cz = process_fixture("components2.html")
    assert_equal(
      [
        '/html/body/article[1]',
        '/html/body/article[1]/article[1]',
        '/html/body/article[1]/article[2]',
        '/html/body/article[2]',
        '/html/body/article[2]/article'
      ],
      cz.component_xpaths
    )
  end


  def test_generate_component
    cz = process_fixture("components1.html")
    assert_equal(
      whitewash(
        "<!DOCTYPE html>" +
        "<html><head><title>Components test 1</title></head><body>" +
        "<article><h2>B</h2></article>" +
        "</body></html>"
      ),
      whitewash(cz.generate_component('/html/body/article[1]').to_html)
    )
  end


  def test_write_component
    cz = process_fixture("components1.html")
    tmp_path = "test/fixtures/componentizer/tmp.html"
    cz.write_component("/html/body", tmp_path) { |doc| doc.to_xhtml }
    assert_equal(
      whitewash(
        "<!DOCTYPE html>" +
        '<html xmlns="http://www.w3.org/1999/xhtml"><head>' +
        '<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />' +
        "<title>Components test 1</title></head>" +
        "<body><h1>A</h1></body></html>"
      ),
      whitewash(IO.read(tmp_path))
    )
  ensure
    File.unlink(tmp_path)
  end


  protected

    def process_fixture(filename)
      fx = File.new("test/fixtures/componentizer/#{filename}")
      doc = Nokogiri::HTML::Document.parse(fx)
      cz = Peregrin::Componentizer.new(doc)
      cz.process(doc.at_xpath('/html/body'))
      cz
    end

end
