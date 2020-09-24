require_relative "./errors"
class Grammaphone
  # This is not a descendant of Enumerator. This is explicit and intentional, 
  # due to use as an almost tree-like object. This implementation makes it behave 
  # as a near-functional list structure, which is extremely useful for this parser.
  class TokenStream
    # This doesn't need to be here, but it could potentially be useful
    include Enumerable

    # Creates a new instance of TokenStream, using the data from `tokens`. If
    # `tokens` is a String, it's split using `split_method`, which takes a 
    # String and returns an Array. if `split_method` isn't provided, then 
    # `String#split` is called on `tokens`, using the space character as the 
    # separator.
    #
    # If `tokens` is an Array of Strings, the Array is duplicated, and used 
    # directly.
    #
    # If `tokens` is not a String or Array, then `to_a` is called on `tokens` 
    # and the result is used as the token stream.
    def initialize(tokens, &split_method)
      case tokens
      when String
        if split_method.nil?
          @enum = tokens.split(" ")
        else
          @enum = split_method.call(tokens).to_a
        end
      when Array
        raise TokenStreamError unless tokens.all?{|t| t.kind_of?(String)}
        @enum = tokens.dup
      else
        raise TokenStreamError unless tokens.respond_to?(:to_a)
        @enum = tokens.to_a.dup # dup just in case
      end
      @pointer = 0
    end

    # This ensures that all instances refer to the exact same token stream, 
    # but not necessarily at the same point. This saves a great deal of 
    # memory, without risking stream data integrity.
    def initialize_copy(orig)
      @enum = orig.instance_variable_get(:@enum)
      super
    end

    # Gets the next non-empty token, consuming all viewed tokens.
    #
    # Follows the same relationship as `peek` and `peek_token`
    def next
      token = next_token
      token = next_token while token&.empty?
      token
    end

    # Gets the next token, consuming it.
    def next_token
      token = @enum[@pointer]
      raise NonstringTokenError unless token.nil? || token.kind_of?(String) 
      @pointer += 1
      token
    end

    # Peeks at the nth token from the current pointer, not counting empty tokens, 
    # not consuming any tokens.
    #
    # if no count is given, deaults to the next immediate token.
    #
    # Follows the same relationship as `next` and `next_token`
    def peek(n = 0)
      offset = (0..n).inject(0) do |acc, p|
        peek_token(p)&.empty? ? acc + 1 : acc
      end
      peek_token(n + offset)
    end

    # Peeks at the nth token from the current pointer, not consuming it.
    #
    # If no count is given, defaults to the next immediate token.
    def peek_token(n = 0)
      raise ArgumentError.new("can't look back in the token stream") if n < 0
      @enum[@pointer + n]
    end

    # Consumes the next n tokens, returning `self`.
    #
    # This has no meaningful effect if the stream is empty.
    #
    # If no count is given, defaults to consuming a single token
    def skip(n = 1)
      @pointer += n
      self
    end

    # Resets the pointer to the beginning of the token stream.
    def reset
      @pointer = 0
      self
    end

    # Returns `true` if there are no tokens remaining in the stream and `false` 
    # otherwise. That is, any calls to `peek_token`, `peek`, `next_token`, or 
    # `next` are guaranteed to return `nil` if `empty?` returns `true`.
    def empty?
      @pointer >= @enum.size
    end

    # Provided because there's a chance that it'll be useful. At the very least, 
    # it can't hurt, since any arrays produced are copies.
    def each
      if block_given?
        @enum.each { |t| yield t }
        self
      else
        to_enum(:each)
      end
    end

    # Returns the remaining tokens as an Array.
    def to_a
      @enum[@pointer..].dup
    end
  end

  # Token contains methods that classify what kind of element type a specific 
  # rule pattern is.
  module Token
    # The prefix used to denote a literal element.
    LITERAL_PREFIX = "\""

    # Checks if an element expects a literal value. A literal element is 
    # denoted by being prefixed by the value of `LITERAL_PREFIX`.
    def self.literal?(token)
      token[0] == LITERAL_PREFIX
    end

    # Removes the denotative marks of a literal, and returns the resulting value.
    def self.clean_literal(token)
      token[1..]
    end

    # Returns whether the token is described by the element and that the 
    # element is a literal.
    #
    # Returns `false` if the token is `nil`, since it's impossible to match a 
    # literal `nil`. Note, `nil` differs from an empty token.
    def self.matches_literal?(element, token)
      !token.nil? && literal?(element) && token == clean_literal(element)
    end

    # Checks if an element expects a pattern value. A pattern element is 
    # denoted by being surrounded by forward slashes.
    def self.pattern?(token)
      token[0] == "/" && token[-1] == "/"
    end

    # Removes the denotative marks of a pattern, and returns a Regexp that 
    # matches the pattern exactly. That is, the pattern describes the 
    # whole token, and nothing less.
    def self.clean_pattern(token)
      /\A#{token[1...-1]}\Z/
    end

    # Returns whether the token is described by the element and that the 
    # element is a pattern.
    #
    # Returns `false` if the token is `nil`, and the pattern doesn't match 
    # the empty string.
    def self.matches_pattern?(element, token)
      pattern?(element) && (token =~ clean_pattern(element)) ||
        token.nil? && "" =~ clean_pattern(element)
    end
  end
end
