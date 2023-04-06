// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import device_bot show *
import device_bot.interpreter show *
import expect show *

main:
  test_primary
  test_unary
  test_binary
  test_precedence
  test_short_circuit
  test_statements
  test_builtins
  test_openai_programs
  test_instruction_example

run_expression program/Program --allow_multiple_statements/bool=false:
  if not allow_multiple_statements:
    expect_equals 1 program.body.size
  scope := [{:}]
  for i := 0 ; i < program.body.size - 1; i++:
    (program.body[i] as Statement).eval scope (: throw "break") (: throw "continue")
  statement := program.body.last
  expect statement is ExpressionStatement
  return (statement as ExpressionStatement).expression.eval scope

test_primary:
  node := parse "1;" []
  expect_equals 1 (run_expression node)

  node = parse "1.0;" []
  expect_equals 1.0 (run_expression node)

  node = parse "true;" []
  expect_equals true (run_expression node)

  node = parse "false;" []
  expect_equals false (run_expression node)

  node = parse "\"foo\";" []
  expect_equals "foo" (run_expression node)

  node = parse "(1);" []
  expect_equals 1 (run_expression node)

  node = parse "let x = 1; x;" []
  expect_equals
      1
      run_expression node --allow_multiple_statements

  node = parse "list_create();" []
  expect_equals [] (run_expression node)

test_unary:
  node := parse "-1;" []
  expect_equals -1 (run_expression node)

  node = parse "-1.0;" []
  expect_equals -1.0 (run_expression node)

  node = parse "~1;" []
  expect_equals -2 (run_expression node)

  node = parse "!true;" []
  expect_equals false (run_expression node)

  node = parse "!false;" []
  expect_equals true (run_expression node)


test_binary:
  // Additive:
  node := parse "1 + 2;" []
  expect_equals 3 (run_expression node)

  node = parse "1 - 2;" []
  expect_equals -1 (run_expression node)

  // Multiplicative:
  node = parse "2 * 3;" []
  expect_equals 6 (run_expression node)

  node = parse "8 / 2;" []
  expect_equals 4 (run_expression node)

  node = parse "8 % 3;" []
  expect_equals 2 (run_expression node)

  // Bitwise:
  node = parse "7 & 2;" []
  expect_equals 2 (run_expression node)

  node = parse "10 | 9;" []
  expect_equals 11 (run_expression node)

  node = parse "10 ^ 9;" []
  expect_equals 3 (run_expression node)

  node = parse "~10;" []
  expect_equals -11 (run_expression node)

  node = parse "3 << 2;" []
  expect_equals 12 (run_expression node)

  node = parse "12 >> 2;" []
  expect_equals 3 (run_expression node)

  node = parse "-1 >>> 60;" []
  expect_equals 15 (run_expression node)

  // Relational:
  node = parse "1 < 2;" []
  expect_equals true (run_expression node)

  node = parse "2 < 1;" []
  expect_equals false (run_expression node)

  node = parse "1 < 1;" []
  expect_equals false (run_expression node)

  node = parse "1 <= 2;" []
  expect_equals true (run_expression node)

  node = parse "2 <= 1;" []
  expect_equals false (run_expression node)

  node = parse "1 <= 1;" []
  expect_equals true (run_expression node)

  node = parse "1 > 2;" []
  expect_equals false (run_expression node)

  node = parse "2 > 1;" []
  expect_equals true (run_expression node)

  node = parse "1 > 1;" []
  expect_equals false (run_expression node)

  node = parse "1 >= 2;" []
  expect_equals false (run_expression node)

  node = parse "2 >= 1;" []
  expect_equals true (run_expression node)

  // Equality:
  node = parse "1 == 2;" []
  expect_equals false (run_expression node)

  node = parse "2 == 1;" []
  expect_equals false (run_expression node)

  node = parse "1 == 1;" []
  expect_equals true (run_expression node)

  node = parse "1 != 2;" []
  expect_equals true (run_expression node)

  node = parse "2 != 1;" []
  expect_equals true (run_expression node)

  node = parse "1 != 1;" []
  expect_equals false (run_expression node)

  // Logical:
  node = parse "true && true;" []
  expect_equals true (run_expression node)

  node = parse "true && false;" []
  expect_equals false (run_expression node)

  node = parse "false && false;" []
  expect_equals false (run_expression node)

  node = parse "false && true;" []
  expect_equals false (run_expression node)

  node = parse "true || true;" []
  expect_equals true (run_expression node)

  node = parse "true || false;" []
  expect_equals true (run_expression node)

  node = parse "false || false;" []
  expect_equals false (run_expression node)

  node = parse "false || true;" []
  expect_equals true (run_expression node)

  // Floating point operations:
  node = parse "1.5 + 2.0;" []
  expect_equals 3.5 (run_expression node)

  node = parse "1.0 - 2.5;" []
  expect_equals -1.5 (run_expression node)

  node = parse "2.5 * 3.0;" []
  expect_equals 7.5 (run_expression node)

  node = parse "8.5 / 2.0;" []
  expect_equals 4.25 (run_expression node)

  node = parse "8.5 % 3.0;" []
  expect_equals 2.5 (run_expression node)

  node = parse "1.5 < 2.0;" []
  expect_equals true (run_expression node)

  node = parse "2.5 < 1.0;" []
  expect_equals false (run_expression node)

  // Floating point wins over integer:
  node = parse "1 + 2.0;" []
  expect_equals 3.0 (run_expression node)

  node = parse "1.0 + 2;" []
  expect_equals 3.0 (run_expression node)

  node = parse "1.0 < 2;" []
  expect_equals true (run_expression node)

  // String concatenation:
  node = parse "\"a\" + \"b\";" []
  expect_equals "ab" (run_expression node)

  node = parse "\"a\" + 1;" []
  expect_equals "a1" (run_expression node)

  node = parse "1 + \"b\";" []
  expect_equals "1b" (run_expression node)

  // Assignment.
  node = parse "let a = 2; a = 1;" []
  expect_equals 1
      run_expression node --allow_multiple_statements

