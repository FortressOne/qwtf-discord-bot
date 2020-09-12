class Pug
  DEFAULT_TEAMSIZE = 4
  NO_OF_TEAMS = 2

  def self.for(channel_id)
    new(channel_id)
  end

  def initialize(channel_id)
    @channel_id = channel_id
  end

  def join(user_id)
    redis.setnx(pug_key, Time.now)
    redis.sadd(players_key, user_id)
  end

  def joined_players
    redis.smembers(players_key).map(&:to_i)
  end

  def team(no)
    index = no - 1
    joined_players.each_slice(teamsize).to_a[index]
  end

  def teamsize=(teamsize)
    redis.set(teamsize_key, teamsize)
  end

  def full?
    joined_player_count >= maxplayers
  end

  def joined_player_count
    redis.scard(players_key).to_i
  end

  def player_slots
    "#{joined_player_count}/#{maxplayers}"
  end

  def slots_left
    maxplayers - joined_player_count
  end

  def notify_roles=(roles)
    redis.set(notify_roles_key, roles)
  end

  def notify_roles
    redis.get(notify_roles_key) || '@here'
  end

  def teamsize=(teamsize)
    redis.set(teamsize_key, teamsize)
  end

  def teamsize
    (redis.get(teamsize_key) || DEFAULT_TEAMSIZE).to_i
  end

  def active?
    redis.get(pug_key)
  end

  def leave(player_id)
    redis.srem(players_key, player_id)
    end_pug if empty?
  end

  def end_pug
    redis.del(pug_key)
    redis.del(players_key)
  end

  def joined?(player_id)
    joined_players.include?(player_id)
  end

  def maxplayers
    teamsize * NO_OF_TEAMS
  end

  private

  def empty?
    joined_player_count.zero?
  end

  def teamsize_key
    [pug_key, 'teamsize'].join(':')
  end

  def players_key
    [pug_key, 'players'].join(':')
  end

  def pug_key
    ['pug', 'channel', @channel_id].join(':')
  end

  def notify_roles_key
    [pug_key, 'role'].join(':')
  end

  def teamsize_key
    [pug_key, 'teamsize'].join(':')
  end

  def redis
    Redis.current
  end
end
