// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .device_bot

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
    paren_start := syntax.index_of "("
    name = syntax[..paren_start].trim
    paren_end := syntax.index_of ")"
    params := syntax[paren_start + 1..paren_end]
    if params.trim == "":
      arity_ = 0
    else:
      count := 0
      start_offset := 0
      while start_offset < params.size:
        start_offset = params.index_of "," start_offset
        if start_offset == -1:
          break
        count++
        start_offset++
      arity_ = count + 1

BUILTINS ::= [
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
          ms := args[0]
          sleep --ms=ms,
  Function
      --syntax="random(<min>, <max>)"
      --description="Returns a random integer between min and max."
      --action=:: | args |
          min := args[0]
          max := args[1]
          random min max,
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
          index := args[1]
          list[index],
  Function
      --syntax="list_set(<list>, <index>, <value>)"
      --description="Sets a value in a list."
      --action=:: | args |
          list/List := args[0]
          index := args[1]
          value := args[2]
          list[index] = value,
  Function
      --syntax="list_size(<list>)"
      --description="Returns the size of a list."
      --action=:: | args |
          list/List := args[0]
          list.size,
]

builtins_description -> string:
  result := ""
  BUILTINS.do: | function/Function |
      result += "- $function.syntax: $function.description\n"
  return result

parse code/string user_functions/List -> Program:
  scanner := Scanner code
  parser := Parser scanner BUILTINS user_functions
  return parser.parse_program

class Scanner:
  code/string
  position/int := 0

  constructor .code:

  next -> Token:
    if position >= code.size:
      return Token Token.TYPE_EOF ""

    keep_removing_spaces_and_comments := true
    while keep_removing_spaces_and_comments:
      keep_removing_spaces_and_comments = false

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
        keep_removing_spaces_and_comments = true


    if position >= code.size:
      return Token Token.TYPE_EOF ""

    c := code[position]

    if c == '+' or
        c == '-' or
        c == '*' or
        c == '/' or
        c == '%' or
        c == '^' or
        c == '~':
      position++
      return Token Token.TYPE_OPERATOR (string.from_rune c)

    if c == '<':
      if peek == '<':
        position += 2
        return Token Token.TYPE_OPERATOR "<<"
      if peek == '=':
        position += 2
        return Token Token.TYPE_OPERATOR "<="
      position++
      return Token Token.TYPE_OPERATOR "<"

    if c == '>':
      if peek == '>':
        if (peek 2) == '>':
          position += 3
          return Token Token.TYPE_OPERATOR ">>>"
        position += 2
        return Token Token.TYPE_OPERATOR ">>"
      if peek == '=':
        position += 2
        return Token Token.TYPE_OPERATOR ">="
      position++
      return Token Token.TYPE_OPERATOR ">"

    if c == '!':
      if peek == '=':
        position += 2
        return Token Token.TYPE_OPERATOR "!="
      position++
      return Token Token.TYPE_OPERATOR "!"

    if c == '=':
      if peek == '=':
        position += 2
        return Token Token.TYPE_OPERATOR "=="
      position++
      return Token Token.TYPE_OPERATOR "="

    if c == '&':
      if peek == '&':
        position += 2
        return Token Token.TYPE_OPERATOR "&&"
      position++
      return Token Token.TYPE_OPERATOR "&"

    if c == '|':
      if peek == '|':
        position += 2
        return Token Token.TYPE_OPERATOR "||"
      position++
      return Token Token.TYPE_OPERATOR "|"

    if c == '(':
      position++
      return Token Token.TYPE_LEFT_PAREN "("

    if c == ')':
      position++
      return Token Token.TYPE_RIGHT_PAREN ")"

    if c == '{':
      position++
      return Token Token.TYPE_LEFT_BRACE "{"

    if c == '}':
      position++
      return Token Token.TYPE_RIGHT_BRACE "}"

    if c == 'i' and
        peek == 'f' and
        not is_identifier (peek 2):
      position += 2
      return Token Token.TYPE_IF "if"

    if c == 'e' and
        peek == 'l' and
        (peek 2) == 's' and
        (peek 3) == 'e' and
        not is_identifier (peek 4):
      position += 4
      return Token Token.TYPE_ELSE "else"

    if c == 'w' and
        peek == 'h' and
        (peek 2) == 'i' and
        (peek 3) == 'l' and
        (peek 4) == 'e' and
        not is_identifier (peek 5):
      position += 5
      return Token Token.TYPE_WHILE "while"

    if c == 'l' and
        peek == 'e' and
        (peek 2) == 't' and
        not is_identifier (peek 3):
      position += 3
      return Token Token.TYPE_LET "let"

    if c == 't' and
        peek == 'r' and
        (peek 2) == 'u' and
        (peek 3) == 'e' and
        not is_identifier (peek 4):
      position += 4
      return Token Token.TYPE_TRUE "true"

    if c == 'f' and
        peek == 'a' and
        (peek 2) == 'l' and
        (peek 3) == 's' and
        (peek 4) == 'e' and
        not is_identifier (peek 5):
      position += 5
      return Token Token.TYPE_FALSE "false"

    if is_identifier_start c:
      start := position
      position++
      while is_identifier current:
        position++
      return Token Token.TYPE_IDENTIFIER code[start..position].copy

    if '0' <= c <= '9':
      start := position
      position++
      while '0' <= current <= '9':
        position++
      if current == '.':
        position++
        while '0' <= current <= '9':
          position++
      return Token Token.TYPE_NUMBER code[start..position].copy

    if c == '"':
      start := position
      position++
      while current != '"' and current != -1:
        position++
      if current == -1:
        throw "unterminated string"
      position++
      return Token Token.TYPE_STRING code[start..position].copy

    if c == ';':
      position++
      return Token Token.TYPE_SEQUENCE_SEPARATOR ";"

    throw "unexpected character: $(string.from_rune c)"

  current -> int:
    if position < code.size:
      return code[position]
    return -1

  peek n/int=1 -> int:
    if position < code.size - n:
      return code[position + n]
    return -1

  is_identifier_start c/int --start/bool=false -> bool:
    return 'a' <= c <= 'z' or 'A' <= c <= 'Z' or c == '_'

  is_identifier c/int -> bool:
    return is_identifier_start c or '0' <= c <= '9'

