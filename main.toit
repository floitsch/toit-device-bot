// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import discord
import monitor
import .src.device_bot

OPENAI_KEY ::=

DISCORD_TOKEN ::=
DISCORD_URL ::=

main:
  if DISCORD_URL != "":
    print "To invite the bot to a channel go to $DISCORD_URL"

  discord_client := discord.Client --token=DISCORD_TOKEN
  discord_client.connect
  discord_mutex := monitor.Mutex

  channel_id := ""

  device_bot := DeviceBot --openai_key=OPENAI_KEY [
    Function
        --syntax="get_temperature()"
        --description="Gets the current temperature in Celsius. Returns a float. Avoid measuring more often than every 100ms."
        --action=:: | args/List |
          print "getting temperature"
          (random 0 30).to_float,
    Function
        --syntax="print(<message>)"
        --description="Print a message"
        --action=:: | args/List |
          message := args[0]
          discord_mutex.do:
            discord_client.send_message --channel_id=channel_id "$message"
  ]

  me := discord_client.me
  my_id := me.id
  print "My id is $my_id"

  print "Now listening for messages"
  intents := 0
    | discord.INTENT_GUILD_MEMBERS
    | discord.INTENT_GUILD_MESSAGES
    | discord.INTENT_DIRECT_MESSAGES
    | discord.INTENT_GUILD_MESSAGE_CONTENT

  task::
    discord_client.listen --intents=intents: | event/discord.Event? |
      print "Got notification $event"
      if event is discord.EventMessageCreate:
        message := (event as discord.EventMessageCreate).message
        if message.author.id == my_id: continue.listen

        print "Message: $message.content"

        channel_id = message.channel_id
        content := message.content
        device_bot.handle_message content --when_started=:: | response/string |
          discord_mutex.do:
            discord_client.send_message --channel_id=channel_id response
