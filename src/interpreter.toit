// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .device-bot

/**
A function in the language.
*/
class Function:
  name/string
  syntax/string
  description/string
  action/Lambda
  arity_/int

  /**
  Constructs a new function.

  The $syntax is the string that the user would type to call the function. The
    syntax is used to determine the function's name and arity. It is
    also given as help to OpenAI.

  The $description is a short description of the function. It is given as help to
    OpenAI.

  The $action is the function that is called when the function is called. It is
    invoked with a list of arguments.
  */
  constructor --.syntax --.description --.action:
    paren-start := syntax.index-of "("
    name = syntax[..paren-start].trim
    paren-end := syntax.index-of ")"
    params := syntax[paren-start + 1..paren-end]
    if params.trim == "":
      arity_ = 0
    else:
      count := 0
      start-offset := 0
      while start-offset < params.size:
        start-offset = params.index-of "," start-offset
        if start-offset == -1:
          break
        count++
        start-offset++
      arity_ = count + 1

BUILTINS ::= [
  Function
      --syntax="to_int(<num_or_string>)"
      --description="Converts a number or string to an integer."
      --action=:: | args |
          num-or-string := args[0]
          num-or-string is string
              ? int.parse num-or-string
              : num-or-string.to-int,
  Function
      --syntax="print(<message>)"
      --description="Prints a message."
      --action=:: | args |
          message := args[0]
          print message,
  Function
      --syntax="sleep(<ms>)"
      --description="Sleeps for a given amount of milliseconds."
      --action=:: | args |
          ms/num := args[0]
          sleep --ms=(ms.to-int),
  Function
      --syntax="random(<min>, <max>)"
      --description="Returns a random integer between min and max."
      --action=:: | args |
          min := (args[0] as num).to-int
          max := (args[1] as num).to-int
          random min max,
  Function
      --syntax="now()"
      --description="Returns the current time in milliseconds since epoch."
      --action=:: | args |
          Time.now.ms-since-epoch,
  Function
      --syntax="list_create()"
      --description="Creates a new list."
      --action=:: | args |
          [],
  Function
      --syntax="list_add(<list>, <value>)"
      --description="Adds a value to a list."
      --action=:: | args |
          list/List := args[0]
          value := args[1]
          list.add value,
  Function
      --syntax="list_get(<list>, <index>)"
      --description="Gets a value from a list."
      --action=:: | args |
          list/List := args[0]
          index := args[1].to-int
          list[index],
  Function
      --syntax="list_set(<list>, <index>, <value>)"
      --description="Sets a value in a list."
      --action=:: | args |
          list/List := args[0]
          index := args[1].to-int
          value := args[2]
          list[index] = value,
  Function
      --syntax="list_size(<list>)"
      --description="Returns the size of a list."
      --action=:: | args |
          list/List := args[0]
          list.size,
  Function
      --syntax="map_create()"
      --description="Creates a new map."
      --action=:: | args |
          {:},
  Function
      --syntax="map_set(<map>, <key>, <value>)"
      --description="Sets a value in a map."
      --action=:: | args |
          map/Map := args[0]
          key := args[1]
          value := args[2]
          map[key] = value,
  Function
      --syntax="map_get(<map>, <key>)"
      --description="Gets a value from a map."
      --action=:: | args |
          map/Map := args[0]
          key := args[1]
          if not map.contains key:
            throw "Key not found in map: $key"
          map[key],
  Function
      --syntax="map_contains(<map>, <key>)"
      --description="Returns true if the map contains the given key."
      --action=:: | args |
          map/Map := args[0]
          key := args[1]
          map.contains key,
  Function
      --syntax="map_keys(<map>)"
      --description="Returns a list of all keys in the map."
      --action=:: | args |
          map/Map := args[0]
          map.keys,
  Function
      --syntax="map_values(<map>)"
      --description="Returns a list of all values in the map."
      --action=:: | args |
          map/Map := args[0]
          map.values,
  Function
      --syntax="map_size(<map>)"
      --description="Returns the size of a map."
      --action=:: | args |
          map/Map := args[0]
          map.size,
]