class Token:
  static TYPE_EOF ::= 0
  static TYPE_NUMBER ::= 1
  static TYPE_OPERATOR ::= 2
  static TYPE_LEFT_PAREN ::= 3
  static TYPE_RIGHT_PAREN ::= 4
  static TYPE_IF ::= 5
  static TYPE_ELSE ::= 6
  static TYPE_WHILE ::= 7
  static TYPE_LET ::= 8
  static TYPE_IDENTIFIER ::= 9
  static TYPE_LEFT_BRACE ::= 10
  static TYPE_RIGHT_BRACE ::= 11
  static TYPE_TRUE ::= 13
  static TYPE_FALSE ::= 14
  static TYPE_STRING ::= 15
  static TYPE_SEQUENCE_SEPARATOR ::= 16

  type/int
  value/string

  constructor .type .value:

  stringify -> string:
    return "Token($(type) $(value))"

class Parser:
  scanner_/Scanner
  current/Token? := null
  functions/Map

  constructor .scanner_ builtins_list/List user_function_list/List:
    functions = {:}
    builtins_list.do: | function/Function |
      functions[function.name] = function

    // User functions override builtins.
    user_function_list.do: | function/Function |
      functions[function.name] = function

  consume -> none:
    current = scanner_.next

  consume type/int -> none:
    if current.type != type:
      throw "expected $type, got $current.type $current.value"
    consume

  consume type/int value/string -> none:
    if current.type != type or current.value != value:
      throw "expected $(type) $(value)"
    consume

  parse_program -> Program:
    current = scanner_.next
    body := []
    is_first := true
    while current.type != Token.TYPE_EOF:
      body.add parse_statement
      while current.type == Token.TYPE_SEQUENCE_SEPARATOR:
        consume
    consume Token.TYPE_EOF
    return Program body

  parse_statement -> Statement:
    if current.type == Token.TYPE_LEFT_BRACE:
      return parse_block
    if current.type == Token.TYPE_LET:
      return parse_let
    if current.type == Token.TYPE_IF:
      return parse_if
    if current.type == Token.TYPE_WHILE:
      return parse_while
    if current.type == Token.TYPE_SEQUENCE_SEPARATOR:
      return Nop
    return ExpressionStatement parse_expression

  parse_block -> Block:
    consume Token.TYPE_LEFT_BRACE
    nodes := []
    while current.type != Token.TYPE_RIGHT_BRACE and current.type != Token.TYPE_EOF:
      node := parse_statement
      nodes.add node
      if current.type == Token.TYPE_SEQUENCE_SEPARATOR:
        consume Token.TYPE_SEQUENCE_SEPARATOR
    consume Token.TYPE_RIGHT_BRACE
    return Block nodes

  parse_let -> Let:
    consume Token.TYPE_LET
    if current.type != Token.TYPE_IDENTIFIER:
      throw "expected identifier"
    name := current.value
    consume Token.TYPE_IDENTIFIER
    consume Token.TYPE_OPERATOR "="
    expression := parse_expression
    return Let name expression

  parse_if -> If:
    consume Token.TYPE_IF
    consume Token.TYPE_LEFT_PAREN
    condition := parse_expression
    consume Token.TYPE_RIGHT_PAREN
    then := parse_statement
    if current.type == Token.TYPE_ELSE:
      consume Token.TYPE_ELSE
      else_ := parse_statement
      return If condition then else_
    return If condition then null

  parse_while -> While:
    consume Token.TYPE_WHILE
    consume Token.TYPE_LEFT_PAREN
    condition := parse_expression
    consume Token.TYPE_RIGHT_PAREN
    body := parse_statement
    return While condition body

  parse_expression -> Expression:
    return parse_assignment

  parse_assignment -> Expression:
    left := parse_logical_or
    if current.type == Token.TYPE_OPERATOR and
        current.value == "=":
      consume Token.TYPE_OPERATOR
      if left is not Reference:
        throw "expected identifier on left side of assignment"
      right := parse_assignment
      return Assignment (left as Reference) right
    return left

  parse_logical_or -> Expression:
    left := parse_logical_and
    while current.type == Token.TYPE_OPERATOR and
        current.value == "||":
      consume Token.TYPE_OPERATOR
      right := parse_logical_and
      left = Binary "||" left right
    return left

  parse_logical_and -> Expression:
    left := parse_equality
    while current.type == Token.TYPE_OPERATOR and
        current.value == "&&":
      consume Token.TYPE_OPERATOR
      right := parse_equality
      left = Binary "&&" left right
    return left

  parse_equality -> Expression:
    left := parse_comparison
    while current.type == Token.TYPE_OPERATOR and
        (current.value == "==" or
          current.value == "!="):
      op := current.value
      consume Token.TYPE_OPERATOR
      right := parse_comparison
      left = Binary op left right
    return left

  parse_comparison -> Expression:
    left := parse_bitwise_or
    while current.type == Token.TYPE_OPERATOR and
        (current.value == "<" or
          current.value == ">" or
          current.value == "<=" or
          current.value == ">="):
      op := current.value
      consume Token.TYPE_OPERATOR
      right := parse_bitwise_or
      left = Binary op left right
    return left

  parse_bitwise_or -> Expression:
    left := parse_bitwise_xor
    while current.type == Token.TYPE_OPERATOR and
        current.value == "|":
      consume Token.TYPE_OPERATOR
      right := parse_bitwise_xor
      left = Binary "|" left right
    return left

  parse_bitwise_xor -> Expression:
    left := parse_bitwise_and
    while current.type == Token.TYPE_OPERATOR and
        current.value == "^":
      consume Token.TYPE_OPERATOR
      right := parse_bitwise_and
      left = Binary "^" left right
    return left

  parse_bitwise_and -> Expression:
    left := parse_shift
    while current.type == Token.TYPE_OPERATOR and
        current.value == "&":
      consume Token.TYPE_OPERATOR
      right := parse_shift
      left = Binary "&" left right
    return left

  parse_shift -> Expression:
    left := parse_additive
    while current.type == Token.TYPE_OPERATOR and
        (current.value == "<<" or
          current.value == ">>" or
          current.value == ">>>"):
      op := current.value
      consume Token.TYPE_OPERATOR
      right := parse_additive
      left = Binary op left right
    return left

  parse_additive -> Expression:
    left := parse_multiplicative
    while current.type == Token.TYPE_OPERATOR and
        (current.value == "+" or
          current.value == "-"):
      op := current.value
      consume Token.TYPE_OPERATOR
      right := parse_multiplicative
      left = Binary op left right
    return left

  parse_multiplicative -> Expression:
    left := parse_unary
    while current.type == Token.TYPE_OPERATOR and
        (current.value == "*" or
          current.value == "/" or
          current.value == "%"):
      op := current.value
      consume Token.TYPE_OPERATOR
      right := parse_unary
      left = Binary op left right
    return left

  parse_unary -> Expression:
    if current.type == Token.TYPE_OPERATOR and
        (current.value == "-" or
          current.value == "~" or
          current.value == "!"):
      op := current.value
      consume Token.TYPE_OPERATOR
      return Unary op parse_unary
    return parse_primary

  parse_primary -> Expression:
    if current.type == Token.TYPE_NUMBER:
      value := current.value
      consume Token.TYPE_NUMBER
      return Number value
    if current.type == Token.TYPE_IDENTIFIER:
      name := current.value
      consume Token.TYPE_IDENTIFIER
      if current.type == Token.TYPE_LEFT_PAREN:
        consume Token.TYPE_LEFT_PAREN
        args := []
        while current.type != Token.TYPE_RIGHT_PAREN:
          args.add parse_expression
          if current.type == Token.TYPE_OPERATOR and
              current.value == ",":
            consume Token.TYPE_OPERATOR ","
        consume Token.TYPE_RIGHT_PAREN
        function/Function? := functions.get name
        if not function:
          throw "undefined function: $(name)"
        if not function.arity_ == args.size:
          throw """wrong number of arguments to $(name): \
              expected $(function.arity_), got $(args.size)"""
        return Call function args
      return Reference name
    if current.type == Token.TYPE_LEFT_PAREN:
      consume Token.TYPE_LEFT_PAREN
      expression := parse_expression
      consume Token.TYPE_RIGHT_PAREN
      return expression
    if current.type == Token.TYPE_TRUE:
      consume Token.TYPE_TRUE
      return Boolean "true"
    if current.type == Token.TYPE_FALSE:
      consume Token.TYPE_FALSE
      return Boolean "false"
    if current.type == Token.TYPE_STRING:
      value := current.value
      consume Token.TYPE_STRING
      return String value
    throw "unexpected token: $(current.value)"

