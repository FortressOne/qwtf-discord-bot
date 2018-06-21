class Teams
	COLOURS = [:blue, :red, :yell, :gren, :other]

	def self.build
		@@teams = COLOURS.map do |colour|
			Team.new(colour)
		end
	end

	def self.find_by_colour(colour)
		@@teams.find { |team| team.colour == colour } || @@teams.find { |team| team.colour == nil }
	end

	def self.all
		@@teams
	end
end
