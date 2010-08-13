module Peregrin

  VERSION = "1.0.0"

  # Required gems
  require 'zip/zip'  # Name of gem is "rubyzip"
  require 'zip/zipfilesystem'
  require 'nokogiri'

  # Require libs in this directory
  [
    "book",
    "utils/componentizer",
    "utils/outliner",
    "formats/epub",
    "formats/zhook",
    "formats/ochook"
  ].each { |lib|
    require File.join(File.dirname(__FILE__), lib)
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
      puts "TODO: usage"
    end


    def self.validate(path)
      klass = format_for_path(path)
      klass.validate(path)
      true
    rescue UnknownFileFormat => e
      exit_with("Unknown file format: #{path}")
    rescue => e
      exit_with("Invalid #{klass::FORMAT}: #{path}", "Reason — "+e.to_s)
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
      puts "Components:"
      book.components.each { |cmpt| puts "  #{cmpt.keys.first}" }
      puts "Media: #{book.media.size}"
      book.media.each { |mpath| puts "  #{mpath}" }
      puts "Cover: #{book.cover}"
      puts "Metadata:"
      book.metadata.each_pair { |name, content|
        puts "  #{name}: #{content}"  unless content.empty?
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


    class UnknownFileFormat < RuntimeError
      def initialize(path = nil)
        @page = path
      end
    end

  end

end