builtins-description -> string:
  result := ""
  BUILTINS.do: | function/Function |
      result += "- $function.syntax: $function.description\n"
  return result

parse code/string user-functions/List -> Program:
  scanner := Scanner code
  parser := Parser scanner BUILTINS user-functions
  return parser.parse-program

class Scanner:
  code/string
  position/int := 0

  constructor .code:

  next -> Token:
    if position >= code.size:
      return Token Token.EOF ""

    keep-removing-spaces-and-comments := true
    while keep-removing-spaces-and-comments:
      keep-removing-spaces-and-comments = false

      while position < code.size:
        c := code[position]
        if c == ' ' or c == '\n':
          position++
          continue
        break

      if current == '/' and peek == '/':
        // Comment.
        // Eat until end of line.
        while current != '\n' and current != -1:
          position++
        keep-removing-spaces-and-comments = true


    if position >= code.size:
      return Token Token.EOF ""

    c := code[position]

    if c == '+' or
        c == '-' or
        c == '*' or
        c == '/' or
        c == '%' or
        c == '^' or
        c == '~':
      position++
      return Token Token.OPERATOR (string.from-rune c)

    if c == '<':
      if peek == '<':
        position += 2
        return Token Token.OPERATOR "<<"
      if peek == '=':
        position += 2
        return Token Token.OPERATOR "<="
      position++
      return Token Token.OPERATOR "<"

    if c == '>':
      if peek == '>':
        if (peek 2) == '>':
          position += 3
          return Token Token.OPERATOR ">>>"
        position += 2
        return Token Token.OPERATOR ">>"
      if peek == '=':
        position += 2
        return Token Token.OPERATOR ">="
      position++
      return Token Token.OPERATOR ">"

    if c == '!':
      if peek == '=':
        position += 2
        return Token Token.OPERATOR "!="
      position++
      return Token Token.OPERATOR "!"

    if c == '=':
      if peek == '=':
        position += 2
        return Token Token.OPERATOR "=="
      position++
      return Token Token.OPERATOR "="

    if c == '&':
      if peek == '&':
        position += 2
        return Token Token.OPERATOR "&&"
      position++
      return Token Token.OPERATOR "&"

    if c == '|':
      if peek == '|':
        position += 2
        return Token Token.OPERATOR "||"
      position++
      return Token Token.OPERATOR "|"

    if c == '(':
      position++
      return Token Token.LEFT-PAREN "("

    if c == ')':
      position++
      return Token Token.RIGHT-PAREN ")"

    if c == '{':
      position++
      return Token Token.LEFT-BRACE "{"

    if c == '}':
      position++
      return Token Token.RIGHT-BRACE "}"

    if c == 'i' and
        peek == 'f' and
        not is-identifier (peek 2):
      position += 2
      return Token Token.IF "if"

    if c == 'e' and
        peek == 'l' and
        (peek 2) == 's' and
        (peek 3) == 'e' and
        not is-identifier (peek 4):
      position += 4
      return Token Token.ELSE "else"

    if c == 'w' and
        peek == 'h' and
        (peek 2) == 'i' and
        (peek 3) == 'l' and
        (peek 4) == 'e' and
        not is-identifier (peek 5):
      position += 5
      return Token Token.WHILE "while"

    if c == 'l' and
        peek == 'e' and
        (peek 2) == 't' and
        not is-identifier (peek 3):
      position += 3
      return Token Token.LET "let"

    if c == 't' and
        peek == 'r' and
        (peek 2) == 'u' and
        (peek 3) == 'e' and
        not is-identifier (peek 4):
      position += 4
      return Token Token.TRUE "true"

    if c == 'f' and
        peek == 'a' and
        (peek 2) == 'l' and
        (peek 3) == 's' and
        (peek 4) == 'e' and
        not is-identifier (peek 5):
      position += 5
      return Token Token.FALSE "false"

    if c == 'c' and
        peek == 'o' and
        (peek 2) == 'n' and
        (peek 3) == 't' and
        (peek 4) == 'i' and
        (peek 5) == 'n' and
        (peek 6) == 'u' and
        (peek 7) == 'e' and
        not is-identifier (peek 8):
      position += 8
      return Token Token.CONTINUE "continue"

    if c == 'b' and
        peek == 'r' and
        (peek 2) == 'e' and
        (peek 3) == 'a' and
        (peek 4) == 'k' and
        not is-identifier (peek 5):
      position += 5
      return Token Token.BREAK "break"

    if is-identifier-start c:
      start := position
      position++
      while is-identifier current:
        position++
      return Token Token.IDENTIFIER code[start..position].copy

    if '0' <= c <= '9':
      start := position
      position++
      while '0' <= current <= '9':
        position++
      if current == '.':
        position++
        while '0' <= current <= '9':
          position++
      return Token Token.NUMBER code[start..position].copy

    if c == '"':
      start := position
      position++
      while current != '"' and current != -1:
        position++
      if current == -1:
        throw "unterminated string"
      position++
      return Token Token.STRING code[start..position].copy

    if c == ';':
      position++
      return Token Token.SEMICOLON ";"

    if c == ',':
      position++
      return Token Token.COMMA ","

    throw "unexpected character: $(string.from-rune c)"

  current -> int:
    if position < code.size:
      return code[position]
    return -1

  peek n/int=1 -> int:
    if position < code.size - n:
      return code[position + n]
    return -1

  is-identifier-start c/int --start/bool=false -> bool:
    return 'a' <= c <= 'z' or 'A' <= c <= 'Z' or c == '_'

  is-identifier c/int -> bool:
    return is-identifier-start c or '0' <= c <= '9'