test_precedence:
  // Expected order:
  // 1. Unary
  // 2. Multiplicative
  // 3. Additive
  // 4. Shift
  // 5. Bitwise AND
  // 6. Bitwise XOR
  // 7. Bitwise OR
  // 8. Relational
  // 9. Equality
  // 10. Logical AND
  // 11. Logical OR
  // 12. Assignment

  node := parse "-1 * 2;" []
  // Not like we can detect a difference...
  expect_equals -2 (run_expression node)

  node = parse "1 * -2;" []
  // Not like we can detect a difference...
  expect_equals -2 (run_expression node)

  node = parse "~1 * 2;" []
  expect_equals -4 (run_expression node)

  node = parse "3 * ~2;" []
  expect_equals -9 (run_expression node)

  node = parse "1 * 2 + 3;" []
  expect_equals 5 (run_expression node)

  node = parse "1 + 2 * 3;" []
  expect_equals 7 (run_expression node)

  node = parse "1 << 2 + 3;" []
  expect_equals 32 (run_expression node)

  node = parse "1 + 2 << 3;" []
  expect_equals 24 (run_expression node)

  node = parse "1 & 2 + 3;" []
  expect_equals 1 (run_expression node)

  node = parse "1 + 2 & 3;" []
  expect_equals 3 (run_expression node)

  node = parse "1 ^ 2 + 3;" []
  expect_equals 4 (run_expression node)

  node = parse "1 & 3 ^ 3;" []
  expect_equals 2 (run_expression node)

  node = parse "1 ^ 3 & 3;" []
  expect_equals 2 (run_expression node)

  node = parse "1 | 2 ^ 3;" []
  expect_equals 1 (run_expression node)

  node = parse "1 ^ 3 | 1;" []
  expect_equals 3 (run_expression node)

  node = parse "1 < 2 | 3;" []
  expect_equals true (run_expression node)

  node = parse "1 | 3 < 2;" []
  expect_equals false (run_expression node)

  node = parse "1 == 2 | 3;" []
  expect_equals false (run_expression node)

  node = parse "1 | 3 == 2;" []
  expect_equals false (run_expression node)

  node = parse "1 == 1 && 2 == 3;" []
  expect_equals false (run_expression node)

  node = parse "1 == 1 && 2 == 2;" []
  expect_equals true (run_expression node)

  node = parse "1 == 1 || 2 == 3;" []
  expect_equals true (run_expression node)

  node = parse "1 == 2 || 2 == 3;" []
  expect_equals false (run_expression node)

  node = parse "let a = 1; a = true && 1 == 2;" []
  expect_equals false
      run_expression node --allow_multiple_statements

  node = parse "let a = 1; a = true && 1 == 1;" []
  expect_equals true
      run_expression node --allow_multiple_statements

  node = parse "let a = 1; a = true || 1 == 2;" []
  expect_equals true
      run_expression node --allow_multiple_statements

  node = parse "let a = 1; a = false || 1 == 2;" []
  expect_equals false
      run_expression node --allow_multiple_statements

