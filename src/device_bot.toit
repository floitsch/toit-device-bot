// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import openai
import .interpreter
export Function

SYSTEM_MESSAGE ::=
    "You are terse bot that writes simple programs in a simplified C-like programming language."

// We hardcode the builtins here, so that the string can be stored in flash.
// Use $builtins_description to generate the text when the builtins change.
LANGUAGE_DESCRIPTION ::= """
  Given a simplified C-like programming language with the following builtin functions:
  - print(<message>): Prints a message.
  - sleep(<ms>): Sleeps for a given amount of milliseconds.
  - random(<min>, <max>): Returns a random integer between min and max.
  - list_create(): Creates a new list.
  - list_add(<list>, <value>): Adds a value to a list.
  - list_get(<list>, <index>): Gets a value from a list.
  - list_set(<list>, <index>, <value>): Sets a value in a list.
  - list_size(<list>): Returns the size of a list.

  Examples:
  ```
  // Print a message, then sleep for 1000ms, then print another message.
  print("Hello world!");
  sleep(1000);
  print("Goodbye world!");
  ```

  ```
  // Print a message 10 times.
  let i = 0;
  while (i < 10) {
    print("Hello world!");
    i = i + 1;
  }
  ```

  ```
  // Add 10 numbers to a list and print it.
  let list = list_create();
  let i = 0;
  while (i < 10) {
    list_add(list, i);
    i = i + 1;
  }
  print(list);
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

  executing_task_/Task? := null

  constructor --openai_key/string functions/List:
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
        print "Requesting completion from OpenAI"
        print "Conversation: $conversation"
        response/string? := openai_client_.complete_chat --conversation=conversation --max_tokens=500
        print "Got response:\n$response"
        if response.ends_with "```" or response.ends_with "```\n":
          // Grrr. Bot added a code block. Potentially even adding some noise.
          start_pos := response.index_of "```"
          end_pos := response.index_of --last "```"
          response = response[start_pos + 3 .. end_pos]
        exception := catch --trace:
          program := parse response functions_
          response = null
          conversation = null
          when_started.call "Running the program"
          program.eval
        if exception and not conversation:
          print "Running the program failed with the following error: $exception"
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
