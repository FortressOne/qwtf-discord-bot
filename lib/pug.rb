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
    redis.setnx(pug_key, Time.now)

    redis.sadd(team_key(0), player_id)
  end

  def join_team(team_no:, player_id:)
    leave_teams(player_id)
    redis.sadd(team_key(team_no), player_id)
  end

  def joined_players
    teams_keys.inject([]) do |players, team|
      players + redis.smembers(team).map(&:to_i)
    end
  end

  def team(number)
    redis.smembers(team_key(number)).map(&:to_i)
  end

  def teamsize=(teamsize)
    redis.set(teamsize_key, teamsize)
  end

  def full?
    joined_player_count >= maxplayers
  end

  def empty?
    joined_player_count.zero?
  end

  def joined_player_count
    joined_players.count
  end

  def team_player_count(team_no)
    redis.scard(team_key(team_no)).to_i
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

  def teamsize
    (redis.get(teamsize_key) || DEFAULT_TEAMSIZE).to_i
  end

  def active?
    redis.get(pug_key)
  end

  def leave(player_id)
    leave_teams(player_id)
  end

  def end_pug
    redis.keys([pug_key, "*"].join).each do |key|
      redis.del(key)
    end
  end

  def joined?(player_id)
    joined_players.include?(player_id)
  end

  def maxplayers
    teamsize * no_of_teams
  end

  def won_by(team_no)
    { teams: teams, winner: team_no }
  end

  def teams
    teams_keys.inject({}) do |teams, team|
      teams.merge({ team.split(':').last => redis.smembers(team).map(&:to_i) })
    end
  end

  def actual_teams
    teams.tap { |team| team.delete("0") }
  end

  private

  def leave_teams(player_id)
    teams_keys.each do |team|
      redis.srem(team, player_id)
    end
  end

  def teams_keys
    redis.keys([pug_key, 'teams:*'].join(':'))
  end

  def team_key(team_no)
    [pug_key, 'teams', team_no].join(':')
  end

  def pug_key
    [channel_key, 'pug'].join(':')
  end

  def channel_key
    ['channel', @channel_id].join(':')
  end

  def notify_roles_key
    [channel_key, 'role'].join(':')
  end

  def teamsize_key
    [channel_key, 'teamsize'].join(':')
  end

  def redis
    Redis.current
  end

  def no_of_teams
    [actual_teams.count, MIN_NO_OF_TEAMS].max
  end
end