class Token:
  static EOF ::= 0
  static NUMBER ::= 1
  static OPERATOR ::= 2
  static LEFT-PAREN ::= 3
  static RIGHT-PAREN ::= 4
  static IF ::= 5
  static ELSE ::= 6
  static WHILE ::= 7
  static LET ::= 8
  static IDENTIFIER ::= 9
  static LEFT-BRACE ::= 10
  static RIGHT-BRACE ::= 11
  static TRUE ::= 13
  static FALSE ::= 14
  static STRING ::= 15
  static SEMICOLON ::= 16
  static COMMA ::= 17
  static CONTINUE ::= 18
  static BREAK ::= 19

  type/int
  value/string

  constructor .type .value:

  stringify -> string:
    return "Token($(type) $(value))"

token-type-string type/int -> string:
  if type == Token.EOF: return "EOF"
  if type == Token.NUMBER: return "NUMBER"
  if type == Token.OPERATOR: return "OPERATOR"
  if type == Token.LEFT-PAREN: return "LEFT_PAREN"
  if type == Token.RIGHT-PAREN: return "RIGHT_PAREN"
  if type == Token.IF: return "IF"
  if type == Token.ELSE: return "ELSE"
  if type == Token.WHILE: return "WHILE"
  if type == Token.LET: return "LET"
  if type == Token.IDENTIFIER: return "IDENTIFIER"
  if type == Token.LEFT-BRACE: return "LEFT_BRACE"
  if type == Token.RIGHT-BRACE: return "RIGHT_BRACE"
  if type == Token.TRUE: return "TRUE"
  if type == Token.FALSE: return "FALSE"
  if type == Token.STRING: return "STRING"
  if type == Token.SEMICOLON: return "SEMICOLON"
  if type == Token.COMMA: return "COMMA"
  if type == Token.CONTINUE: return "CONTINUE"
  if type == Token.BREAK: return "BREAK"
  unreachable

