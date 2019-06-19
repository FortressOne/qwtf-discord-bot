class QwtfDiscordBotServer < QwtfDiscordBot
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: TOKEN,
      client_id: CLIENT_ID,
      prefix: '!'
    )

    bot.command :server do |event, *args|
      return unless event.channel.id.to_s == CHANNEL_ID

      if args.empty?
        event.channel.send_message(
          "Provide a server address e.g. `!server sydney.fortressone.org` or use `!active` or `!all`"
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
      return unless event.channel.id.to_s == CHANNEL_ID

      qstat_responses = @endpoints.map do |endpoint|
        QstatRequest.new(endpoint)
      end

      qstat_responses.each do |server|
        message = server.server_summary
        embed = server.to_embed

        if embed
          event.channel.send_embed(message, embed)
        else
          event.channel.send_message(message)
        end
      end

      return nil
    end

    bot.command :active do |event|
      return unless event.channel.id.to_s == CHANNEL_ID

      qstat_responses = @endpoints.map do |endpoint|
        QstatRequest.new(endpoint)
      end

      servers_with_players = qstat_responses.select(&:has_players?)

      if servers_with_players.empty?
        event.channel.send_message(
          "All ##{event.channel.name} servers are empty"
        )
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
