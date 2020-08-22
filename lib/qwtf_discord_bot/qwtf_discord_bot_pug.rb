require "redis"

class QwtfDiscordBotPug
  FOUR_HOURS = 4 * 60 * 60
  DEFAULT_MAXPLAYERS = 8

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      pug = pug_key(event)

      redis.setnx(pug, Time.now)
      redis.expire(pug, FOUR_HOURS)

      user = event.user
      redis.sadd(players_key(event), user.id)

      redis.setnx(maxplayers_key(event), DEFAULT_MAXPLAYERS)

      username = user.username

      message = case number_in_lobby(event)
                when 1
                  [
                    "#{username} creates a PUG",
                    "#{number_in_lobby(event)}/#{maxplayers(event)}",
                    "`!join` to join"
                  ].join(" | ")
                when maxplayers(event)
                  "Time to play!"
                else
                  [
                    "#{username} joins the PUG",
                    "#{number_in_lobby(event)}/#{maxplayers(event)}"
                  ].join(" | ")
                end

      send_and_log_message(message, event)
    end

    bot.command :status do |event, *args|
      pug = pug_key(event)

      redis.setnx(maxplayers_key(event), DEFAULT_MAXPLAYERS)

      users = redis.smembers(players_key(event)).map do |user_id|
        event.channel.users.find { |user| user.id.to_s == user_id }
      end

      usernames = users.map do |user|
        user.username
      end

      message = "Players: #{usernames.join(", ")} | #{number_in_lobby(event)}/#{maxplayers(event)}"

      send_and_log_message(message, event)
    end

    bot.command :maxplayers do |event, *args|
      pug = pug_key(event)
      redis.setnx(maxplayers_key(event), DEFAULT_MAXPLAYERS)

      new_maxplayers = args[0]

      if new_maxplayers
        redis.set(maxplayers_key(event), new_maxplayers)
        message = "Max number of players set to #{maxplayers(event)} | #{number_in_lobby(event)}/#{maxplayers(event)}"
      else
        message = "Current max number of players is #{maxplayers(event)} | #{number_in_lobby(event)}/#{maxplayers(event)}"
      end

      send_and_log_message(message, event)
    end

    bot.command :leave do |event, *args|
      pug = pug_key(event)

      user = event.user
      user_id = user.id

      redis.srem(players_key(event), user_id)

      message = "#{user.username} leaves the PUG | #{number_in_lobby(event)}/#{maxplayers(event)}"
      send_and_log_message(message, event)
    end

    bot.command :end do |event, *args|
      pug = pug_key(event)

      redis.del(pug)
      redis.del(players_key(event))

      message = "PUG ended"
      send_and_log_message(message, event)
    end

    bot.run
  end

  private

  def maxplayers_key(event)
    [pug_key(event), "maxplayers"].join(":")
  end

  def maxplayers(event)
    redis.get(maxplayers_key(event))
  end

  def number_in_lobby(event)
    redis.scard(players_key(event))
  end

  def pug_key(event)
    ["pug", event.channel.id].join(":")
  end

  def players_key(event)
    [pug_key(event), "players"].join(":")
  end

  def send_and_log_message(message, event)
    event.channel.send_message(message)
    puts message
  end

  def redis
    @redis ||= Redis.new
  end
end
