# Device Bot

A bot that runs on a device and interprets commands using OpenAI.

The bot comes with a small interpreter for a tiny C-like language.
When the user sends a request to the device (typically through a chat
application), the device sends the request to the OpenAI API, instructing
it to generate a program that works on the language interpreter.

Developers can provide their own functions with descriptions which
are also sent to the OpenAI API. For example, a device with a
temperature sensor and a light sensor could provide the functions
`get_temperature` and `set_light`.

## Example

The following example shows how to use the device bot to control a light depending
on the temperature.

Warning: running this program will fill up your terminal with output (due to the
`print` statements).
```
import device_bot show *
import host.os  // Only needed for `os.env`.

main:
  openai_key := os.env.get "OPENAI_KEY"

  if not openai_key:
    print "Please set the OPENAI_KEY environment variable."
    exit 1

  main
      --openai_key=openai_key

main --openai_key/string:
  device_bot := DeviceBot --openai_key=openai_key [
    Function
        --syntax="get_temperature()"
        --description="Gets the current temperature in Celsius. Returns a float."
        --action=:: | args/List |
          print "getting temperature"
          (random 0 30).to_float,
    Function
        --syntax="set_light(<on_off>)"
        --description="Turns the light on or off, depending on the boolean parameter"
        --action=:: | args/List |
          message := args[0]
          print "setting light to $message"
  ]

  // The request here typically comes from a chat application.
  device_bot.handle_message --when_started=(:: print "Running the program") """
    Wait 2 seconds, then turn the light off.
    Then continuously measure the temperature and turn the light on if the temperature is above 20 degrees Celsius.
    """
```

## Features and bugs
Please file feature requests and bugs at the [issue tracker](https://github.com/floitsch/toit-device-bot/issues).
