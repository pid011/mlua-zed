; mLua is parsed with the Lua grammar, so mLua-only declarations often appear
; inside ERROR nodes. These rules intentionally recover the common declaration
; shapes used by the official VS Code grammar.

[
  "do"
  "end"
  "goto"
  "in"
  "local"
  (break_statement)
] @keyword

[
  "else"
  "elseif"
  "if"
  "then"
] @keyword.conditional

[
  "for"
  "repeat"
  "until"
  "while"
] @keyword.repeat

"function" @keyword.function
"return" @keyword.return

((identifier) @keyword
  (#any-of? @keyword "break" "do" "end" "goto" "in" "local"))

((identifier) @keyword.conditional
  (#any-of? @keyword.conditional "else" "elseif" "if" "then"))

((identifier) @keyword.repeat
  (#any-of? @keyword.repeat "for" "repeat" "until" "while"))

((identifier) @keyword.function
  (#eq? @keyword.function "function"))

((identifier) @keyword.return
  (#eq? @keyword.return "return"))

((identifier) @keyword
  (#any-of? @keyword
    "script" "property" "member" "extends" "continue"
    "event" "logic" "state" "struct"))

((identifier) @keyword.function
  (#any-of? @keyword.function
    "method" "handler" "constructor" "operator" "emitter"))

((identifier) @keyword.modifier
  (#any-of? @keyword.modifier "override" "static" "readonly"))

[
  "and"
  "not"
  "or"
] @keyword.operator

((identifier) @keyword.operator
  (#any-of? @keyword.operator "and" "not" "or"))

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

((identifier) @type.builtin
  (#any-of? @type.builtin "any" "boolean" "number" "string" "void"))

((identifier) @type
  (#match? @type "^[A-Z][A-Za-z0-9_]*$"))

((identifier) @constant
  (#match? @constant "^[A-Z][A-Z_0-9]*$"))

((identifier) @attribute
  (#match? @attribute "^@[A-Za-z_][A-Za-z0-9_]*$"))

((function_call
  name: (identifier) @attribute)
  (#any-of? @attribute
    "Logic" "ExecSpace" "Sync" "TargetUserSync" "EventSender" "DisplayName"
    "Description" "Deprecated" "Sealed" "HideFromInspector"
    "InspectorButton" "ReleaseOnly" "LuaLibrary" "AttributeUsage" "MinValue"
    "MaxValue" "MaxLength" "Delta"))

(vararg_expression) @constant
(nil) @constant.builtin
(nil) @variable.builtin

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

((function_call
  name: (identifier) @function)
  (#not-match? @function "^(@.*|and|break|continue|constructor|do|else|elseif|emitter|end|extends|for|function|goto|handler|if|in|local|member|method|not|operator|or|override|property|readonly|repeat|return|script|static|then|until|while)$"))

(function_call
  name: (dot_index_expression
    field: (identifier) @function))

(function_call
  name: (method_index_expression
    method: (identifier) @function.method.call))

(function_declaration
  name: [
    (identifier) @function.definition
    (dot_index_expression
      field: (identifier) @function.definition)
  ])

(parameters
  (identifier) @variable.parameter)

; script MyScript extends BaseScript
((ERROR
  . (identifier) @keyword @_mlua_script
  . (identifier) @type
  . (identifier) @keyword @_mlua_extends
  . (identifier) @type)
  (#eq? @_mlua_script "script")
  (#eq? @_mlua_extends "extends"))

; @Logic
; script MyScript extends BaseScript
((ERROR
  . (identifier) @attribute
  . (identifier) @keyword @_mlua_script
  . (identifier) @type
  . (identifier) @keyword @_mlua_extends
  . (identifier) @type)
  (#match? @attribute "^@")
  (#eq? @_mlua_script "script")
  (#eq? @_mlua_extends "extends"))

; property Type name = value, when the parser keeps the declaration in one
; assignment_statement.
((assignment_statement
  (variable_list
    name: (identifier) @keyword @_mlua_property)
  (ERROR
    (identifier) @type
    (identifier) @property .))
  (#eq? @_mlua_property "property"))

; property Type name = value, when the parser splits "property Type" into the
; previous ERROR node and keeps "name = value" in the assignment_statement.
((ERROR
  (identifier) @keyword @_mlua_property
  (identifier) @type .)
 .
 (assignment_statement
  (variable_list
    name: (identifier) @property))
  (#eq? @_mlua_property "property"))

; method ReturnType Name(...)
((function_call
  name: (identifier) @keyword @_mlua_callable
  (ERROR
    (identifier) @type
    (identifier) @function.definition .))
  (#any-of? @_mlua_callable "method" "operator"))

; method ReturnType Name(), when a previous "end" absorbs the call node.
((function_call
  (ERROR
    (identifier) @keyword @_mlua_callable
    (identifier) @type
    (identifier) @function.definition .))
  (#any-of? @_mlua_callable "method" "operator"))

; method ReturnType Name(...), when "method ReturnType" is split into a
; previous ERROR node and Name(...) remains a function_call.
((ERROR
  (identifier) @keyword @_mlua_callable
  (identifier) @type .)
 .
 (function_call
  name: (identifier) @function.definition)
  (#any-of? @_mlua_callable "method" "operator"))

; handler/emitter/constructor Name(...)
((function_call
  name: (identifier) @keyword @_mlua_callable
  (ERROR
    (identifier) @function.definition .))
  (#any-of? @_mlua_callable "handler" "emitter" "constructor"))

; handler/emitter/constructor Name(...), when the declaration keyword is split
; into a previous ERROR node.
((ERROR
  (identifier) @keyword.function @_mlua_callable .)
 .
 (function_call
  name: (identifier) @function.definition)
  (#any-of? @_mlua_callable "handler" "emitter" "constructor"))

; member name
((ERROR
  (identifier) @keyword @_mlua_member
  (identifier) @property .)
  (#eq? @_mlua_member "member"))

; Type parameter pairs inside mLua declarations.
((arguments
  (ERROR
    (identifier) @type .)
  . (identifier) @variable.parameter))

(vararg_expression) @variable.parameter
(label_statement (identifier) @label)
(goto_statement (identifier) @label)

(comment) @comment
(hash_bang_line) @preproc
(number) @number
(string) @string
(escape_sequence) @string.escape
