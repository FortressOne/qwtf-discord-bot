class QstatRequest
  MSG_SNIPPET_DELIMITER = ' · '

  attr_accessor :result

  def initialize(endpoint)
    @endpoint = endpoint
  end

  def result
    @result ||= execute
  end

  def to_full_embed
    Discordrb::Webhooks::Embed.new.tap do |embed|
      embed.add_field(
        name: name,
        value: join_link,
      )

      teams.each do |team|
        embed << team.to_embed_field
      end

      footer = [game_map, "#{numplayers}/#{maxplayers} players"]

      if has_spectators?
        footer << "#{numspectators}/#{maxspectators} spectators"
      end

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: footer.join(MSG_SNIPPET_DELIMITER)
      )
    end
  end

  def to_message
    return server_summary if is_empty?

    [server_summary, player_table].join("\n")
  end

  def server_summary
    return "#{@endpoint} isn't responding" unless game_map

    info = [name, @endpoint, game_map]

    info += if !has_spectators?
              ["#{numplayers}/#{maxplayers}"]
            else
              [
                "#{numplayers}/#{maxplayers} players",
                "#{numspectators}/#{maxspectators} spectators"
              ]
            end

    info.join(MSG_SNIPPET_DELIMITER)
  end

  def join_link
    "<qw://#{@endpoint}>"
  end

  def is_empty?
    !has_players? && !has_spectators?
  end

  def player_names
    players.map(&:name)
  end

  def has_players?
    numplayers && numplayers > 0
  end

  def live_server?
    !game_map.nil?
  end

  private

  def has_spectators?
    numspectators && numspectators > 0
  end

  def teams
    @teams ||= build_roster
  end

  def data
    @data ||= JSON.parse(result).first
  end

  def execute
    `qstat -json -P -qws #{@endpoint}`
  end

  def player_table
    players.sort_by { |player| player.team.number }.map(&:to_row).join("\n")
  end

  def name
    name = data['name']
    return address if name.empty?

    name
  end

  def address
    data['address']
  end

  def game_map
    data['map']
  end

  def numplayers
    data['numplayers']
  end

  def maxplayers
    data['maxplayers']
  end

  def numspectators
    data['numspectators']
  end

  def maxspectators
    data['maxspectators']
  end

  def build_roster
    return [] if is_empty?

    roster = Roster.new

    data['players'].map do |player_data|
      player = Player.new(player_data)
      roster.enroll(player)
    end

    roster.teams.sort_by { |team| team.number }
  end

  def players
    data['players'].map do |player_data|
      Player.new(player_data)
    end
  end
end
