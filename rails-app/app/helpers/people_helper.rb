module PeopleHelper
  def itemscope obj, &block
    Slim::Parser.current_itemscope = obj
    content_tag "div", block.call
  end
end

module Slim
  class Parser
    cattr_accessor :current_itemscope

    private
      ATTR_SHORTHAND = {
        '#' => 'id',
        '.' => 'class',
        '@' => 'itemprop'
      }.freeze

      if RUBY_VERSION > '1.9'
        # CLASS_ID_REGEX = /^(#|\.)([\w\u00c0-\uFFFF][\w:\u00c0-\uFFFF-]*)/
      else
        CLASS_ID_REGEX = /^(#|\.|\@)(\w[\w:-]*)/
      end


    def parse_tag(line, lineno)

      orig_line = line
      content = [:multi]
      case line
      when /^[#\.]/
        tag = 'div'
      when /^\w[:\w-]*/
        tag = $&
        line = $'
      else
        syntax_error! 'Unknown line indicator', orig_line, lineno
      end

      # Now we'll have to find all the attributes. We'll store these in an
      # nested array: [[name, value], [name2, value2]]. The value is a piece
      # of Ruby code.
      attributes = [:html, :attrs]

      # Find any literal class/id attributes
      while line =~ CLASS_ID_REGEX
        # The class/id attribute is :static instead of :slim :text,
        # because we don't want text interpolation in .class or #id shortcut
        attributes << [:html, :attr, ATTR_SHORTHAND[$1], [:static, $2]]
        # attributes << [:html, :attr, ATTR_SHORTHAND[$1], [:static, $2]]
        # content = "A"
        if $1 == '@' and self.current_itemscope
          content << [:slim, :interpolate, self.current_itemscope.send($2)]
        end
        line = $'
      end

      # Check to see if there is a delimiter right after the tag name
      delimiter = ''
      if line =~ DELIMITER_REGEX
        delimiter = DELIMITERS[$&]
        # Replace the delimiter with a space so we can continue parsing as normal.
        line[0] = ?\s
      end

      # Parse attributes
      while line =~ ATTR_REGEX
        name = $1
        line = $'
        if line =~ QUOTED_VALUE_REGEX
          # Value is quoted (static)
          line = $'
          attributes << [:html, :attr, name, [:slim, :interpolate, $1[1..-2]]]
        else
          # Value is ruby code
          escape = line[0] != ?=
          line, code = parse_ruby_attribute(orig_line, escape ? line : line[1..-1], lineno, delimiter)
          attributes << [:slim, :attr, name, escape, code]
        end
      end

      # Find ending delimiter
      unless delimiter.empty?
        if line =~ /^\s*#{Regexp.escape delimiter}/
          line = $'
        else
          syntax_error! "Expected closing delimiter #{delimiter}", orig_line, lineno, orig_line.size - line.size
        end
      end

      tag = [:html, :tag, tag, attributes, content]

      if line =~ /^\s*=(=?)/
        # Handle output code
        block = [:multi]
        broken_line = $'.strip
        content << [:slim, :output, $1 != '=', broken_line, block]
        [tag, block, broken_line, nil]
      elsif line =~ /^\s*\//
        # Closed tag
        tag.pop
        [tag, block, nil, nil]
      elsif line =~ /^\s*$/
        # Empty line
        [tag, content, nil, nil]
      else
        # Handle text content
        content << [:slim, :interpolate, line.sub(/^( )/, '')]
        [tag, content, nil, orig_line.size - line.size + ($1 ? 1 : 0)]
      end
    end

  end
end