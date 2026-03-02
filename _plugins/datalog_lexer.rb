# _plugins/datalog_lexer.rb
# Custom Lexer for wirelog's Datalog dialect 

require 'rouge'

module Rouge
  module Lexers
    class Datalog < RegexLexer
      title "Datalog"
      desc "A declarative logic programming language (Datalog)"
      tag 'datalog'
      aliases 'dl'
      filenames '*.dl'

      state :root do
        # Directives (e.g. .decl, .input, .output, .type, .comp, .init)
        rule %r/^\s*\.[a-z]\w*/i, Keyword::Declaration

        # Comments
        rule %r/\/\*/, Comment::Multiline, :comment
        rule %r/\/\/[^\n]*/, Comment::Single

        # Strings
        rule %r/"/, Str::Double, :string

        # Numbers (including floats, integers, and unsigned if applicable)
        rule %r/[+\-]?\d*\.\d+([eE][+\-]?\d+)?/i, Num::Float
        rule %r/[+\-]?0[xX][0-9a-fA-F]+/i, Num::Hex
        rule %r/[+\-]?0[bB][01]+/i, Num::Bin
        rule %r/[+\-]?\d+/i, Num::Integer

        # Variables: start with uppercase letter or underscore
        rule %r/[A-Z_][a-zA-Z0-9_]*/, Name::Variable

        # Identifiers (Relations / Atoms / Data types): start with lowercase
        rule %r/[a-z][a-zA-Z0-9_]*/, Name::Function

        # Operators
        rule %r/:-|:=|=|!=|<|<=|>|>=|\+|\-|\*|\/|%|\^/, Operator

        # Punctuation
        rule %r/[(),.:;{}]/, Punctuation

        # Whitespace
        rule %r/\s+/m, Text::Whitespace
      end

      state :comment do
        rule %r/[^\*\/]+/, Comment::Multiline
        rule %r/\*\//, Comment::Multiline, :pop!
        rule %r/[\*\/]/, Comment::Multiline
      end

      state :string do
        rule %r/[^\\"]+/, Str::Double
        rule %r/\\./, Str::Escape
        rule %r/"/, Str::Double, :pop!
      end
    end
  end
end
