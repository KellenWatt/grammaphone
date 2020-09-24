Gem::Specification.new do |s|
  s.name = "Grammaphone"
  s.version = "0.1.0"
  s.date = "2020-09-15"
  s.license = "MIT"
  s.summary = "A pure Ruby dynamic parser"
  s.description = "A dynamic parser written in Ruby that uses a BNF-adjascent grammar."
  s.author = "Kellen Watt"
  s.email = "kbw6d9@mst.edu"

  s.homepage = "https://github.com/KellenWatt/grammaphone"

  s.files = [
    "lib/grammaphone.rb",
    "lib/grammaphone/errors.rb",
    "lib/grammaphone/tokens.rb",
    "lib/grammaphone/rule.rb",
  ]
end
