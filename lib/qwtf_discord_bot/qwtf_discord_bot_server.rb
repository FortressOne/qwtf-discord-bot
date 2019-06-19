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
          "Provide a server address e.g. `!server location.fortressone.org` or use `!servers`"
        )
      else
        endpoint = args.first
        qstat_request = QstatRequest.new(endpoint)
        message = qstat_request.server_summary
        embed = qstat_request.to_embed

        if embed
          event.channel.send_embed(message, embed)
        else
          event.channel.send_message(message)
        end
      end
    end

    bot.command :servers do |event|
      return unless event.channel.id.to_s == CHANNEL_ID

      qstat_requests = @endpoints.map do |endpoint|
        QstatRequest.new(endpoint)
      end

      message = qstat_requests.map(&:server_summary).join("\n")
      event.channel.send_message(message)
    end

    bot.command :active do |event|
      return unless event.channel.id.to_s == CHANNEL_ID

      qstat_requests = @endpoints.map do |endpoint|
        QstatRequest.new(endpoint)
      end

      servers_with_players = qstat_requests.select(&:has_players?)

      message = begin
                  if servers_with_players.empty?
                    "All ##{event.channel.name} servers are empty."
                  else
                    servers_with_players.map(&:server_summary).join("\n")
                  end
                end

      event.channel.send_message(message)
    end

    bot.run
  end
end