abstract class Node:
  abstract eval scope/List -> any

class Program:
  body/List

  constructor .body:

  eval:
    scope := [{:}]
    body.do: it.eval scope

abstract class Statement extends Node:
  abstract eval scope/List -> any

class Nop extends Statement:
  eval scope/List:
    return null

class Block extends Statement:
  statements/List

  constructor .statements:

  eval scope/List -> any:
    scope.add {:}
    statements.do: it.eval scope
    scope.resize (scope.size - 1)
    return null

class Let extends Statement:
  name/string
  expression/Expression

  constructor .name .expression:

  eval scope/List:
    value := expression.eval scope
    scope.last[name] = value
    return null

class If extends Statement:
  condition/Expression
  then/Statement
  els/Statement?

  constructor .condition .then .els:

  eval scope/List:
    t := condition.eval scope
    if condition.eval scope:
      then.eval scope
      return null
    if els:
      return els.eval scope
    return null

class While extends Statement:
  condition/Expression
  body/Statement

  constructor .condition .body:

  eval scope/List:
    while condition.eval scope:
      body.eval scope
    return null

class ExpressionStatement extends Statement:
  expression/Expression

  constructor .expression:

  eval scope/List:
    return expression.eval scope

abstract class Expression extends Node:
  abstract eval scope/List -> any

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
    throw "unexpected operator: $(op)"

