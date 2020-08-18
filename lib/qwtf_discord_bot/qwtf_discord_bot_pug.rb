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
      pug = ["pug", event.channel].join(":")

      message = if redis.get(pug)
        "#{event.user.username} joins the PUG."
      else
        redis.set(pug, Time.now)
        redis.expire(pug, FOUR_HOURS)
        "#{event.user.username} starts a PUG. `!join` to join."
      end

      player = [pug, event.user.id].join(":")
      redis.set(player, Time.now)

      # start_pug if pug_full?

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
