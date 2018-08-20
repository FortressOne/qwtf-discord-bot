class QstatRequest
  def initialize(endpoint)
    @endpoint = endpoint
    @data = fetch_data
  end

  def teams
    @teams ||= begin
                 return nil unless has_players?
                 build_roster
               end
  end

  def to_message
    return server_summary unless has_players?
    [server_summary, player_table].join("\n")
  end

  def to_embed
    return nil unless has_players?

    embed = Discordrb::Webhooks::Embed.new

    teams.each do |_name, team|
      embed.add_field(team.to_embed_field)
    end

    embed
  end

  def server_summary
    return "#{@endpoint} isn't responding" unless game_map
    "#{@endpoint} | #{game_map} | #{numplayers}/#{maxplayers}"
  end

  def has_players?
    @data["players"] && @data["players"].any?
  end

  def player_names
    players.map(&:name)
  end

  private

    def fetch_data
      JSON.parse(%x[qstat -json -P -qws #{@endpoint}]).first
    end

    def player_table
      players.sort_by { |player| player.team.number }.map(&:to_row).join("\n")
    end

    def address
      @data["address"]
    end

    def game_map
      @data["map"]
    end

    def numplayers
      @data["numplayers"]
    end

    def maxplayers
      @data["maxplayers"]
    end

    def build_roster
      roster = {}

      @data["players"].map do |player_data|
        player = Player.new(player_data)
        team_name = player.team
        roster[team_name] ||= Team.new(team_name)
        roster[team_name].enlist(player)
      end

      roster
    end

    def players
      @data["players"].map do |player_data|
        Player.new(player_data)
      end
    end

    def players_from_team(team)
      players.select { |player| player.team_name == team }.map(&:player_name)
    end
end
