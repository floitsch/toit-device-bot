// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import device-bot show *
import host.os // Only needed for `os.env.

main:
  openai-key := os.env.get "OPENAI_KEY"

  if not openai-key:
    print "Please set the OPENAI_KEY environment variable."
    exit 1

  main
      --openai-key=openai-key

main --openai-key/string:
  device-bot := DeviceBot --openai-key=openai-key [
    Function
        --syntax="get_temperature()"
        --description="Gets the current temperature in Celsius. Returns a float."
        --action=:: | args/List |
          print "getting temperature"
          (random 0 30).to-float,
    Function
        --syntax="set_light(<on_off>)"
        --description="Turns the light on or off, depending on the boolean parameter"
        --action=:: | args/List |
          message := args[0]
          print "setting light to $message"
  ]

  // The request here typically comes from a chat application.
  device-bot.handle-message --when-started=(:: print "Running the program") """
    Wait 2 seconds, then turn the light off.
    Then continuously measure the temperature and turn the light on if the temperature is above 20 degrees Celsius.
    """