class Parser:
  scanner_/Scanner
  current/Token? := null
  functions/Map

  constructor .scanner_ builtins-list/List user-function-list/List:
    functions = {:}
    builtins-list.do: | function/Function |
      functions[function.name] = function

    // User functions override builtins.
    user-function-list.do: | function/Function |
      functions[function.name] = function

  consume -> none:
    current = scanner_.next

  consume type/int -> none:
    if current.type != type:
      throw "expected $(token-type-string type), got $(token-type-string current.type) $current.value"
    consume

  consume type/int value/string -> none:
    if current.type != type or current.value != value:
      throw "expected $(type) $(value)"
    consume

  parse-program -> Program:
    current = scanner_.next
    body := []
    is-first := true
    while current.type != Token.EOF:
      body.add parse-statement
    consume Token.EOF
    return Program body

  parse-statement -> Statement:
    if current.type == Token.LEFT-BRACE:
      return parse-block
    if current.type == Token.LET:
      return parse-let
    if current.type == Token.IF:
      return parse-if
    if current.type == Token.WHILE:
      return parse-while
    if current.type == Token.SEMICOLON:
      consume
      return Nop
    if current.type == Token.CONTINUE:
      consume
      consume Token.SEMICOLON
      return Continue
    if current.type == Token.BREAK:
      consume
      consume Token.SEMICOLON
      return Break
    expression := parse-expression
    consume Token.SEMICOLON
    return ExpressionStatement expression

  parse-block -> Block:
    consume Token.LEFT-BRACE
    nodes := []
    while current.type != Token.RIGHT-BRACE and current.type != Token.EOF:
      node := parse-statement
      nodes.add node
      if current.type == Token.SEMICOLON:
        consume Token.SEMICOLON
    consume Token.RIGHT-BRACE
    return Block nodes

  parse-let -> Let:
    consume Token.LET
    if current.type != Token.IDENTIFIER:
      throw "expected identifier"
    name := current.value
    consume Token.IDENTIFIER
    consume Token.OPERATOR "="
    expression := parse-expression
    consume Token.SEMICOLON
    return Let name expression

  parse-if -> If:
    consume Token.IF
    consume Token.LEFT-PAREN
    condition := parse-expression
    consume Token.RIGHT-PAREN
    then := parse-statement
    if current.type == Token.ELSE:
      consume Token.ELSE
      else_ := parse-statement
      return If condition then else_
    return If condition then null

  parse-while -> While:
    consume Token.WHILE
    consume Token.LEFT-PAREN
    condition := parse-expression
    consume Token.RIGHT-PAREN
    body := parse-statement
    return While condition body

  parse-expression -> Expression:
    return parse-assignment

  parse-assignment -> Expression:
    left := parse-logical-or
    if current.type == Token.OPERATOR and
        current.value == "=":
      consume Token.OPERATOR
      if left is not Reference:
        throw "expected identifier on left side of assignment"
      right := parse-assignment
      return Assignment (left as Reference) right
    return left

  parse-logical-or -> Expression:
    left := parse-logical-and
    while current.type == Token.OPERATOR and
        current.value == "||":
      consume Token.OPERATOR
      right := parse-logical-and
      left = Binary "||" left right
    return left

  parse-logical-and -> Expression:
    left := parse-equality
    while current.type == Token.OPERATOR and
        current.value == "&&":
      consume Token.OPERATOR
      right := parse-equality
      left = Binary "&&" left right
    return left

  parse-equality -> Expression:
    left := parse-comparison
    while current.type == Token.OPERATOR and
        (current.value == "==" or
          current.value == "!="):
      op := current.value
      consume Token.OPERATOR
      right := parse-comparison
      left = Binary op left right
    return left

  parse-comparison -> Expression:
    left := parse-bitwise-or
    while current.type == Token.OPERATOR and
        (current.value == "<" or
          current.value == ">" or
          current.value == "<=" or
          current.value == ">="):
      op := current.value
      consume Token.OPERATOR
      right := parse-bitwise-or
      left = Binary op left right
    return left

  parse-bitwise-or -> Expression:
    left := parse-bitwise-xor
    while current.type == Token.OPERATOR and
        current.value == "|":
      consume Token.OPERATOR
      right := parse-bitwise-xor
      left = Binary "|" left right
    return left

  parse-bitwise-xor -> Expression:
    left := parse-bitwise-and
    while current.type == Token.OPERATOR and
        current.value == "^":
      consume Token.OPERATOR
      right := parse-bitwise-and
      left = Binary "^" left right
    return left

  parse-bitwise-and -> Expression:
    left := parse-shift
    while current.type == Token.OPERATOR and
        current.value == "&":
      consume Token.OPERATOR
      right := parse-shift
      left = Binary "&" left right
    return left

  parse-shift -> Expression:
    left := parse-additive
    while current.type == Token.OPERATOR and
        (current.value == "<<" or
          current.value == ">>" or
          current.value == ">>>"):
      op := current.value
      consume Token.OPERATOR
      right := parse-additive
      left = Binary op left right
    return left

  parse-additive -> Expression:
    left := parse-multiplicative
    while current.type == Token.OPERATOR and
        (current.value == "+" or
          current.value == "-"):
      op := current.value
      consume Token.OPERATOR
      right := parse-multiplicative
      left = Binary op left right
    return left

  parse-multiplicative -> Expression:
    left := parse-unary
    while current.type == Token.OPERATOR and
        (current.value == "*" or
          current.value == "/" or
          current.value == "%"):
      op := current.value
      consume Token.OPERATOR
      right := parse-unary
      left = Binary op left right
    return left

  parse-unary -> Expression:
    if current.type == Token.OPERATOR and
        (current.value == "-" or
          current.value == "~" or
          current.value == "!"):
      op := current.value
      consume Token.OPERATOR
      return Unary op parse-unary
    return parse-primary

  parse-primary -> Expression:
    if current.type == Token.NUMBER:
      value := current.value
      consume Token.NUMBER
      return Number value
    if current.type == Token.IDENTIFIER:
      name := current.value
      consume Token.IDENTIFIER
      if current.type == Token.LEFT-PAREN:
        consume Token.LEFT-PAREN
        args := []
        while current.type != Token.RIGHT-PAREN:
          args.add parse-expression
          if current.type == Token.COMMA: consume
        consume Token.RIGHT-PAREN
        function/Function? := functions.get name
        if not function:
          throw "undefined function: $(name)"
        if not function.arity_ == args.size:
          throw """wrong number of arguments to $(name): \
              expected $(function.arity_), got $(args.size)"""
        return Call function args
      return Reference name
    if current.type == Token.LEFT-PAREN:
      consume Token.LEFT-PAREN
      expression := parse-expression
      consume Token.RIGHT-PAREN
      return expression
    if current.type == Token.TRUE:
      consume Token.TRUE
      return Boolean "true"
    if current.type == Token.FALSE:
      consume Token.FALSE
      return Boolean "false"
    if current.type == Token.STRING:
      value := current.value
      consume Token.STRING
      return String value
    throw "unexpected token: $(current.value)"


