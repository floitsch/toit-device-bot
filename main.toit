// Copyright (C) 2023 Florian Loitsch. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import discord
import host.os
import monitor
import .src.device_bot

main:
  openai_key := os.env.get "OPENAI_KEY"
  discord_token := os.env.get "DISCORD_TOKEN"
  discord_url := os.env.get "DISCORD_URL"

  if not openai_key:
    print "Please set the OPENAI_KEY environment variable."
    exit 1

  if not discord_token:
    print "Please set the DISCORD_TOKEN environment variable."
    exit 1

  if not discord_url:
    print "Please set the DISCORD_URL environment variable."
    exit 1

  main
      --openai_key=openai_key
      --discord_token=discord_token
      --discord_url=discord_url

main --openai_key/string --discord_token/string --discord_url/string:
  if discord_url != "":
    print "To invite and authorize the bot to a channel go to $discord_url"

  discord_client := discord.Client --token=discord_token
  discord_client.connect
  discord_mutex := monitor.Mutex

  channel_id := ""

  device_bot/DeviceBot? := null

  // Don't start the but until we are connected to Discord.
  // The initial ready-message is quite heavy, so we prefer not to
  // have the DeviceBot running at the same time.
  start_rest := ::
    device_bot = DeviceBot --openai_key=openai_key [
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

  print "Now listening for messages"
  intents := 0
    | discord.INTENT_GUILD_MEMBERS
    | discord.INTENT_GUILD_MESSAGES
    | discord.INTENT_DIRECT_MESSAGES
    | discord.INTENT_GUILD_MESSAGE_CONTENT

  my_id/string? := null

  task::
    discord_client.listen --intents=intents: | event/discord.Event? |
      print "Got notification $event"
      if event is discord.EventReady:
        my_id = (event as discord.EventReady).user.id
        print "My id is $my_id"
        event = null  // Allow the event to be garbage collected.
        start_rest.call

      if event is discord.EventMessageCreate:
        message := (event as discord.EventMessageCreate).message
        if message.author.id == my_id: continue.listen

        print "Message: $message.content"

        channel_id = message.channel_id
        content := message.content
        device_bot.handle_message content --when_started=:: | response/string |
          discord_mutex.do:
            discord_client.send_message --channel_id=channel_id response
