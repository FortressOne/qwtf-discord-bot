require "redis"

class QwtfDiscordBotPug
  FOUR_HOURS = 4 * 60 * 60
  DEFAULT_NUMBER_OF_PLAYERS = 8

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

      nop_key = [pug_key, "number_of_players"].join(":")
      redis.setnx(nop_key, DEFAULT_NUMBER_OF_PLAYERS)
      number_of_players = redis.get(nop_key)

      username = user.username

      message = case number_in_lobby
                when 1 then "#{username} starts a PUG for #{number_of_players} players. `!join` to join."
                when number_of_players then "Time to play!"
                else "#{username} joins the PUG. #{number_in_lobby}/#{number_of_players} joined."
                end

      channel.send_message(message)
      puts message
    end

    bot.command :players do |event, *args|
      channel = event.channel
      channel_id = channel.id
      number_of_players = args[0]
      nop_key = ["pug", channel_id, "number_of_players"].join(":")
      redis.set(nop_key, number_of_players)
      message = "Number of players set to #{number_of_players}"
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
      nop_key = [pug_key, "number_of_players"].join(":")
      number_of_players = redis.get(nop_key)

      message = "#{user.username} leaves the PUG. #{number_in_lobby}/#{number_of_players} remain."
      channel.send_message(message)
      puts message
    end

    bot.command :end do |event, *args|
      channel = event.channel
      pug = ["pug", channel.id].join(":")

      redis.del(pug)

      message = "PUG ended."
      channel.send_message(message)
      puts message
    end

    # bot.command :status do |event, *args|
    #   channel = event.channel
    #   pug = ["pug", channel.id].join(":")

    #   number_in_lobby = redis.keys("pug:#{channel_id}:player:*").count
    #   nop_key = [pug, "number_of_players"].join(":")
    #   number_of_players = redis.get(nop_key) || 8

    #   message = "."
    #   channel.send_message(message)
    #   puts message
    # end

    bot.run
  end

  private

  def redis
    @redis ||= Redis.new
  end
end
