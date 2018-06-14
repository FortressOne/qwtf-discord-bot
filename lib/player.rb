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

	def to_row
		"#{emoji}#{name}"
	end

	def team
		Team.new(@data["team"])
	end

	private

		def emoji
			Emoji.new(team: team, player_class: player_class).id || ""
		end

		def name
			@data["name"]
		end

		def player_class
			PLAYER_CLASSES[short_class]
		end

		def short_class
			skin.split("_").last
		end

		def skin
			@data["skin"]
		end
end
