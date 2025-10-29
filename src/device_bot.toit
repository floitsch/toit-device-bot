// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import log
import openai
import .interpreter
export Function

SYSTEM-MESSAGE ::=
    "You are terse bot that writes simple programs in a simplified C-like programming language."

// We hardcode the builtins here, so that the string can be stored in flash.
// We also shorten the description, a bit.
LANGUAGE-DESCRIPTION ::= """
  Given a simplified C-like programming language with the following builtin functions:
  - print(<message>).
  - sleep(<ms>).
  - to_int(<number or string>). Converts the given number or string to an integer.
  - random(<min>, <max>).
  - now(): Returns the ms since the epoch.
  - List functions: 'list_create()', 'list_add(<list>, <value>)', 'list_get', 'list_set', 'list_size'.
  - Map function: 'map_create()', 'map_set(<map>, <key>, <value>)', 'map_get', 'map_contains', 'map_keys', 'map_values', 'map_size'.
    'map_get' throws an error if the key is not in the map.
    Keys can be integers or strings.

  Example:
  ```
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
  print(list_get(keys, to_int(list_size(keys) / 2)));
  // Print the average of the squares.
  print(sum / list_size(keys));
  ```

  This language is *not* Javascript. It has no objects (not even 'Math') or self-defined functions. No 'const'."""

REQUEST-MESSAGE ::= """
  Write a program that implements the functionality below (after '===').
  Only respond with the program. Don't add any instructions or explanations.
  ====
  """

class DeviceBot:
  openai-client_/openai.Client? := ?
  function-description-message_/string ::= ?
  functions_/List
  logger_/log.Logger

  executing-task_/Task? := null

  constructor --openai-key/string functions/List --logger/log.Logger=log.default:
    logger_ = logger.with-name "DeviceBot"
    functions_ = functions
    builtins := {}
    BUILTINS.do: | builtin/Function |
      builtins.add builtin.name
    has-user-function := false
    function-description-message_ = ""
    functions.do: | function/Function |
      if not builtins.contains function.name:
        if not has-user-function:
          function-description-message_ += "The language furthermore has the following functions:\n"
          has-user-function = true
        function-description-message_ += "- '$function.syntax': $function.description\n"
    if has-user-function:
      function-description-message_ += "Under no circumstances use any function that is not on the builtin list or this list!"
    else:
      function-description-message_ += "Under no circumstances use any function that is not on the builtin list!"

    openai-client_ = openai.Client --key=openai-key

  close:
    if openai-client_:
      openai-client_.close
      openai-client_ = null
    if executing-task_:
      executing-task_.cancel
      executing-task_ = null

  handle-message message/string? --when-started/Lambda --on-error/Lambda?=null:
    if executing-task_:
      executing-task_.cancel
      executing-task_ = null
    request-message := "$REQUEST-MESSAGE$message"
    message = null  // Allow to GC.
    executing-task_ = task::
      conversation/List? := [
        openai.ChatMessage.system SYSTEM-MESSAGE,
        openai.ChatMessage.user LANGUAGE-DESCRIPTION,
        openai.ChatMessage.user function-description-message_,
        openai.ChatMessage.user request-message,
      ]

      // Give OpenAI 3 attempts to get something parseable.
      succeeded := false
      for i := 0; i < 3; i++:
        logger_.debug "requesting completion from OpenAI" --tags={
          "conversation": conversation,
        }
        response/string? := openai-client_.complete-chat --conversation=conversation --max-tokens=500
        logger_.debug "got response" --tags={ "data": response }
        if response.ends-with "```" or response.ends-with "```\n":
          // Grrr. Bot added a code block. Potentially even adding some noise.
          start-pos := response.index-of "```"
          end-pos := response.index-of --last "```"
          response = response[start-pos + 3 .. end-pos]
        exception := catch --trace:
          program := parse response functions_
          response = null
          conversation = null
          when-started.call
          program.eval
          succeeded = true
        if exception and not conversation:
          logger_.info "running the program failed" --tags={ "error": exception }
        if not exception or not conversation: break

      if not succeeded and on-error: on-error.call
