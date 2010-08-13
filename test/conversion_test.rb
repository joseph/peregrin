require 'test/helper'

class Peregrin::Tests::ConversionTest < Test::Unit::TestCase

  def test_epub_to_ochook
    conversion_test(
      Peregrin::Epub,
      Peregrin::Ochook,
      'test/fixtures/epubs/strunk.epub',
      'test/output/conversions/epub_to_ochook'
    )
  end


  def test_epub_to_zhook
    conversion_test(
      Peregrin::Epub,
      Peregrin::Zhook,
      'test/fixtures/epubs/strunk.epub',
      'test/output/conversions/epub_to_zhook.zhook'
    )
  end


  def test_ochook_to_epub
    conversion_test(
      Peregrin::Ochook,
      Peregrin::Epub,
      'test/fixtures/ochooks/basic',
      'test/output/conversions/ochook_to_epub.epub',
      :componentize => true
    )
  end


  def test_ochook_to_zhook
    conversion_test(
      Peregrin::Ochook,
      Peregrin::Zhook,
      'test/fixtures/ochooks/basic',
      'test/output/conversions/ochook_to_zhook.zhook',
      :componentize => true
    )
    assert_nil(@dest_ook.send(:index).root['manifest'])
  end


  def test_zhook_to_epub
    conversion_test(
      Peregrin::Zhook,
      Peregrin::Epub,
      'test/fixtures/zhooks/flat.zhook',
      'test/output/conversions/zhook_to_epub.epub',
      :componentize => true
    )
  end


  def test_zhook_to_ochook
    conversion_test(
      Peregrin::Zhook,
      Peregrin::Ochook,
      'test/fixtures/zhooks/flat.zhook',
      'test/output/conversions/zhook_to_ochook',
      :componentize => true
    )
  end


  private

    def conversion_test(src_klass, dest_klass, src, dest, to_book_options = {})
      @src_ook = src_klass.read(src)
      @dest_ook = dest_klass.new(@src_ook.to_book(to_book_options))
      FileUtils.mkdir_p(File.dirname(dest))
      @dest_ook.write(dest)
      assert_nothing_raised { dest_klass.validate(dest) }
    end

end
