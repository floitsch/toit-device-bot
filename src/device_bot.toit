// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import log
import openai
import .interpreter
export Function

SYSTEM_MESSAGE ::=
    "You are terse bot that writes simple programs in a simplified C-like programming language."

// We hardcode the builtins here, so that the string can be stored in flash.
// We also shorten the description, a bit.
LANGUAGE_DESCRIPTION ::= """
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

REQUEST_MESSAGE ::= """
  Write a program that implements the functionality below (after '===').
  Only respond with the program. Don't add any instructions or explanations.
  ====
  """

class DeviceBot:
  openai_client_/openai.Client? := ?
  function_description_message_/string ::= ?
  functions_/List
  logger_/log.Logger

  executing_task_/Task? := null

  constructor --openai_key/string functions/List --logger/log.Logger=log.default:
    logger_ = logger.with_name "DeviceBot"
    functions_ = functions
    builtins := {}
    BUILTINS.do: | builtin/Function |
      builtins.add builtin.name
    has_user_function := false
    function_description_message_ = ""
    functions.do: | function/Function |
      if not builtins.contains function.name:
        if not has_user_function:
          function_description_message_ += "The language furthermore has the following functions:\n"
          has_user_function = true
        function_description_message_ += "- '$function.syntax': $function.description\n"
    if has_user_function:
      function_description_message_ += "Under no circumstances use any function that is not on the builtin list or this list!"
    else:
      function_description_message_ += "Under no circumstances use any function that is not on the builtin list!"

    openai_client_ = openai.Client --key=openai_key

  close:
    if openai_client_:
      openai_client_.close
      openai_client_ = null
    if executing_task_:
      executing_task_.cancel
      executing_task_ = null

  handle_message message/string? --when_started/Lambda:
    if executing_task_:
      executing_task_.cancel
      executing_task_ = null
    request_message := "$REQUEST_MESSAGE$message"
    message = null  // Allow to GC.
    executing_task_ = task::
      conversation/List? := [
        openai.ChatMessage.system SYSTEM_MESSAGE,
        openai.ChatMessage.user LANGUAGE_DESCRIPTION,
        openai.ChatMessage.user function_description_message_,
        openai.ChatMessage.user request_message,
      ]

      // Give OpenAI 3 attempts at correcting the program.
      for i := 0; i < 3; i++:
        logger_.debug "requesting completion from OpenAI" --tags={
          "conversation": conversation,
        }
        response/string? := openai_client_.complete_chat --conversation=conversation --max_tokens=500
        logger_.debug "got response" --tags={ "data": response }
        if response.ends_with "```" or response.ends_with "```\n":
          // Grrr. Bot added a code block. Potentially even adding some noise.
          start_pos := response.index_of "```"
          end_pos := response.index_of --last "```"
          response = response[start_pos + 3 .. end_pos]
        exception := catch --trace:
          program := parse response functions_
          response = null
          conversation = null
          when_started.call
          program.eval
        if exception and not conversation:
          logger_.info "running the program failed" --tags={ "error": exception }
        if not exception or not conversation: break
        if conversation:
          conversation.add
              openai.ChatMessage.assistant response
          conversation.add
              openai.ChatMessage.user "I got the following error: $exception."
          conversation.add
              openai.ChatMessage.user """
                Remember: no self-defined functions! No objects! This is an extremely simple language.
                Fix the program.
                Only respond with the program!
                Don't add any apology, instructions or explanations!"""
