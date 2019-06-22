class QwtfDiscordBotServer < QwtfDiscordBot # :nodoc:
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: @token,
      client_id: @client_id,
      prefix: '!'
    )

    bot.command :server do |event, *args|
      if args.empty?
        event.channel.send_message(
          'Provide a server address e.g. `!server sydney.fortressone.org` ' \
          'or use `!active` or `!all`'
        )
      else
        endpoint = args.first
        qstat_response = QstatRequest.new(endpoint)
        message = qstat_response.server_summary
        embed = qstat_response.to_embed

        if embed
          event.channel.send_embed(message, embed)
        else
          event.channel.send_message(message)
        end
      end
    end

    bot.command :all do |event|
      @endpoints.each do |endpoint|
        endpoint.channel_ids.each do |channel_id|
          next unless event.channel.id == channel_id

          qstat_request = QstatRequest.new(endpoint.address)
          message = qstat_request.server_summary
          embed = qstat_request.to_embed


          if embed
            event.channel.send_embed(message, embed)
          else
            event.channel.send_message(message)
          end
        end
      end

      return nil
    end

    bot.command :active do |event|
      endpoints_for_this_channel = @endpoints.select do |endpoint|
        endpoint.channel_ids.any? do |channel_id|
          event.channel.id == channel_id
        end
      end

      qstat_requests = endpoints_for_this_channel.map do |endpoint|
        QstatRequest.new(endpoint.address)
      end

      servers_with_players = qstat_requests.reject do |server|
        server.is_empty?
      end

      if servers_with_players.empty?
        event.channel.send_message("All #{event.channel.name} servers are empty")
      else
        servers_with_players.each do |server|
          message = server.server_summary
          embed = server.to_embed

          if embed
            event.channel.send_embed(message, embed)
          else
            event.channel.send_message(message)
          end
        end
      end

      return nil
    end

    bot.run
  end
end
