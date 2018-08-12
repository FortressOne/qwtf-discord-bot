class QstatRequest
  def initialize(endpoint)
    @data = fetch_data(endpoint)
  end

  def output
    return server_summary unless has_players?
    [server_summary, player_table].join("\n")
  end

  def to_embed
    Discordrb::Webhooks::Embed.new(description: "hello")
  end

  def server_summary
    "#{address} | #{game_map} | #{numplayers}/#{maxplayers}"
  end

  def has_players?
    @data["players"] || false
  end

  def player_names
    players.map(&:name)
  end

  private

    def fetch_data(endpoint)
      JSON.parse(%x[qstat -json -P -qws #{endpoint}]).first
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
end
