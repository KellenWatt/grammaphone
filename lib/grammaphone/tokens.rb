require_relative "./errors"
class Grammaphone
  # This is not a descendant of Enumerator. This is explicit and intentional, 
  # due to use as an almost tree-like object. This implementation makes it behave 
  # as a near-functional list structure, which is extremely useful for this parser.
  class TokenStream
    # This doesn't need to be here, but it could potentially be useful
    include Enumerable

    def initialize(tokens, &split_method)
      case tokens
      when String
        if split_method.nil?
          @enum = tokens.split(" ")
        else
          @enum = split_method.call(tokens).to_a
        end
      when Array
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

  module Token
    LITERAL_PREFIX = "\""

    def self.literal?(token)
      token[0] == LITERAL_PREFIX
    end

    def self.clean_literal(token)
      token[1..]
    end

    def self.matches_literal?(element, token)
      !token.nil? && literal?(element) && token == clean_literal(element)
    end

    def self.pattern?(token)
      token[0] == "/" && token[-1] == "/"
    end

    def self.clean_pattern(token)
      /\A#{token[1...-1]}\Z/
    end

    def self.matches_pattern?(element, token)
      pattern?(element) && (token =~ clean_pattern(element)) ||
        token.nil? && "" =~ clean_pattern(element)
    end
  end
end
