require 'test_helper'

class Peregrin::Tests::OutlinerTest < Test::Unit::TestCase

  def test_spec_1
    load_spec_and_compare_out('spec1')
  end


  def test_spec_2
    load_spec_and_compare_out('spec2') { |section, below|
      if section.heading_text
        section.heading_text
      elsif section.node
        "<i>Untitled #{section.node.name.upcase}</i>"
      end
    }
  end


  def test_spec_3a
    load_spec_and_compare_out('spec3a')
  end


  def test_spec_3b
    load_spec_and_compare_out('spec3b')
  end


  def test_spec_4
    load_spec_and_compare_out('spec4')
  end


  protected

    def load_spec_and_compare_out(spec_name, &blk)
      src_file = File.new("test/fixtures/outliner/#{spec_name}.doc.html")
      cmp_file = File.new("test/fixtures/outliner/#{spec_name}.out.html")
      doc = Nokogiri::HTML::Document.parse(src_file)
      outliner = Peregrin::Outliner.new(doc.root)
      outliner.process(doc.root)
      out = outliner.to_html(&blk)
      cmp = cmp_file.read
      assert_equal(whitewash(cmp), whitewash(out))
    end

end
