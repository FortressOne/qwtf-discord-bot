class EventWrapper
  include QwtfDiscordBot

  DEFAULT_MAXPLAYERS = 8

  def initialize(event)
    @event = event
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
    redis.setnx(maxplayers_key, DEFAULT_MAXPLAYERS)
    redis.get(maxplayers_key).to_i
  end

  def joined_player_count
    redis.scard(players_key).to_i
  end

  def slots_left
    maxplayers - joined_player_count
  end

  def pug_key
    ["channel", @event.channel.id, "pug"].join(":")
  end

  def players_key
    [pug_key, "players"].join(":")
  end

  def player_slots
    "#{joined_player_count}/#{maxplayers}"
  end

  def users
    @event.server.users
  end

  def role_key
    [pug_key, "role"].join(":")
  end

  def role
    redis.get(role_key) || "@here"
  end
end
