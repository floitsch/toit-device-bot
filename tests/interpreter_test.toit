// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import device-bot show *
import device-bot.interpreter show *
import expect show *

main:
  test-primary
  test-unary
  test-binary
  test-precedence
  test-short-circuit
  test-statements
  test-builtins
  test-openai-programs
  test-instruction-example

run-expression program/Program --allow-multiple-statements/bool=false:
  if not allow-multiple-statements:
    expect-equals 1 program.body.size
  scope := [{:}]
  for i := 0 ; i < program.body.size - 1; i++:
    (program.body[i] as Statement).eval scope (: throw "break") (: throw "continue")
  statement := program.body.last
  expect statement is ExpressionStatement
  return (statement as ExpressionStatement).expression.eval scope

test-primary:
  node := parse "1;" []
  expect-equals 1 (run-expression node)

  node = parse "1.0;" []
  expect-equals 1.0 (run-expression node)

  node = parse "true;" []
  expect-equals true (run-expression node)

  node = parse "false;" []
  expect-equals false (run-expression node)

  node = parse "\"foo\";" []
  expect-equals "foo" (run-expression node)

  node = parse "(1);" []
  expect-equals 1 (run-expression node)

  node = parse "let x = 1; x;" []
  expect-equals
      1
      run-expression node --allow-multiple-statements

  node = parse "list_create();" []
  expect-equals [] (run-expression node)

test-unary:
  node := parse "-1;" []
  expect-equals -1 (run-expression node)

  node = parse "-1.0;" []
  expect-equals -1.0 (run-expression node)

  node = parse "~1;" []
  expect-equals -2 (run-expression node)

  node = parse "!true;" []
  expect-equals false (run-expression node)

  node = parse "!false;" []
  expect-equals true (run-expression node)


test-binary:
  // Additive:
  node := parse "1 + 2;" []
  expect-equals 3 (run-expression node)

  node = parse "1 - 2;" []
  expect-equals -1 (run-expression node)

  // Multiplicative:
  node = parse "2 * 3;" []
  expect-equals 6 (run-expression node)

  node = parse "8 / 2;" []
  expect-equals 4 (run-expression node)

  node = parse "8 % 3;" []
  expect-equals 2 (run-expression node)

  // Bitwise:
  node = parse "7 & 2;" []
  expect-equals 2 (run-expression node)

  node = parse "10 | 9;" []
  expect-equals 11 (run-expression node)

  node = parse "10 ^ 9;" []
  expect-equals 3 (run-expression node)

  node = parse "~10;" []
  expect-equals -11 (run-expression node)

  node = parse "3 << 2;" []
  expect-equals 12 (run-expression node)

  node = parse "12 >> 2;" []
  expect-equals 3 (run-expression node)

  node = parse "-1 >>> 60;" []
  expect-equals 15 (run-expression node)

  // Relational:
  node = parse "1 < 2;" []
  expect-equals true (run-expression node)

  node = parse "2 < 1;" []
  expect-equals false (run-expression node)

  node = parse "1 < 1;" []
  expect-equals false (run-expression node)

  node = parse "1 <= 2;" []
  expect-equals true (run-expression node)

  node = parse "2 <= 1;" []
  expect-equals false (run-expression node)

  node = parse "1 <= 1;" []
  expect-equals true (run-expression node)

  node = parse "1 > 2;" []
  expect-equals false (run-expression node)

  node = parse "2 > 1;" []
  expect-equals true (run-expression node)

  node = parse "1 > 1;" []
  expect-equals false (run-expression node)

  node = parse "1 >= 2;" []
  expect-equals false (run-expression node)

  node = parse "2 >= 1;" []
  expect-equals true (run-expression node)

  // Equality:
  node = parse "1 == 2;" []
  expect-equals false (run-expression node)

  node = parse "2 == 1;" []
  expect-equals false (run-expression node)

  node = parse "1 == 1;" []
  expect-equals true (run-expression node)

  node = parse "1 != 2;" []
  expect-equals true (run-expression node)

  node = parse "2 != 1;" []
  expect-equals true (run-expression node)

  node = parse "1 != 1;" []
  expect-equals false (run-expression node)

  // Logical:
  node = parse "true && true;" []
  expect-equals true (run-expression node)

  node = parse "true && false;" []
  expect-equals false (run-expression node)

  node = parse "false && false;" []
  expect-equals false (run-expression node)

  node = parse "false && true;" []
  expect-equals false (run-expression node)

  node = parse "true || true;" []
  expect-equals true (run-expression node)

  node = parse "true || false;" []
  expect-equals true (run-expression node)

  node = parse "false || false;" []
  expect-equals false (run-expression node)

  node = parse "false || true;" []
  expect-equals true (run-expression node)

  // Floating point operations:
  node = parse "1.5 + 2.0;" []
  expect-equals 3.5 (run-expression node)

  node = parse "1.0 - 2.5;" []
  expect-equals -1.5 (run-expression node)

  node = parse "2.5 * 3.0;" []
  expect-equals 7.5 (run-expression node)

  node = parse "8.5 / 2.0;" []
  expect-equals 4.25 (run-expression node)

  node = parse "8.5 % 3.0;" []
  expect-equals 2.5 (run-expression node)

  node = parse "1.5 < 2.0;" []
  expect-equals true (run-expression node)

  node = parse "2.5 < 1.0;" []
  expect-equals false (run-expression node)

  // Floating point wins over integer:
  node = parse "1 + 2.0;" []
  expect-equals 3.0 (run-expression node)

  node = parse "1.0 + 2;" []
  expect-equals 3.0 (run-expression node)

  node = parse "1.0 < 2;" []
  expect-equals true (run-expression node)

  // String concatenation:
  node = parse "\"a\" + \"b\";" []
  expect-equals "ab" (run-expression node)

  node = parse "\"a\" + 1;" []
  expect-equals "a1" (run-expression node)

  node = parse "1 + \"b\";" []
  expect-equals "1b" (run-expression node)

  // Assignment.
  node = parse "let a = 2; a = 1;" []
  expect-equals 1
      run-expression node --allow-multiple-statements

