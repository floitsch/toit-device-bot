// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import openai
import .interpreter
export Function

LANGUAGE_DESCRIPTION ::= """
  Given a simplified C-like programming language with the following builtin functions:
  $builtins_description

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
    // Establish a connection in the beginning when the memory isn't fragmented.
    // We are likely losing the connection again, but maybe it helps sometimes.
    openai_client_.models.list

  close:
    if openai_client_:
      openai_client_.close
      openai_client_ = null
    if executing_task_:
      executing_task_.cancel
      executing_task_ = null

  handle_message message/string --when_started/Lambda:
    if executing_task_:
      executing_task_.cancel
      executing_task_ = null
    executing_task_ = task::
      conversation/List? := [
        openai.ChatMessage.system
            "You are terse bot that writes simple programs in a simplified C-like programming language.",
        openai.ChatMessage.user LANGUAGE_DESCRIPTION,
        openai.ChatMessage.user function_description_message_,
        openai.ChatMessage.user "$REQUEST_MESSAGE$message",
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
              openai.ChatMessage.user """
                I got the following error: $exception.
                Remember: no self-defined functions! No objects! This is an extremely simple language.
                Fix the program.
                Only respond with the program!
                Don't add any apology, instructions or explanations!"""
