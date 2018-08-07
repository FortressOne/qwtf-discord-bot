class Player
  PLAYER_CLASSES = {
    "sco" => "scout",
    "sni" => "sniper",
    "sol" => "soldier",
    "dem" => "demoman",
    "med" => "medic",
    "pyr" => "pyro",
    "hwg" => "hwguy",
    "spy" => "spy",
    "eng" => "engineer"
  }

  def initialize(data)
    @data = data
  end

  def name
    @data["name"]
  end

  def to_row
    "#{emoji}#{name}"
  end

  def team
    @team ||= Team.new(@data["team"].to_sym)
  end

  def player_class
    PLAYER_CLASSES[short_class]
  end

  private

    def emoji
      Emoji.new(self).to_s
    end

    def short_class
      skin.split("_").last
    end

    def skin
      @data["skin"]
    end
end