test-precedence:
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
  expect-equals -2 (run-expression node)

  node = parse "1 * -2;" []
  // Not like we can detect a difference...
  expect-equals -2 (run-expression node)

  node = parse "~1 * 2;" []
  expect-equals -4 (run-expression node)

  node = parse "3 * ~2;" []
  expect-equals -9 (run-expression node)

  node = parse "1 * 2 + 3;" []
  expect-equals 5 (run-expression node)

  node = parse "1 + 2 * 3;" []
  expect-equals 7 (run-expression node)

  node = parse "1 << 2 + 3;" []
  expect-equals 32 (run-expression node)

  node = parse "1 + 2 << 3;" []
  expect-equals 24 (run-expression node)

  node = parse "1 & 2 + 3;" []
  expect-equals 1 (run-expression node)

  node = parse "1 + 2 & 3;" []
  expect-equals 3 (run-expression node)

  node = parse "1 ^ 2 + 3;" []
  expect-equals 4 (run-expression node)

  node = parse "1 & 3 ^ 3;" []
  expect-equals 2 (run-expression node)

  node = parse "1 ^ 3 & 3;" []
  expect-equals 2 (run-expression node)

  node = parse "1 | 2 ^ 3;" []
  expect-equals 1 (run-expression node)

  node = parse "1 ^ 3 | 1;" []
  expect-equals 3 (run-expression node)

  node = parse "1 < 2 | 3;" []
  expect-equals true (run-expression node)

  node = parse "1 | 3 < 2;" []
  expect-equals false (run-expression node)

  node = parse "1 == 2 | 3;" []
  expect-equals false (run-expression node)

  node = parse "1 | 3 == 2;" []
  expect-equals false (run-expression node)

  node = parse "1 == 1 && 2 == 3;" []
  expect-equals false (run-expression node)

  node = parse "1 == 1 && 2 == 2;" []
  expect-equals true (run-expression node)

  node = parse "1 == 1 || 2 == 3;" []
  expect-equals true (run-expression node)

  node = parse "1 == 2 || 2 == 3;" []
  expect-equals false (run-expression node)

  node = parse "let a = 1; a = true && 1 == 2;" []
  expect-equals false
      run-expression node --allow-multiple-statements

  node = parse "let a = 1; a = true && 1 == 1;" []
  expect-equals true
      run-expression node --allow-multiple-statements

  node = parse "let a = 1; a = true || 1 == 2;" []
  expect-equals true
      run-expression node --allow-multiple-statements

  node = parse "let a = 1; a = false || 1 == 2;" []
  expect-equals false
      run-expression node --allow-multiple-statements

run-with-log code/string -> List:
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