run_with_log code/string -> List:
  log := []
  functions := [
    Function
        --syntax="sleep(<x>)"
        --description="Sleep x ms"
        --action=:: | args/List |
          ms := args[0]
          log.add "sleep --ms=$ms",
    Function
        --syntax="print(<message>)"
        --description="Print a message"
        --action=:: | args/List |
          message := args[0]
          log.add "print $message",
    Function
        --syntax="identity(x)"
        --description="Returns argument x"
        --action=:: | args/List |
          x := args[0]
          log.add "identity $x"
          x,
  ]

  program := parse code functions
  program.eval
  return log

test_short_circuit:
  // Short-circuiting AND.
  log := run_with_log "true && identity(true);"
  expect_equals ["identity true"] log

  log = run_with_log "false && identity(true);"
  expect_equals [] log

  // Short-circuiting OR.
  log = run_with_log "true || identity(true);"
  expect_equals [] log

  log = run_with_log "false || identity(true);"
  expect_equals ["identity true"] log

test_statements:
  // Statements are evaluated in order.
  log := run_with_log """
    print("Hello");
    print("World");
  """
  expect_equals [
    "print Hello",
    "print World",
  ] log

  // Let statements.
  log = run_with_log """
    let a = 1;
    print(a);
  """
  expect_equals [
    "print 1",
  ] log

  // Let statements with expressions.
  log = run_with_log """
    let a = 1 + 2;
    print(a);
  """
  expect_equals [
    "print 3",
  ] log

  // While loops.
  log = run_with_log """
    let i = 0;
    while (i < 3) {
      print(i);
      i = i + 1;
    }
  """
  expect_equals [
    "print 0",
    "print 1",
    "print 2",
  ] log

  // Empty while.
  log = run_with_log """
    while (false) {
      print("This should never print");
    }
  """
  expect_equals [] log

  // While with statement not block.
  log = run_with_log """
    let list = list_create();
    while (list_size(list) < 3) list_add(list, 1);
    print(list_size(list));
  """
  expect_equals [
    "print 3",
  ] log

  // Continue.
  log = run_with_log """
    let i = 0;
    while (i < 3) {
      if (i == 1) {
        i = i + 1;
        continue;
      }
      print(i);
      i = i + 1;
    }
  """
  expect_equals [
    "print 0",
    "print 2",
  ] log

  // Nested continue.
  log = run_with_log """
    let i = 0;
    while (i < 3) {
      if (i == 1) {
        i = i + 1;
        continue;
      }
      print("i" + i);
      let j = 0;
      while (j < 3) {
        if (j == 1) {
          j = j + 1;
          continue;
        }
        print("j" + j);
        j = j + 1;
      }
      i = i + 1;
    }
  """
  expect_equals [
    "print i0",
    "print j0",
    "print j2",
    "print i2",
    "print j0",
    "print j2",
  ] log

  // Break.
  log = run_with_log """
    let i = 0;
    while (i < 3) {
      if (i == 1) {
        break;
      }
      print(i);
      i = i + 1;
    }
    print(i);
  """
  expect_equals [
    "print 0",
    "print 1",
  ] log

  // Nested break.
  log = run_with_log """
    let i = 0;
    while (i < 3) {
      if (i == 2) {
        break;
      }
      print("i" + i);
      i = i + 1;
      let j = 0;
      while (j < 3) {
        if (j == i) {
          break;
        }
        print("j" + j);
        j = j + 1;
      }
    }
  """
  expect_equals [
    "print i0",
    "print j0",
    "print i1",
    "print j0",
    "print j1",
  ] log

  // If statements.
  log = run_with_log """
    if (true) {
      print("This should print");
    }
  """
  expect_equals ["print This should print"] log

  log = run_with_log """
    if (false) {
      print("This should never print");
    }
  """
  expect_equals [] log

  // If with statement not block.
  log = run_with_log """
    if (true) print("This should print");
  """
  expect_equals ["print This should print"] log

  // If-else statements.
  log = run_with_log """
    if (true) {
      print("This should print");
    } else {
      print("This should never print");
    }
  """
  expect_equals ["print This should print"] log

  log = run_with_log """
    if (false) {
      print("This should never print");
    } else {
      print("This should print");
    }
  """
  expect_equals ["print This should print"] log

  // If-else with statement not block.
  log = run_with_log """
    if (true) print("This should print");
    else print("This should never print");
  """
  expect_equals ["print This should print"] log

  log = run_with_log """
    if (false) print("This should never print");
    else print("This should print");
  """
  expect_equals ["print This should print"] log

  // Test nops.
  log = run_with_log ";"
  expect_equals [] log

  log = run_with_log """
    if (true);
  """
  expect_equals [] log

  log = run_with_log """
    if (false); else print("This should print");
  """
  expect_equals ["print This should print"] log

  log = run_with_log """
    if (true) {
    }
  """
  expect_equals [] log

