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
		ary = ["#{emoji}"]
		ary << "**#{score}**" unless "#{score}".empty?
		ary << "#{name}"
		ary.join(" ")
	end

	def team
		@team ||= Teams.find_by_colour(@data["team"]).join(self)
	end

	def player_class
		PLAYER_CLASSES[short_class]
	end

	def score
		return "" unless team.playing?
		@data["score"]
	end

	private

		def emoji
			Emoji.new(self).to_s
		end

		def name
			@data["name"]
		end

		def short_class
			skin.split("_").last[0,3]
		end

		def skin
			@data["skin"]
		end
end
