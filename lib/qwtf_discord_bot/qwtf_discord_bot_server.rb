class QwtfDiscordBotServer < QwtfDiscordBot
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: TOKEN,
      client_id: CLIENT_ID,
      prefix: '!'
    )

    bot.command :server do |event|
      qstat_request = QstatRequest.new(endpoint)
      message = qstat_request.server_summary
      embed = qstat_request.to_embed

      if embed
        event.channel.send_embed(message, embed)
      else
        event.channel.send_message(message)
      end
    end

    bot.run
  end
end
