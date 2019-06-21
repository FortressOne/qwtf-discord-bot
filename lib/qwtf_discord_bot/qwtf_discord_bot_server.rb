class QwtfDiscordBotServer < QwtfDiscordBot # :nodoc:
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: TOKEN,
      client_id: CLIENT_ID,
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
      @endpoints.each do |endpoint, channel_ids|
        channel_ids.each do |channel_id|
          next if event.channel.id != channel_id

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

      return nil
    end

    bot.command :active do |event|
      @endpoints.each do |endpoint, channel_ids|
        channel_ids.each do |channel_id|
          next if event.channel.id != channel_id

          qstat_request = QstatRequest.new(endpoint)
          next if qstat_request.is_empty?

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

    bot.run
  end
end
