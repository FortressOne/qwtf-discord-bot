class QwtfDiscordBotServer < QwtfDiscordBot
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: TOKEN,
      client_id: CLIENT_ID,
      prefix: '!'
    )

    bot.command :server do |event|
      embed = QstatRequest.new(endpoint).to_embed

      Discordrb::API::Channel.create_message(
        "Bot #{TOKEN}",
        CHANNEL_ID,
        nil,
        [], # This argument will be removed in next version of discordrb gem
        false,
        embed.to_hash
      )

      nil
    end

    bot.run
  end
end
