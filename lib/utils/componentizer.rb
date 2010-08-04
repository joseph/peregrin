class Peregrin::Componentizer

  attr_reader :component_xpaths


  def initialize(doc)
    @document = doc
    @component_xpaths = []
  end


  # Build a list of xpaths for nodes that can be turned into standalone
  # components.
  #
  def process(from)
    @component_xpaths = []
    walk(from)
    @component_xpaths.reject! { |xpath| emptied?(xpath) }
  end


  # Creates a new document with the same root and head nodes, but with
  # a body that just contains the nodes at the given xpath.
  #
  def generate_component(xpath)
    raise "Not a component: #{xpath}"  unless @component_xpaths.include?(xpath)

    # Clean up the "shell" document.
    @shell_document ||= @document.dup
    bdy = @shell_document.at_css('body')
    bdy.children.remove

    # Find the node we're going to copy into the shell document.
    # Create a deep clone of it. Remove any children of it that are
    # componentizable in their own right.
    node = @document.at_xpath(xpath)
    ndup = node.dup
    node.children.collect { |ch|
      next  unless component_xpaths.include?(ch.path)
      dpath = ch.path.sub(/^#{Regexp.escape(node.path)}/, ndup.path)
      ndup.children.detect { |dch| dch.path == dpath }
    }.compact.each { |ch|
      ch.unlink
    }

    # Append the node to the body of the shell (or replace the body, if
    # the node is a body itself).
    if xpath == "/html/body"
      bdy.replace(ndup)
    else
      bdy.add_child(ndup)
    end

    @shell_document
  end


  # Writes the componentizable node at the given xpath to the given
  # filesystem path.
  #
  # If you provide a block, you get the new document object,
  # and you are expected to return the string containing its HTML form --
  # in this way you can tweak the HTML output. Default is simply: doc.to_html
  #
  def write_component(xpath, path, &blk)
    new_doc = generate_component(xpath)
    out = block_given? ? blk.call(new_doc) : new_doc.to_html
    File.open(path, 'w') { |f| f.write(out) }
    out
  end


  protected

    # The recursive method for walking the tree - checks if the current node
    # is a component, then checks each child of the current node.
    #
    def walk(node)
      return  unless componentizable?(node)
      @component_xpaths.push(node.path)
      node.children.each { |c| walk(c) }
    end


    # True if the node meets the criteria for being componentizable:
    #   1) Is a body or article element (or a div.article)?
    #   2) Are all subsequent siblings also componentizable?
    #
    def componentizable?(node)
      begin
        return false  unless (
          %w[body article].include?(node.name.downcase) ||
          (node.name.downcase == "div" && node['class'].match(/\barticle\b/))
        )
      end while node = node.next
      true
    end


    # True if all children are either componentizable or blank text nodes.
    #
    def emptied?(xpath)
      node = @document.at_xpath(xpath)
      node.children.all? { |ch|
        @component_xpaths.include?(ch.path) ||
        (ch.text? && ch.content.strip.empty?)
      }
    end

end