test-short-circuit:
  // Short-circuiting AND.
  log := run-with-log "true && identity(true);"
  expect-equals ["identity true"] log

  log = run-with-log "false && identity(true);"
  expect-equals [] log

  // Short-circuiting OR.
  log = run-with-log "true || identity(true);"
  expect-equals [] log

  log = run-with-log "false || identity(true);"
  expect-equals ["identity true"] log

test-statements:
  // Statements are evaluated in order.
  log := run-with-log """
    print("Hello");
    print("World");
  """
  expect-equals [
    "print Hello",
    "print World",
  ] log

  // Let statements.
  log = run-with-log """
    let a = 1;
    print(a);
  """
  expect-equals [
    "print 1",
  ] log

  // Let statements with expressions.
  log = run-with-log """
    let a = 1 + 2;
    print(a);
  """
  expect-equals [
    "print 3",
  ] log

  // While loops.
  log = run-with-log """
    let i = 0;
    while (i < 3) {
      print(i);
      i = i + 1;
    }
  """
  expect-equals [
    "print 0",
    "print 1",
    "print 2",
  ] log

  // Empty while.
  log = run-with-log """
    while (false) {
      print("This should never print");
    }
  """
  expect-equals [] log

  // While with statement not block.
  log = run-with-log """
    let list = list_create();
    while (list_size(list) < 3) list_add(list, 1);
    print(list_size(list));
  """
  expect-equals [
    "print 3",
  ] log

  // Continue.
  log = run-with-log """
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
  expect-equals [
    "print 0",
    "print 2",
  ] log

  // Nested continue.
  log = run-with-log """
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
  expect-equals [
    "print i0",
    "print j0",
    "print j2",
    "print i2",
    "print j0",
    "print j2",
  ] log

  // Break.
  log = run-with-log """
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
  expect-equals [
    "print 0",
    "print 1",
  ] log

  // Nested break.
  log = run-with-log """
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
  expect-equals [
    "print i0",
    "print j0",
    "print i1",
    "print j0",
    "print j1",
  ] log

  // If statements.
  log = run-with-log """
    if (true) {
      print("This should print");
    }
  """
  expect-equals ["print This should print"] log

  log = run-with-log """
    if (false) {
      print("This should never print");
    }
  """
  expect-equals [] log

  // If with statement not block.
  log = run-with-log """
    if (true) print("This should print");
  """
  expect-equals ["print This should print"] log

  // If-else statements.
  log = run-with-log """
    if (true) {
      print("This should print");
    } else {
      print("This should never print");
    }
  """
  expect-equals ["print This should print"] log

  log = run-with-log """
    if (false) {
      print("This should never print");
    } else {
      print("This should print");
    }
  """
  expect-equals ["print This should print"] log

  // If-else with statement not block.
  log = run-with-log """
    if (true) print("This should print");
    else print("This should never print");
  """
  expect-equals ["print This should print"] log

  log = run-with-log """
    if (false) print("This should never print");
    else print("This should print");
  """
  expect-equals ["print This should print"] log

  // Test nops.
  log = run-with-log ";"
  expect-equals [] log

  log = run-with-log """
    if (true);
  """
  expect-equals [] log

  log = run-with-log """
    if (false); else print("This should print");
  """
  expect-equals ["print This should print"] log

  log = run-with-log """
    if (true) {
    }
  """
  expect-equals [] log

test-builtins:
  // No real way to test 'print'.

  // Sleep.
  // We run some simple code 10 times and measure how long it takes.
  // Then we sleep twice that amount and check that the time elapsed.
  program := parse "1+1;" []
  duration := Duration.of:
    10.repeat:
      program.eval
  sleep-duration := duration * 2
  in-ms := sleep-duration.in-ms
  if in-ms == 0: in-ms = 1
  program = parse "sleep($in-ms);" []
  measured := Duration.of:
    program.eval
  expect measured > sleep-duration

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

  result := run-expression program --allow-multiple-statements
  expect-equals [3, 2, 1, 1, 4, 3] result

/**
Test OpenAI programs.

These aren't really pinnacles of programming, but that's what our
  interpreter has to deal with.
*/
test-openai-programs:
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
  expect-equals
      expected
      run-with-log PROGRAM

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
  expect-equals
      expected
      run-with-log PROGRAM2

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
  expect-equals
      expected
      run-with-log PROGRAM3

test-instruction-example:
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
  expect-equals
      expected
      run-with-log EXAMPLE