current-dot-id-counter_ := 0
generate-dot-id_:
  return "node_$(current-dot-id-counter_++)"

class Program:
  body/List

  constructor .body:

  eval:
    scope := [{:}]
    body.do: it.eval scope (: throw "not in loop") (: throw "not in loop")

  dot-out:
    my-id := generate-dot-id_
    print "digraph ast {"
    print "  node [shape=box]"
    print "  $my-id [label=\"Program\"]"
    body.do: it.dot-out my-id ""
    print "}"

abstract class Statement:
  abstract eval scope/List [brek] [cont] -> any

  abstract dot-out parent/string edge-label/string

class Nop extends Statement:
  eval scope/List [brek] [cont] -> any:
    return null

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"Nop\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class Block extends Statement:
  statements/List

  constructor .statements:

  eval scope/List [brek] [cont] -> any:
    scope.add {:}
    statements.do: it.eval scope brek cont
    scope.resize (scope.size - 1)
    return null

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"...\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    statements.do: it.dot-out my-id ""

class Let extends Statement:
  name/string
  expression/Expression

  constructor .name .expression:

  eval scope/List [brek] [cont] -> any:
    value := expression.eval scope
    scope.last[name] = value
    return null

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$name :=\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    expression.dot-out my-id "value"

class If extends Statement:
  condition/Expression
  then/Statement
  els/Statement?

  constructor .condition .then .els:

  eval scope/List [brek] [cont]:
    if condition.eval scope:
      return then.eval scope brek cont
    else if els:
      return els.eval scope brek cont
    return null

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"if\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    condition.dot-out my-id "condition"
    then.dot-out my-id "then"
    if els:
      els.dot-out my-id "else"

class While extends Statement:
  condition/Expression
  body/Statement

  constructor .condition .body:

  eval scope/List [brek] [cont]:
    while condition.eval scope:
      body.eval scope (: return null) (:
        continue)
    return null

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"while\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    condition.dot-out my-id "condition"
    body.dot-out my-id "body"

