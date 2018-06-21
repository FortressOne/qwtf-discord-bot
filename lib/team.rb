class Team
	TEAMS = {blue: 1, red: 2, yell: 3, gren: 4}

	attr_reader :colour, :number, :players

	def initialize(colour)
		@colour = TEAMS[colour] ? colour : nil
		@number = TEAMS[colour]
		@players = []
	end

	def join(player)
		@players << player unless @players.include?(player)
	end

	def playing?
		[1, 2, 3, 4].include?(@number)
	end
end
