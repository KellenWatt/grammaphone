class Grammaphone
  class ParseError < StandardError; end

  class RulesetError < ParseError
    def message
      "Problem with ruleset definition"
    end
  end

  class EmptyRulesetError < RulesetError
    def message
      super + ": empty ruleset not allowed"
    end
  end

  def initialize(rules = {})
    raise ArgumentError.new("cannot form parser from a #{rules.class}") unless rules.kind_of? Hash
    @rules = rules.map do |k, v|
      Rule.new(k, v)
    end
  end

  def add_rule(name, rule, &action)
    m = @rules.find {|r| r.name == name}
    if m.nil?
      @rules << Rule.new(name, rule, &action)
    else
      m.rule = rule
      m.action = action
    end
  end

  def rules
    @rules.map{|r| [r.name, r.rule]}.to_h
  end

  def parse(token_stream)
    raise EmptyRulesetError if @rules.size == 0
    self.send(@rules[0].name, token_stream.dup)
  end

  def test(name, token_stream)
    self.send(name, token_stream.dup)
  end

  def method_missing(m, *args, &block)
    r = @rules.find{|r| r.name == m}
    if r
      matches = []
      r.each do |version|
        tokens = args[0].dup
        version.each do |pattern|
          token = tokens.shift
          puts "rule: #{r.name}; pattern: #{pattern}; token: #{token}"
          # puts "pattern: #{pattern}; token: #{token}"
          if pattern[0] == ("\"")
            if pattern[1..] != token
              matches.clear
              break false
            end
            matches << token
          else
            tokens.unshift(token)
            res = self.send(pattern, tokens)
            if res 
              matches += res.flatten
              tokens.shift(res.size)
            else
              matches.clear
              break res
            end
          end
        end
        break if tokens.empty?
      end
      puts "matches for rule #{r.name}: #{matches.to_s}"
      r.trigger(matches)
    else
      super
    end
  end

  private 

  class Rule
    attr_reader :name

    def initialize(name, rule, act = nil)
      raise ArgumentError.new("rule names must be a String or Symbol") unless (name.kind_of?(Symbol) || name.kind_of?(String))
      @name = name.to_sym
      self.rule = rule
      self.action = act
    end

    def rule
      @rule.dup
    end

    def rule=(rule)
      case rule
      when Array
        raise ArgumentError.new("grammar rules as Arrays must contain only Strings") unless rule.all?{|r| r.kind_of?(String)}
        @rule = rule.dup
      when String
        @rule = [rule.dup]
      else
        raise ArgumentError.new("grammar rules must be Strings or Array of Strings")
      end
    end

    # action expected to return an Array-like object with flatten implemented
    def action=(action)
      raise ArgumentError.new("rule actions must be a proc") unless (action.kind_of?(Proc) || action.kind_of?(NilClass))
      if action.nil?
        @action = Proc.new {|v| v}
      else
        @action = action
      end
    end

    def each 
      if block_given?
        @rule.each do |r|
          yield r.split(" ")
        end
      else
        to_enum(:each)
      end
    end

    def trigger(tokens)
      @action.call(tokens)
    end
  end
end
