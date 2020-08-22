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
      e = EventWrapper.new(event)

      redis.setnx(e.pug_key, Time.now)
      redis.expire(e.pug_key, FOUR_HOURS)

      redis.sadd(e.players_key, e.user_id)
      redis.setnx(e.maxplayers_key, DEFAULT_MAXPLAYERS)

      message = case e.number_in_lobby
                when 1
                  [
                    "#{e.username} creates a PUG",
                    e.player_slots,
                    "`!join` to join"
                  ].join(" | ")
                when e.maxplayers
                  "Time to play!"
                else
                  [
                    "#{e.username} joins the PUG",
                    e.player_slots,
                  ].join(" | ")
                end

      send_and_log_message(message, event)
    end

    bot.command :status do |event, *args|
      e = EventWrapper.new(event)

      redis.setnx(e.maxplayers_key, DEFAULT_MAXPLAYERS)

      users = redis.smembers(e.players_key).map do |user_id|
        e.users.find do |user|
          user.id.to_s == user_id
        end
      end

      usernames = users.map do |user|
        user.username
      end

      message = "Players: #{usernames.join(", ")} | #{e.player_slots}"

      send_and_log_message(message, event)
    end

    bot.command :maxplayers do |event, *args|
      e = EventWrapper.new(event)

      redis.setnx(e.maxplayers_key, DEFAULT_MAXPLAYERS)

      new_maxplayers = args[0]

      if new_maxplayers
        redis.set(e.maxplayers_key, new_maxplayers)
        message = "Max number of players set to #{e.maxplayers} | #{e.player_slots}"
      else
        message = "Current max number of players is #{e.maxplayers} | #{e.player_slots}"
      end

      send_and_log_message(message, event)
    end

    bot.command :leave do |event, *args|
      e = EventWrapper.new(event)

      redis.srem(e.players_key, e.user_id)

      message = "#{e.username} leaves the PUG | #{e.player_slots}"
      send_and_log_message(message, event)
    end

    bot.command :end do |event, *args|
      e = EventWrapper.new(event)

      redis.del(e.pug_key)
      redis.del(e.players_key)

      message = "PUG ended"
      send_and_log_message(message, event)
    end

    bot.run
  end

  private

  def send_and_log_message(message, event)
    event.channel.send_message(message)
    puts message
  end

  def redis
    RedisClient.redis
  end
end

class EventWrapper
  def initialize(event)
    @event = event
    @redis = redis
  end

  def user_id
    @event.user.id
  end
  
  def username
    @event.user.username
  end

  def maxplayers_key
    [pug_key, "maxplayers"].join(":")
  end

  def maxplayers
    redis.get(maxplayers_key)
  end

  def number_in_lobby
    redis.scard(players_key)
  end

  def pug_key
    ["pug", @event.channel.id].join(":")
  end

  def players_key
    [pug_key, "players"].join(":")
  end

  def player_slots
    "#{number_in_lobby}/#{maxplayers}"
  end

  def users
    @event.channel.users
  end

  private

  def redis
    RedisClient.redis
  end
end

class RedisClient
  def self.redis
    @@redis ||= Redis.new
  end
end
