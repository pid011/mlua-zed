; Tree-sitter highlight queries for mLua.

(identifier) @variable

((identifier) @variable.special
  (#eq? @variable.special "self"))

[
  "do"
  "end"
  "goto"
  "in"
  "local"
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

[
  "and"
  "not"
  "or"
] @keyword.operator

[
  "script"
  "property"
  "member"
  "extends"
] @keyword

[
  "method"
  "handler"
  "constructor"
  "operator"
  "emitter"
] @keyword.function

[
  "override"
  "static"
  "readonly"
] @keyword.modifier

(break_statement) @keyword
(continue_statement) @keyword

(nil) @variable.builtin
(boolean) @boolean
(number) @number
(string) @string
(escape_sequence) @string.escape
(comment) @comment

; mLua attributes are parsed as a short ERROR for the leading @ plus the
; following identifier or call expression.
((ERROR
  (ERROR)
  .
  (identifier) @attribute)
  (#any-of? @attribute
    "Component" "Logic" "State" "ExecSpace" "Sync" "TargetUserSync"
    "EventSender" "DisplayName" "Description" "Deprecated" "Sealed" "HideFromInspector"
    "InspectorButton" "ReleaseOnly" "LuaLibrary" "AttributeUsage" "MinValue"
    "MaxValue" "MaxLength" "Delta"))

((ERROR)
 .
 (function_call
  function: (identifier) @attribute)
  (#any-of? @attribute
    "Component" "Logic" "State" "ExecSpace" "Sync" "TargetUserSync"
    "EventSender" "DisplayName" "Description" "Deprecated" "Sealed" "HideFromInspector"
    "InspectorButton" "ReleaseOnly" "LuaLibrary" "AttributeUsage" "MinValue"
    "MaxValue" "MaxLength" "Delta"))

; The upstream grammar currently requires declaration bodies to contain at
; least one statement. Empty script/method/handler bodies are recovered as
; ERROR nodes, so keep the visible syntax highlighted in that recovery shape.
(ERROR
  "script"
  .
  (identifier) @type)

(ERROR
  "method"
  .
  (type)
  .
  (identifier) @function.method
  .
  (parameter_list))

(ERROR
  "handler"
  .
  (identifier) @function
  .
  (parameter_list))

(ERROR
  "constructor"
  .
  (identifier) @constructor
  .
  (parameter_list))

((ERROR
  (identifier) @type
  .
  (type)))

((ERROR
  (identifier) @type
  .
  (identifier) @keyword)
  (#eq? @keyword "end")
  (#not-match? @type "^(end|return|break|continue)$"))

(ERROR
  (type)
  .
  (identifier) @function.method
  .
  (parameter_list))

(ERROR
  (identifier) @function
  .
  (parameter_list))

((ERROR
  (identifier) @keyword)
  (#eq? @keyword "end"))

(function_declaration
  name: (identifier) @function.definition)

(method_declaration
  name: (identifier) @function.method)

(handler_declaration
  name: (identifier) @function)

(constructor_declaration
  name: (identifier) @constructor)

(emitter_declaration
  name: (identifier) @function)

(function_expression) @function

((function_call
  function: (identifier) @function.call)
  (#not-match? @function.call "^(Logic|ExecSpace|Sync|TargetUserSync|EventSender|DisplayName|Description|Deprecated|Sealed|HideFromInspector|InspectorButton|ReleaseOnly|LuaLibrary|AttributeUsage|MinValue|MaxValue|MaxLength|Delta)$"))

(function_call
  function: (dot_index
    field: (identifier) @function.call))

(function_call
  function: (method_index
    method: (identifier) @function.method.call))

(script_declaration
  name: (identifier) @type)

(type
  (identifier) @type)

((type
  (identifier) @type.builtin)
  (#any-of? @type.builtin
    "any" "boolean" "integer" "number" "string" "void"))

(parameter
  name: (identifier) @variable.parameter)

(vararg) @variable.parameter

(property_declaration
  name: (identifier) @property)

(property_declaration
  name: (identifier) @variable.member)

(member_declaration
  name: (identifier) @property)

(member_declaration
  name: (identifier) @variable.member)

(dot_index
  field: (identifier) @property)

(dot_index
  field: (identifier) @variable.member)

(label
  name: (identifier) @label)

(goto_statement
  label: (identifier) @label)

[
  "//="
  "+="
  "-="
  "*="
  "/="
  "%="
  "&="
  "|="
  "<<"
  ">>"
  "//"
  ".."
  "=="
  "~="
  "<="
  ">="
  "<"
  ">"
  "+"
  "-"
  "*"
  "/"
  "%"
  "#"
  "^"
  "&"
  "|"
  "~"
  "="
] @operator

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
  ":"
  "."
] @punctuation.delimiter
