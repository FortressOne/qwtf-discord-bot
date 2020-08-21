require "redis"

class QwtfDiscordBotPug
  FOUR_HOURS = 4 * 60 * 60

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      channel_id = event.channel.id
      user = event.user
      pug = ["pug", channel_id].join(":")
      player = [pug, "player", user.id].join(":")

      redis.set(pug, Time.now)
      redis.expire(pug, FOUR_HOURS)
      redis.set(player, Time.now)

      number_in_lobby = redis.keys("pug:#{channel_id}:player:*").count
      username = user.username

      message = case number_in_lobby
                when 1 then "#{username} starts a PUG. `!join` to join."
                when 8 then "Start the pug!"
                else "#{username} joins the PUG. (#{number_in_lobby}/8)"
                end
      end

      event.channel.send_message(message)
      puts message
    end

    bot.command :end do |event, *args|
      pug = ["pug", event.channel.id].join(":")

      event.channel.send_message(message)
      puts message
    end

    bot.run
  end

  private

  def redis
    @redis ||= Redis.new
  end
end
