require_relative "grammaphone/errors"
require_relative "grammaphone/tokens"
require_relative "grammaphone/rule"

# Grammaphone is a dynamically-definable parser pseudo-generator based on a 
# BNF-like grammar.
#
# ### Grammar
# A grammar is defined using key-value pairs in a hash. This is viewed as a 
# names with associated sets of patterns it can match against. A name can be 
# any sequence of characters that are valid in a Ruby String (i.e. any Unicode 
# character). Similarly, the patterns can be composed of any Ruby-valid characters.
#
# ### Writing a Rule
# A rule is a list of element identifiers, separated by spaces (`" "` or `\x20`).
#
# Element identifiers fall into three categories: literals, patterns, and rules.
#
# A literal is a string of characters that will be matched iff the token matches 
# the literal text *exactly*. Literal sequences are preceeded by one double-quote 
# (`"` or `\x22`). For example, to match the exact string "hello", the literal 
# string you would use is `"hello`. Note that the initial double-quote is not 
# included in the literal itself.
#
# A pattern is a string of characters representing a Ruby-valid regex. Pattern 
# sequences are surrounded by one forward slash (`"/"` or `\x2F`) on each end. 
# For example, to match a capitalized name composed strictly of ASCII letters, 
# (e.g. "April", "John", "Alex"), the pattern string could be `/[A-Z][a-z]*/`. 
# Note that every pattern must strictly match the whole token. Anything else 
# won't be matched.
#
# A rule identifier is a string of characters representing the name of a grammatical 
# rule. Rule identifier sequences are trivial, and are specified by using the 
# exact name of the rule with no decorations. For example, to reference a rule 
# named "NUMBER", the Rule string is `NUMBER`. Note that, like any grammar, a rule 
# can refer to itself to define a recursive pattern. If a rule name is specified 
# that doesn't exist in the current grammar, an exception will be raised and 
# parsing will immediately stop.
#
# A rule is composed of zero or more element identifiers, which are evaluated in 
# order. If a rule has no identifiers, then it will only match an empty token 
# list, which will always succeed.
#
# Multiple options for a rule can be specified by passing an Array where each 
# element of the Array is a valid rule. These rules are treated as possibilities 
# for matching, with a precedence specified by the order.
#
# #### Example
# The two most common introductory programs are "Hello, world!", and an 
# introduction program, given a name. For the purposes of this example, the latter
# prints in the format "Hello, \<name\>!", where `<name>` is the name entered.
#
# The following Hash describes the grammar that matches the output of these programs, 
# assuming they are tokenized as ["Hello", ",", " ", \<name\>/world, "!"]. That 
# tokenization is not default, but is assumed for the purposes of this example. 
# This is by no means the only possible grammar, just an example.
#
# ```ruby
# {
#   START: '"Hello ", /\s/ NAME "!',
#   NAME: ['"world', '/[A-Z][a-z]*/']
# }
# ```
#
# Note that to match a space, you need to use the pattern, since the splitting function 
# for rules splits on the space character, regardless of where it is.
class Grammaphone

  # Creates a TokenStream instance using `split_method` as the function to 
  # split `src` into tokens. 
  #
  # `split_method` is expected to take a String and return an Array of Strings.
  def self.tokenize(src, &split_method)
    TokenStream.new(src, &split_method)
  end

  # Creates a new instance of Grammaphone. 
  #
  # `rules` is a Hash containing the rules of the grammar, as defined above.
  #
  # `node_type` must be a class that responds to <<. By default, this is Array.
  #
  # `default_action` is the method called on the results of a rule being matched.
  # This function is passed the results of the rule matching, which is an instance 
  # of `node_type`, and the name of the rule matched. By default, this is the 
  # identity function, returning the input node.
  #
  # The results of the action are included in the output instead of the input 
  # instance of `node_type`.
  def initialize(rules = {}, node_type = Array, &default_action)
    raise ArgumentError.new("cannot form parser from a #{rules.class}") unless rules.kind_of? Hash
    raise ArgumentError.new("syntax tree type must respond to <<") unless node_type.method_defined?(:"<<")
    @default_action = (default_action.nil? ? lambda{|node, name| node} : default_action)
    @node_type = node_type
    @rules = rules.map do |k, v|
      Rule.new(k, v, @default_action)
    end
  end

  # Adds a rule with a single rule to the grammar, using the associated action, 
  # replacing existing the rule if there is a conflict.
  #
  # `action` is the method called on the results of the rule being matched.
  # This function is passed the results of the rule matching, which is an instance 
  # of `node_type`, and the name of the rule matched. By default, this is the 
  # identity function, returning the input node.
  def add_rule(name, rule, &action)
    m = @rules.find {|r| r.name == name}
    action = @default_action if action.nil?
    if m.nil?
      @rules << Rule.new(name, rule, action)
    else
      m.rule = rule
      m.action = action
    end
  end

  # Returns a Hash containint  a representation of existing rules. This does 
  # not provide access to the underlying rules.
  def rules
    @rules.map{|r| [r.name, r.rule]}.to_h
  end

  # Runs the grammar on the given token stream. If `token_stream` is not a 
  # TokenStream instance, then a new TokenStream instance is created.
  #
  # The initial rule is the first rule added, either from the initial Hash or 
  # the first call to `add_rule`.
  #
  # If the ruleset is empty when `parse` is called, an EmptyRulesetError is 
  # raised.
  def parse(token_stream)
    token_stream = TokenStream.new(token_stream) unless token_stream.kind_of?(TokenStream)
    raise EmptyRulesetError if @rules.size == 0
    res = self.send(@rules[0].name, token_stream, @node_type)
    res
  end

  # Runs the specified rule. Useful for testing purposes.
  #
  # Not to be released in shipped version
  def test(name, token_stream)
    self.send(name, TokenStream.new(token_stream))
  end

  def respond_to_missing?(m, include_all)
    (include_all && @rules.any?{|r| r.name == m}) || super
  end

  # This is fun, but it doesn't really take advantage of metaprogramming in a way 
  # that can't be accomplished with match_rule. It also lets the rules be "called" 
  # outside of normal context
  def method_missing(m, *args, &block)
    r = @rules.find{|r| r.name == m}
    if r
      match_rule(r, args[0], args[1])
    else
      super
    end
  end
  
  private
 
  def match_rule(r, stream, result_type)
    # This is an enormous function. It needs to be pared down
    matches = nil
    result = result_type.new
    r.each do |option|
      tokens = stream.dup
      break if option.empty?
      matched = true

      option.each do |element|
        token = tokens.peek
        # puts "rule: #{r.name}; element: #{element}; token: #{token}"
        if Token.literal?(element)
          unless Token.matches_literal?(element, token)
            matches = nil
            matched = false
            break
          end

          matches ||= []
          matches << token
          result << token
          tokens.next # might as well be tokens.skip
        elsif Token.pattern?(element)
          unless Token.matches_pattern?(element, token)
            matches = nil
            matched = false
            break
          end

          matches ||= []
          unless token.nil?
            matches << token
            result << token
          end
          tokens.next
        else
          raise TokenError.new("Can't have empty patterns") if element.empty?

          submatches, res = self.send(element, tokens, result_type)
          unless submatches
            matches = nil
            matched = false
            break
          end

          matches ||= []
          matches << submatches
          result << res
          tokens.skip([submatches.size, 1].max)
        end
      end

      if matched
        result = r.trigger(result)
        break
      end
    end
    # puts "matches for rule #{r.name}: #{matches.to_s}" unless matches.nil?
    return false if matches.nil?
    [matches, result]
  end
end
