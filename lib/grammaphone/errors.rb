class Grammaphone
  class ParseError < StandardError; end

  class RulesetError < ParseError
    def message
      super + "Problem with ruleset definition"
    end
  end

  class EmptyRulesetError < RulesetError
    def message
      super + ": empty ruleset not allowed"
    end
  end

  class TokenError < ParseError; end

  class NonstringTokenError < TokenError
    def message
      super + "Token not a String"
    end
  end

  class TokenStreamError < TokenError
    def message
      super + "Non-Array-able types can't be tokenized"
    end
  end
end
