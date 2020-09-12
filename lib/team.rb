class Team
  attr_accessor :name, :number, :players

  TEAMS = { 'blue' => 1, 'red' => 2, 'yell' => 3, 'gren' => 4, 'spec' => 5 }.freeze

  def initialize(name)
    @name = build_name(name)
    @number = TEAMS[name] || 5
    @players = []
  end

  def enlist(player)
    @players << player
  end

  def to_embed_field
    Discordrb::Webhooks::EmbedField.new(inline: true, name: field_name, value: player_list)
  end

  private

  def field_name
    name = @name.capitalize
    return name.to_s unless playing?

    "#{name} | #{score}"
  end

  def playing?
    (1..4).include?(@number)
  end

  def player_list
    players.map(&:to_row).join("\n")
  end

  def score
    return nil if @name == 'spec'

    @players.first.score
  end

  def build_name(name)
    return name if TEAMS[name]

    'spec'
  end
end
