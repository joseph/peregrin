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

* zipruby
* nokogiri
* mime-types


## Peregrin from the command-line

You can use Peregrin to inspect a Zhook, Ochook or EPUB file from the
command-line. It will perform very basic validation of the file and
output an analysis.

    $ peregrin strunk.epub
    [EPUB]

    Cover
      images/cover.png

    Components [10]
      cover.xml
      title.xml
      about.xml
      main0.xml
      main1.xml
      main2.xml
      main3.xml
      main4.xml
      main5.xml
      main6.xml

    Resources [2]
      css/main.css
      images/cover.png

    Chapters
    - Title
    - About
    - Chapter 1 - Introductory
    - Chapter 2 - Elementary Rules of Usage
    - Chapter 3 - Elementary Principles of Composition
    - Chapter 4 - A Few Matters of Form
    - Chapter 5 - Words and Expressions Commonly Misused
    - Chapter 6 - Words Commonly Misspelled

    Properties [5]
      title: The Elements of Style
      identifier: urn:uuid:6f82990c-9394-11df-920d-001cc0a62c0b
      language: en
      creator: William Strunk Jr.
      subject: Non-Fiction

Note that file type detection is quite naive — it just uses the path extension,
and if the extension is not .zhook or .epub, it assumes the path is an
Ochook directory.

You can also use Peregrin to convert from one format to another. Just provide
two paths to the utility; it will convert from the first to the second.

    $ peregrin strunk.epub strunk.zhook
    [Zhook]
    Cover
      cover.png

    Components [1]
      index.html

    Resources [2]
      css/main.css
      cover.png

    Chapters
    - Title
    - About
    - Chapter 1 - Introductory
    - Chapter 2 - Elementary Rules of Usage
    - Chapter 3 - Elementary Principles of Composition
    - Chapter 4 - A Few Matters of Form
    - Chapter 5 - Words and Expressions Commonly Misused
    - Chapter 6 - Words Commonly Misspelled

    Properties [5]
      title: The Elements of Style
      identifier: urn:uuid:6f82990c-9394-11df-920d-001cc0a62c0b
      language: en
      creator: William Strunk Jr.
      subject: Non-Fiction


## Library usage

The three formats are represented in the Peregrin::Epub, Peregrin::Zhook and
Peregrin::Ochook classes. Each format class responds to the following methods:

  * validate(path)
  * read(path) - creates an instance of the class from the path
  * new(book) - creates an instance of the class from a Peregrin::Book

Each instance of a format class responds to the following methods:

  * write(path)
  * to\_book(options) - returns a Peregrin:Book object

Here's what a conversion routine might look like:

   zhook = Peregrin::Zhook.read('foo.zhook')
   epub = Peregrin::Epub.new(zhook.to\_book(:componentize => true))
   epub.write('foo.epub')

## Peregrin::Book

Between the three supported formats, there is an abstracted concept of "book"
data, which holds the following information:

* components - an array of Components that make up the linear content
* chapters - an array of Chapters (with title, src and children)
* properties - an array of Property metadata tuples (key/value + attributes)
* resources - an array of Resources contained in the ebook, other than components
* cover - the Resource that should be used as the cover of the ebook

There will probably be some changes to the shape of this data over the
development of Peregrin, to ensure that the Book interchange object retains all
relevant information about an ebook without lossiness. But for the moment,
it's being kept as simple as possible.


## Peregrin?

All this rhyming on "ook" put me in mind of the Took family. There is no
deeper meaning.


## History

* 1.1.4 - Basic EPUB3 and EPUB fixed-layout read support (thanks @klacointe!)
