class QstatRequest
  def initialize(endpoint)
    @endpoint = endpoint
    @data = fetch_data
  end

  def teams
    @teams ||= begin
                 return nil unless has_players?

                 roster = {}

                 teams = players.map(&:team).uniq
                 teams.each { |team| roster[team] = [] }

                 players.each do |player|
                   roster[player.team] << player
                 end

                 roster
               end
  end

  def to_message
    return server_summary unless has_players?
    [server_summary, player_table].join("\n")
  end

  def to_embed
    return nil unless has_players?

    embed = Discordrb::Webhooks::Embed.new

    teams.each do |team, players|
      player_list = players.map(&:to_row).join("\n")
      score = players.first.score

      field_name = case
                   when team.empty? then "No Team"
                   when score < 0 then "#{team.capitalize}"
                   when score >= 0 then "#{team.capitalize} | #{score}"
                   end

      embed.add_field(Discordrb::Webhooks::EmbedField.new(inline: true, name: field_name, value: player_list))
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

    def players
      @data["players"].map do |player_data|
        Player.new(player_data)
      end
    end

    def players_from_team(team)
      players.select { |player| player.team_name == team }.map(&:player_name)
    end
end
