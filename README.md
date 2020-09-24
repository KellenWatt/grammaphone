# Grammaphone
A BNF-adjacent based RD parser.

No, it isn't spelled wrong. Grammaphone is a parser built on the idea of 
parsing strictly based on a grammar, and not having any sort of intermediate 
generation. This is significantly slower than generated parsers, but also 
simpler and cleaner to inject in a Ruby toolchain.
