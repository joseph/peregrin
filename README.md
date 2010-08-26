# Peregrin

A library for inspecting Zhooks, Ochooks and EPUB ebooks, and converting
between them.

Invented by [Inventive Labs](http://inventivelabs.com.au). Released under the
MIT license.

More info: http://ochook.org/peregrin


## Requirements

Ruby, at least 1.8.x.

You must have ImageMagick installed — specifically, you must have the 'convert'
utility provided by ImageMagick somewhere in your PATH.

Required Ruby gems:

* rubyzip
* nokogiri


## Peregrin from the command-line

You can use Peregrin to inspect a Zhook, Ochook or EPUB file from the
command-line. It will perform very basic validation of the file and
output an analysis.

    $ peregrin strunk.epub
    [EPUB]
    Components:
      main0.xml
      main1.xml
      main2.xml
      main3.xml
      main4.xml
      main5.xml
      main6.xml
      main7.xml
      main8.xml
      main9.xml
      main10.xml
      main11.xml
      main12.xml
      main13.xml
      main14.xml
      main15.xml
      main16.xml
      main17.xml
      main18.xml
      main19.xml
      main20.xml
      main21.xml
    Media: 1
      css/main.css
    Cover: cover.png
    Metadata:
      title: The Elements of Style
      creator: William Strunk Jr.
      cover: cover
      language: en
      identifier: 8102537c96

Note that file type detection is quite naive — it just uses the path extension,
and if the extension is not .zhook or .epub, it assumes the path is an
Ochook directory.

You can also use Peregrin to convert from one format to another. Just provide
two paths to the utility; it will convert from the first to the second.

    $ peregrin strunk.epub strunk.zhook
    [Zhook]
    Components:
      index.html
    Media: 2
      css/main.css
      cover.png
    Cover: cover.png
    Metadata:
      title: The Elements of Style
      creator: William Strunk Jr.
      cover: cover
      language: en
      identifier: e4603149df00

## Library usage

The three formats are represented in the Peregrin::Epub, Peregrin::Zhook and
Peregrin::Ochook classes. Each format class responds to the following methods:

  * validate(path)
  * read(path) - creates an instance of the class from the path
  * new(book) - creates an instance of the class from a Peregrin::Book

Each instance of a format class responds to the following methods:

  * write(path)
  * to_book(options) - returns a Peregrin:Book object

Here's what a conversion routine might look like:

   zhook = Peregrin::Zhook.read('foo.zhook')
   epub = Peregrin::Epub.new(zhook.to_book(:componentize => true))
   epub.write('foo.epub')

## Peregrin::Book

Between the three supported formats, there is an abstracted concept of "book"
data, which holds the following information:

* components - an array of files that make up the linear content
* contents - an array of chapters (with titles, hrefs and children)
* metadata - a hash of key/value pairs
* media - an array of files contained in the ebook, other than components
* cover - the media file that should be used as the cover of the ebook

There will probably be some changes to the shape of this data over the
development of Peregrin, to ensure that the Book interchange object retains all
relevant information about an ebook without lossiness. But for the moment,
it's being kept as simple as possible.


## Peregrin?

All this rhyming on "ook" put me in mind of the Took family. There is no
deeper meaning.
