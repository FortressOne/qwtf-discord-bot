class Pug
  DEFAULT_TEAMSIZE = 4
  MIN_NO_OF_TEAMS = 2

  def self.for(channel_id)
    new(channel_id)
  end

  def initialize(channel_id)
    @channel_id = channel_id
  end

  def join(player_id)
    timestamp = Time.now.to_i
    redis.setnx(pug_key, timestamp)
    redis.zadd(queue_key, timestamp, player_id, nx: true)
  end

  def join_team(team_no:, player_id:)
    join(player_id)
    unteam(player_id)
    redis.sadd(team_key(team_no), player_id)
  end

  def up_now_players
    players[0, maxplayers]
  end

  def destroy_teams
    teamed_players.each do |player_id|
      unteam(player_id)
    end
  end

  def teamed_players
    teams_keys.inject([]) do |players, team|
      players + redis.smembers(team).map(&:to_i)
    end
  end

  def add_maps(maps)
    redis.sadd(maps_key, maps)
  end

  def remove_maps(maps)
    redis.srem(maps_key, maps)
  end

  def maps
    redis.smembers(maps_key)
  end

  def vote(player_id:, map:)
    redis.sadd(votes_key(map), player_id)
  end

  def vote_count(map)
    redis.scard(votes_key(map)).to_i
  end

  def team(number)
    redis.smembers(team_key(number)).map(&:to_i)
  end

  def teamsize=(teamsize)
    redis.set(teamsize_key, teamsize)
  end

  def total_player_count
    players.count
  end

  def full?
    total_player_count >= maxplayers
  end

  def has_exactly_maxplayers?
    total_player_count == maxplayers
  end

  def empty?
    total_player_count.zero?
  end

  def teamed_player_count
    teamed_players.count
  end

  def team_player_count(team_no)
    redis.scard(team_key(team_no)).to_i
  end

  def player_slots
    "#{total_player_count}/#{maxplayers}"
  end

  def slots_left
    maxplayers - total_player_count
  end

  def notify_roles=(roles)
    redis.set(notify_roles_key, roles)
  end

  def notify_roles
    redis.get(notify_roles_key) || '@here'
  end

  def teamsize
    (redis.get(teamsize_key) || DEFAULT_TEAMSIZE).to_i
  end

  def active?
    redis.get(pug_key)
  end

  def leave(player_id)
    leave_queue(player_id)
    unteam(player_id)
  end

  def end_pug
    redis.keys([pug_key, "*"].join).each do |key|
      redis.del(key)
    end
  end

  def joined?(player_id)
    redis.zrank(queue_key, player_id)
  end

  def maxplayers
    teamsize * no_of_teams
  end

  def queued_players
    players - teamed_players
  end

  def teams
    all_teams = teams_keys.inject({}) do |teams, team|
      teams.merge({ team.split(':').last.to_i => redis.smembers(team).map(&:to_i) })
    end

    all_teams.sort.to_h
  end

  def update_last_result_time
    redis.set(last_result_time_key, Time.now.to_i)
  end

  def last_result_time
    redis.get(last_result_time_key).to_i
  end

  def equal_number_of_players_on_each_team?
    team_player_counts = teams.map do |_name, players|
      players.size
    end

    team_player_counts.uniq.size == 1
  end

  def unteam(player_id)
    teams_keys.each do |team|
      redis.srem(team, player_id)
    end
  end

  def players
    redis.zrange(queue_key, 0, -1).map(&:to_i)
  end

  private

  def leave_queue(player_id)
    redis.zrem(queue_key, player_id)
  end

  def teams_keys
    redis.keys([pug_key, 'teams:*'].join(':'))
  end

  def queue_key
    [pug_key, 'queue'].join(':')
  end

  def team_key(team_no)
    [pug_key, 'teams', team_no].join(':')
  end

  def last_result_time_key
    [channel_key, 'last_result_time'].join(':')
  end

  def pug_key
    [channel_key, 'pug'].join(':')
  end

  def maps_key
    [channel_key, 'maps'].join(':')
  end

  def notify_roles_key
    [channel_key, 'role'].join(':')
  end

  def teamsize_key
    [channel_key, 'teamsize'].join(':')
  end

  def votes_keys
    redis.keys([pug_key, 'votes:*'].join(':'))
  end

  def votes_key(map)
    [channel_key, 'votes', map].join(':')
  end

  def channel_key
    ['channel', @channel_id].join(':')
  end

  def redis
    Redis.current
  end

  def no_of_teams
    [teams.count, MIN_NO_OF_TEAMS].max
  end
end
