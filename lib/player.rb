class Player
  PLAYER_CLASSES = {
    'sco' => 'scout',
    'sni' => 'sniper',
    'sol' => 'soldier',
    'dem' => 'demoman',
    'med' => 'medic',
    'pyr' => 'pyro',
    'hwg' => 'hwguy',
    'spy' => 'spy',
    'eng' => 'engineer'
  }.freeze

  def initialize(data)
    @data = data
  end

  def name
    @data['name']
  end

  def score
    @data['score']
  end

  def to_row
    "#{emoji}#{name}"
  end

  def team
    return 'spec' unless valid_score?
    @data['team']
  end

  def player_class
    PLAYER_CLASSES[short_class]
  end

  private

  def emoji
    Emoji.for(team: team.to_s, player_class: player_class)
  end

  def short_class
    skin.split('_').last
  end

  def skin
    @data['skin']
  end

  def valid_score?
    score >= 0
  end
end
