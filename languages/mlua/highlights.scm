; mLua is parsed with the Lua grammar for the first POC. The language server
; supplies mLua-specific semantic tokens when semantic tokens are enabled.

[
  "do"
  "else"
  "elseif"
  "end"
  "for"
  "function"
  "goto"
  "if"
  "in"
  "local"
  "repeat"
  "return"
  "then"
  "until"
  "while"
  (break_statement)
] @keyword

((identifier) @keyword
  (#any-of? @keyword
    "script" "property" "method" "handler" "extends" "event" "logic" "state" "struct"))

[
  "and"
  "not"
  "or"
] @keyword.operator

[
  "+"
  "-"
  "*"
  "/"
  "%"
  "^"
  "#"
  "=="
  "~="
  "<="
  ">="
  "<"
  ">"
  "="
  "&"
  "~"
  "|"
  "<<"
  ">>"
  "//"
  ".."
] @operator

[
  ";"
  ":"
  ","
  "."
] @punctuation.delimiter

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

(identifier) @variable

((identifier) @variable.special
  (#eq? @variable.special "self"))

((identifier) @constant
  (#match? @constant "^[A-Z][A-Z_0-9]*$"))

(vararg_expression) @constant
(nil) @constant.builtin

[
  (false)
  (true)
] @boolean

(field
  name: (identifier) @property)

(dot_index_expression
  field: (identifier) @property)

(method_index_expression
  method: (identifier) @function.method)

(function_call
  name: [
    (identifier) @function
    (dot_index_expression
      field: (identifier) @function)
  ])

(function_declaration
  name: [
    (identifier) @function.definition
    (dot_index_expression
      field: (identifier) @function.definition)
  ])

(parameters
  (identifier) @variable.parameter)

(comment) @comment
(hash_bang_line) @preproc
(number) @number
(string) @string
(escape_sequence) @string.escape