test_builtins:
  // No real way to test 'print'.

  // Sleep.
  // We run some simple code 10 times and measure how long it takes.
  // Then we sleep twice that amount and check that the time elapsed.
  program := parse "1+1;" []
  duration := Duration.of:
    10.repeat:
      program.eval
  sleep_duration := duration * 2
  in_ms := sleep_duration.in_ms
  if in_ms == 0: in_ms = 1
  program = parse "sleep($in_ms);" []
  measured := Duration.of:
    program.eval
  expect measured > sleep_duration

  // List functions.
  // - list_create
  // - list_add
  // - list_get
  // - list_set
  // - list_size
  program = parse """
    let list = list_create();
    let list2 = list_create();
    list_add(list, 1);
    list_add(list, 2);
    list_add(list, 3);
    list_add(list2, list_get(list, 2));
    list_add(list2, list_get(list, 1));
    list_add(list2, list_get(list, 0));
    list_set(list, 1, 4);
    let i = 0;
    while (i < list_size(list)) {
      list_add(list2, list_get(list, i));
      i = i + 1;
    }
    list2;
  """ []

  result := run_expression program --allow_multiple_statements
  expect_equals [3, 2, 1, 1, 4, 3] result

/**
Test OpenAI programs.

These aren't really pinnacles of programming, but that's what our
  interpreter has to deal with.
*/
test_openai_programs:
  PROGRAM ::= """
    let reminder = true;
    if (reminder) {
      print("Don't forget to look after your noodles!");

      let currentTime = 0;
      while (currentTime < 3000) {
          sleep(1000);
          currentTime = currentTime + 1000;
      }

      print("Remember to put them in the fridge.");
      sleep(17000);
      print("You can do anything you put your mind to!");
    }
  """
  expected := [
    "print Don't forget to look after your noodles!",
    "sleep --ms=1000",
    "sleep --ms=1000",
    "sleep --ms=1000",
    "print Remember to put them in the fridge.",
    "sleep --ms=17000",
    "print You can do anything you put your mind to!",
  ]
  expect_equals
      expected
      run_with_log PROGRAM

  PROGRAM2 ::= """
    let remind = true;
    let message = false;

    if (remind) {
      let noodlesDone = false;
      let timeToRemind = 30000;

      sleep(timeToRemind);

      while (!noodlesDone) {
        sleep(20000);
        message = true;
        noodlesDone = true;
      }
    }

    if (message) {
      print("Way to go, champ!");
    }"""
  expected = [
    "sleep --ms=30000",
    "sleep --ms=20000",
    "print Way to go, champ!",
  ]
  expect_equals
      expected
      run_with_log PROGRAM2

  PROGRAM3 ::= """
    let message = "Don't forget about your noodles! Keep up the good work!";
    sleep(30000);
    print(message);
    sleep(20000);
    print("You're doing great!");
  """
  expected = [
    "sleep --ms=30000",
    "print Don't forget about your noodles! Keep up the good work!",
    "sleep --ms=20000",
    "print You're doing great!",
  ]
  expect_equals
      expected
      run_with_log PROGRAM3

test_instruction_example:
  // Make sure the example we send to OpenAI is actually correct...
  EXAMPLE ::= """
    // Create a map from numbers to their squares.
    let map = map_create();
    let i = 0;
    let sum = 0;
    while (i < 10) {
      map_set(map, i, i * i);
      sum = sum + i * i;
      i = i + 1;
    }
    // Print the map.
    print(map);
    // Print the square of 5.
    print(map_get(map, 5));

    let keys = map_keys(map);
    // Print the element in the middle of the key list.
    print(list_get(keys, list_size(keys) / 2));
    // Print the average of the squares.
    print(sum * 1.0 / list_size(keys));
  """
  expected := [
    "print {0: 0, 1: 1, 2: 4, 3: 9, 4: 16, 5: 25, 6: 36, 7: 49, 8: 64, 9: 81}",
    "print 25",
    "print 5",
    "print 28.5",
  ]
  expect_equals
      expected
      run_with_log EXAMPLE
