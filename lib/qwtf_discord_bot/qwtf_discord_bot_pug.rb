class QwtfDiscordBotPug
  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      # if pug_active?
      #   join_pug
      # else
      #   create_pug
      # end

      # start_pug if pug_full?

      message = "#{event.user.username} has joined"
      event.channel.send_message(message)
      puts message
    end

    bot.run
  end
end
