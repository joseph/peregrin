module Peregrin

  VERSION = "1.0.0"

  # Required libraries
  require 'fileutils'
  require 'uri'
  require 'zipruby'
  require 'nokogiri'
  require 'mime/types'

  # Require libs in this directory
  [
    "peregrin/zip_patch",
    "peregrin/book",
    "peregrin/resource",
    "peregrin/component",
    "peregrin/chapter",
    "peregrin/property",
    "peregrin/componentizer",
    "peregrin/outliner",
    "formats/epub",
    "formats/zhook",
    "formats/ochook"
  ].each { |lib|
    require lib
  }


  class Main

    def self.run(args)
      if args.size == 1
        src = args.first
        validate(src) and inspect(src)
      elsif args.size == 2
        src, dest = args
        validate(src) and convert(src, dest) and inspect(dest)
      else
        usage
      end
    end


    def self.usage
      puts "Peregrin [http://ochook.org/peregrin]"
      puts "Version: #{VERSION}"
      puts "A tool for inspecting Zhooks, Ochooks and EPUB ebooks,"
      puts "and converting between them."
      puts ""
      puts "Usage: peregrin srcpath [destpath]"
      puts ""
      puts "If one path given, validates ebook at that path and outputs analysis."
      puts "If two paths given, converts from srcpath to destpath and outputs "
      puts "analysis of converted ebook."
    end


    def self.validate(path)
      klass = format_for_path(path)
      klass.validate(path)
      true
    rescue UnknownFileFormat => e
      exit_with("Unknown file format: #{path}")
    rescue => e
      exit_with("Invalid #{klass::FORMAT}: #{path}", "Reason - #{e}")
    end


    def self.convert(src_path, dest_path, src_klass = nil, dest_klass = nil)
      src_klass ||= format_for_path(src_path)
      dest_klass ||= format_for_path(dest_path)

      src_ook = src_klass.read(src_path)

      # FIXME: how do we do these options? User-specified? Dest-format-specified?
      options = {}
      options[:componentize] = true  if dest_klass == Peregrin::Epub
      book = src_ook.to_book(options)

      dest_ook = dest_klass.new(book)
      dest_ook.write(dest_path)
      validate(dest_path)
    end


    def self.inspect(path)
      klass = format_for_path(path)
      ook = klass.read(path)
      book = ook.to_book
      puts "[#{klass::FORMAT}]"
      puts "\nCover\n  #{book.cover.src}"
      puts "\nComponents [#{book.components.size}]"
      book.components.each { |cmpt| puts "  #{cmpt.src}" }
      puts "\nResources [#{book.resources.size}]"
      book.resources.each { |res| puts "  #{res.src}" }
      puts "\nChapters"
      book.chapters.each { |chp| print_chapter_title(chp, "- ") }
      puts "\nProperties [#{book.properties.size}]"
      book.properties.each { |property|
        puts "  #{property.key}: #{property.value}"  unless property.value.empty?
      }
      true
    end


    private

      def self.format_for_path(path)
        return Peregrin::Zhook  if File.extname(path) == ".zhook"
        return Peregrin::Epub  if File.extname(path) == ".epub"
        return Peregrin::Ochook  if File.directory?(path) || !File.exists?(path)
        raise UnknownFileFormat.new(path)
      end


      def self.exit_with(*remarks)
        remarks.each { |rm| puts(rm) }
        false
      end


      def self.print_chapter_title(chp, padd)
        puts "#{padd}#{chp.title}"
        chp.children.each { |ch|
          print_chapter_title(ch, "  "+padd)
        }
      end



    class UnknownFileFormat < RuntimeError
      def initialize(path = nil)
        @page = path
      end
    end

  end

end
