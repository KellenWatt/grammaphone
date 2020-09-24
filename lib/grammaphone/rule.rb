require_relative "./errors"
class Grammaphone
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
        raise ArgumentError.new("grammar rule as an Array must contain only Strings") unless rule.all?{|r| r.kind_of?(String)}
        @rule = rule.dup
      when String
        @rule = [rule.dup]
      else
        raise ArgumentError.new("grammar rule must be a String or Array of Strings")
      end
      @allows_empty = @rule.any?{|r| r.empty?}
    end

    # action expected to return an Array-like object with flatten implemented
    def action=(action)
      raise ArgumentError.new("rule actions must be a proc") unless (action.kind_of?(Proc) || action.kind_of?(NilClass))
      if action.nil?
        @action = lambda {|tokens, name| token}
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

    def allows_empty?
      @allows_empty
    end

    def trigger(node)
      @action.call(node, name)
    end
  end
end
