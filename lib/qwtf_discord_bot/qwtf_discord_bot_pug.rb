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
      channel = event.channel
      channel_id = channel.id
      pug_key = ["pug", channel_id].join(":")

      redis.setnx(pug_key, Time.now)
      redis.expire(pug_key, FOUR_HOURS)

      players_key = [pug_key, "players"].join(":")
      user = event.user
      redis.sadd(players_key, user.id)

      number_in_lobby = redis.scard(players_key)

      maxplayers_key = [pug_key, "maxplayers"].join(":")
      redis.setnx(maxplayers_key, DEFAULT_MAXPLAYERS)
      maxplayers = redis.get(maxplayers_key)

      username = user.username

      message = case number_in_lobby
                when 1 then "#{username} starts a PUG for #{maxplayers} players, `!join` to join"
                when maxplayers then "Time to play!"
                else "#{username} joins the PUG | #{number_in_lobby}/#{maxplayers}"
                end

      channel.send_message(message)
      puts message
    end

    bot.command :status do |event, *args|
      channel = event.channel
      channel_id = channel.id
      pug_key = ["pug", channel_id].join(":")
      players_key = [pug_key, "players"].join(":")

      number_in_lobby = redis.scard(players_key)
      maxplayers_key = [pug_key, "maxplayers"].join(":")
      redis.setnx(maxplayers_key, DEFAULT_MAXPLAYERS)
      maxplayers = redis.get(maxplayers_key)

      users = redis.smembers(players_key).map do |user_id|
        channel.users.find { |user| user.id.to_s == user_id }
      end

      usernames = users.map do |user|
        user.username
      end

      number_in_lobby = redis.scard(players_key)

      message = "Players: #{usernames.join(",")} | #{number_in_lobby}/#{maxplayers}"

      channel.send_message(message)
      puts message
    end

    bot.command :maxplayers do |event, *args|
      channel = event.channel
      channel_id = channel.id
      pug_key = ["pug", channel_id].join(":")
      maxplayers_key = [pug_key, "maxplayers"].join(":")
      redis.setnx(maxplayers_key, DEFAULT_MAXPLAYERS)

      players_key = [pug_key, "players"].join(":")
      number_in_lobby = redis.scard(players_key)

      maxplayers = args[0]

      if maxplayers
        redis.set(maxplayers_key, maxplayers)
        message = "Max number of players set to #{maxplayers} | #{number_in_lobby}/#{maxplayers}"
      else
        maxplayers = redis.get(maxplayers_key)
        message = "Current max number of players is #{maxplayers} | #{number_in_lobby}/#{maxplayers}"
      end

      channel.send_message(message)
      puts message
    end

    bot.command :leave do |event, *args|
      channel = event.channel
      channel_id = channel.id

      pug_key = ["pug", channel_id].join(":")

      user = event.user
      user_id = user.id

      players_key = [pug_key, "players"].join(":")

      redis.srem(players_key, user_id)

      number_in_lobby = redis.scard(players_key)
      maxplayers_key = [pug_key, "maxplayers"].join(":")
      maxplayers = redis.get(maxplayers_key)

      message = "#{user.username} leaves the PUG | #{number_in_lobby}/#{maxplayers}"
      channel.send_message(message)
      puts message
    end

    bot.command :end do |event, *args|
      channel = event.channel
      pug_key = ["pug", channel.id].join(":")
      players_key = [pug_key, "players"].join(":")

      redis.del(pug_key)
      redis.del(players_key)

      message = "PUG ended"
      channel.send_message(message)
      puts message
    end

    bot.run
  end

  private

  def redis
    @redis ||= Redis.new
  end
end
