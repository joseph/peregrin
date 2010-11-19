# Books have nested sections with headings - each of these is a chapter.
#
# TODO: flag whether a chapter is linkable?
#
class Peregrin::Chapter

  attr_accessor :title, :src, :children

  def initialize(title, src = nil)
    @title = title.gsub(/[\r\n]/,' ')  if title
    @src = src
    @children = []
  end


  def add_child(child_title, child_src)
    chp = Peregrin::Chapter.new(child_title, child_src)
    children.push(chp)
    chp
  end


  # A chapter is an empty leaf if you can't link to it or any of its children.
  # Typically you wouldn't show an empty-leaf chapter in a Table of Contents.
  #
  def empty_leaf?
    src.nil? && children.all? { |ch| ch.empty_leaf? }
  end

end