class Binary extends Expression:
  op/string
  left/Expression
  right/Expression

  constructor .op .left .right:

  eval scope/List -> any:
    left_value := left.eval scope
    right_value := right.eval scope
    if op == "+":
      if left_value is String or right_value is String:
        return left_value.stringify + right_value.stringify
      return left_value + right_value
    if op == "-":
      return left_value - right_value
    if op == "*":
      return left_value * right_value
    if op == "/":
      return left_value / right_value
    if op == "%":
      return left_value % right_value
    if op == "&":
      return left_value & right_value
    if op == "|":
      return left_value | right_value
    if op == "^":
      return left_value ^ right_value
    if op == "&&":
      return left_value and right_value
    if op == "||":
      return left_value or right_value
    if op == "==":
      return left_value == right_value
    if op == "!=":
      return left_value != right_value
    if op == "<":
      return left_value < right_value
    if op == "<=":
      return left_value <= right_value
    if op == ">":
      return left_value > right_value
    if op == ">=":
      return left_value >= right_value
    if op == "<<":
      return left_value << right_value
    if op == ">>":
      return left_value >> right_value
    if op == ">>>":
      return left_value >>> right_value
    throw "unexpected operator: $(op)"

class Number extends Expression:
  value/num

  constructor string_value/string:
    value = num_parse string_value

  eval scope/List -> any:
    return value

  static num_parse string_value/string -> num:
    return int.parse string_value --on_error=:
      return float.parse string_value

class Reference extends Expression:
  name/string

  constructor .name:

  eval scope/List -> any:
    for i := scope.size - 1; i >= 0; i -= 1:
      if scope[i].contains name:
        return scope[i][name]
    throw "undefined variable: $(name)"

class Call extends Expression:
  function/Function
  args/List

  constructor .function .args:

  eval scope/List -> any:
    evaluated_args := args.map: it.eval scope
    return function.action.call evaluated_args

class Boolean extends Expression:
  value/bool

  constructor string_value/string:
    value = string_value == "true"

  eval scope/List -> any:
    return value

class String extends Expression:
  value/string

  constructor .value:

  eval scope/List -> any:
    return value[1 .. value.size - 1]
