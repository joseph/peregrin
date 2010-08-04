class Peregrin::Outliner

  REGEXES = {
    :section_root => /^BLOCKQUOTE|BODY|DETAILS|FIELDSET|FIGURE|TD$/i,
    :section_content => /^ARTICLE|ASIDE|NAV|SECTION$/i,
    :heading => /^H[1-6]|HGROUP$/i
  }

  class Utils

    def self.section_root?(el)
      element_name_is?(el, REGEXES[:section_root])
    end


    def self.section_content?(el)
      element_name_is?(el, REGEXES[:section_content])
    end


    def self.heading?(el)
      element_name_is?(el, REGEXES[:heading])
    end


    def self.named?(el, name)
      element_name_is?(el, /^#{name}$/)
    end


    def self.heading_rank(el)
      raise "Not a heading: #{el.inspect}"  unless heading?(el)
      if named?(el, 'HGROUP')
        1.upto(6) { |n| return n  if el.at_css("h#{n}") }
        return 6 #raise "Heading not found in HGROUP: #{el.inspect}"
      else
        el.name.reverse.to_i
      end
    end


    def self.element_name_is?(el, pattern)
      return false  unless el
      return false  unless el.respond_to?(:name)
      return false  if el.name.nil? || el.name.empty?
      el.name.upcase.match(pattern) ? true : false
    end

  end


  class Section

    attr_accessor :sections, :heading, :container, :node


    def initialize(node = nil)
      self.node = node
      self.sections = []
    end


    def append(subsection)
      subsection.container = self
      sections.push(subsection)
    end


    def empty?
      heading_text.nil? && sections.all? { |sxn| sxn.empty? }
    end


    def heading_text
      return nil  unless Utils.heading?(heading)
      h = heading
      h = h.at_css("h#{Utils.heading_rank(h)}")  if Utils.named?(h, 'HGROUP')
      return  nil  unless h && !h.content.strip.empty?
      h.content.strip
    end


    def heading_rank
      # FIXME: some doubt as to whether 1 is the sensible default
      Utils.heading?(heading) ? Utils.heading_rank(heading) : 1
    end

  end



  def initialize(doc)
    @document = doc
  end


  def process(from)
    @outlinee = nil
    @outlines = {}
    @section = Section.new
    @stack = []
    walk(from)
  end


  def walk(node)
    return  unless node
    enter_node(node)
    node.children.each { |ch| walk(ch) }
    exit_node(node)
  end


  def enter_node(node)
    return  if Utils.heading?(@stack.last)

    if Utils.section_content?(node) || Utils.section_root?(node)
      @stack.push(@outlinee)  unless @outlinee.nil?
      @outlinee = node
      @section = Section.new(node)
      @outlines[@outlinee] = Section.new(node)
      @outlines[@outlinee].sections = [@section]
      return
    end

    return  if @outlinee.nil?

    if Utils.heading?(node)
      node_rank = Utils.heading_rank(node)
      if !@section.heading
        @section.heading = node
      elsif node_rank <= @outlines[@outlinee].sections.last.heading_rank
        @section = Section.new
        @section.heading = node
        @outlines[@outlinee].sections.push(@section)
      else
        candidate = @section
        while true
          if node_rank > candidate.heading_rank
            @section = Section.new
            candidate.append(@section)
            @section.heading = node
            break
          end
          candidate = candidate.container
        end
      end
      @stack.push(node)
    end
  end


  def exit_node(node)
    if Utils.heading?(@stack.last)
      @stack.pop  if @stack.last == node
      return
    end

    if Utils.section_content?(node) && !@stack.empty?
      @outlinee = @stack.pop
      @section = @outlines[@outlinee].sections.last
      @outlines[node].sections.each { |s| @section.append(s) }
      return
    end

    if Utils.section_root?(node) && !@stack.empty?
      @outlinee = @stack.pop
      @section = @outlines[@outlinee].sections.last
      while @section.sections.any?
        @section = @section.sections.last
      end
      return
    end

    if Utils.section_content?(node) || Utils.section_root?(node)
      @section = @outlines[@outlinee].sections.first
      return
    end
  end


  def to_html
    curse = lambda { |section, is_root|
      below = section.sections.collect { |ch|
        ch_out = curse.call(ch, false).strip
        (ch_out.nil? || ch_out.empty?) ? "" : "<li>#{ch_out}</li>"
      }.join.strip
      below = (below.nil? || below.empty?) ? "" : "<ol>#{below}</ol>\n"
      if is_root
        below
      else
        heading = block_given? ? yield(section, below) : section.heading_text
        "#{heading}#{below}"
      end
    }
    curse.call(result_root, true)
  end


  def result_root
    @outlines[@outlinee]
  end

end
