class QwtfDiscordBotServer
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :help do |event, *args|
      "Server commands: `!active`, `!all`, `!server <address>`"
    end

    bot.command :server do |event, *args|
      if args.empty?
        message = 'Provide a server address e.g. `!server ' \
          'sydney.fortressone.org` or use `!active` or `!all`'
        event.channel.send_message(message)

        return puts message
      end

      endpoint = args.first
      request = QstatRequest.new(endpoint)

      if !request.live_server?
        event.channel.send_message("#{endpoint} isn't responding")
      else
        event.channel.send_embed(nil, request.to_full_embed)
      end
    end

    bot.command :all do |event|
      endpoints_for_this_channel = QwtfDiscordBot.config.endpoints.select do |endpoint|
        endpoint.channel_ids.any? do |channel_id|
          event.channel.id == channel_id
        end
      end

      if endpoints_for_this_channel.empty?
        message = 'There are no servers associated with this channel'
        event.channel.send_message(message)
        return puts message
      end

      endpoints_for_this_channel.each do |endpoint|
        request = QstatRequest.new(endpoint.address)

        if !request.live_server?
          event.channel.send_message("#{endpoint} isn't responding")
        else
          event.channel.send_embed(nil, request.to_full_embed)
        end
      end

      return nil
    end

    bot.command :active do |event|
      endpoints_for_this_channel = QwtfDiscordBot.config.endpoints.select do |endpoint|
        endpoint.channel_ids.any? do |channel_id|
          event.channel.id == channel_id
        end
      end

      if endpoints_for_this_channel.empty?
        message = 'There are no servers associated with this channel'
        event.channel.send_message(message)
        return puts message
      end

      qstat_requests = endpoints_for_this_channel.map do |endpoint|
        QstatRequest.new(endpoint.address)
      end

      servers_with_players = qstat_requests.reject do |server|
        server.is_empty?
      end

      if servers_with_players.empty?
        message = "All ##{event.channel.name} servers are empty"
        event.channel.send_message(message)
        return puts message
      end

      servers_with_players.each do |server|
        event.channel.send_embed(nil, server.to_full_embed)
      end

      return nil
    end

    bot.run
  end
end