class Continue extends Statement:
  eval scope/List [brek] [cont]:
    cont.call
    unreachable

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"continue\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class Break extends Statement:
  eval scope/List [brek] [cont]:
    brek.call
    unreachable

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"break\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class ExpressionStatement extends Statement:
  expression/Expression

  constructor .expression:

  eval scope/List [brek] [cont] -> any:
    return expression.eval scope

  dot-out parent/string edge-label/string:
    // No need to pollute the graph with expression statements.
    expression.dot-out parent edge-label

abstract class Expression:
  abstract eval scope/List -> any

  abstract dot-out parent/string edge-label/string

class Assignment extends Expression:
  left/Reference
  right/Expression

  constructor .left .right:

  eval scope/List -> any:
    name := left.name
    value := right.eval scope
    for i := scope.size - 1; i >= 0; i -= 1:
      if scope[i].contains name:
        scope[i][name] = value
        return value
    throw "undefined variable: $(name)"

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"=\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    left.dot-out my-id "left"
    right.dot-out my-id "right"

class Unary extends Expression:
  op/string
  expression/Expression

  constructor .op .expression:

  eval scope/List -> any:
    value := expression.eval scope
    if op == "-":
      return -value
    if op == "~":
      return ~value
    if op == "!":
      return not value
    throw "unexpected operator: $op"

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$op\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    expression.dot-out my-id "value"

class Binary extends Expression:
  op/string
  left/Expression
  right/Expression

  constructor .op .left .right:

  eval scope/List -> any:
    // Short-circuiting.
    left-value := left.eval scope
    if op == "&&" and not left-value:
      return false
    if op == "||" and left-value:
      return true

    right-value := right.eval scope
    if op == "+":
      if left-value is string or right-value is string:
        return "$left-value$right-value"
      return left-value + right-value
    if op == "-":
      return left-value - right-value
    if op == "*":
      return left-value * right-value
    if op == "/":
      return left-value * 1.0 / right-value
    if op == "%":
      return left-value % right-value
    if op == "&":
      return left-value & right-value
    if op == "|":
      return left-value | right-value
    if op == "^":
      return left-value ^ right-value
    if op == "&&":
      return left-value and right-value
    if op == "||":
      return left-value or right-value
    if op == "==":
      return left-value == right-value
    if op == "!=":
      return left-value != right-value
    if op == "<":
      return left-value < right-value
    if op == "<=":
      return left-value <= right-value
    if op == ">":
      return left-value > right-value
    if op == ">=":
      return left-value >= right-value
    if op == "<<":
      return left-value << right-value
    if op == ">>":
      return left-value >> right-value
    if op == ">>>":
      return left-value >>> right-value
    throw "unexpected operator: $(op)"

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$op\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    left.dot-out my-id "left"
    right.dot-out my-id "right"

class Number extends Expression:
  value/num

  constructor string-value/string:
    value = num-parse string-value

  eval scope/List -> any:
    return value

  static num-parse string-value/string -> num:
    return int.parse string-value --if-error=:
      return float.parse string-value

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$value\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class Reference extends Expression:
  name/string

  constructor .name:

  eval scope/List -> any:
    for i := scope.size - 1; i >= 0; i -= 1:
      if scope[i].contains name:
        return scope[i][name]
    throw "undefined variable: $(name)"

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$name\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class Call extends Expression:
  function/Function
  args/List

  constructor .function .args:

  eval scope/List -> any:
    evaluated-args := args.map: it.eval scope
    return function.action.call evaluated-args

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$function.name()\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
    for i := 0; i < args.size; i += 1:
      args[i].dot-out my-id "arg $i"

class Boolean extends Expression:
  value/bool

  constructor string-value/string:
    value = string-value == "true"

  eval scope/List -> any:
    return value

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"$value\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"

class String extends Expression:
  value/string

  constructor .value:

  eval scope/List -> any:
    return value[1 .. value.size - 1]

  dot-out parent/string edge-label/string:
    my-id := generate-dot-id_
    print "  $my-id [label=\"'$value'\"]"
    print "  $parent -> $my-id [label=\"$edge-label\"]"
