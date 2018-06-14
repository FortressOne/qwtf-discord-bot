class Team
	attr_accessor :number

	TEAMS = { spec: 0, blue: 1, red: 2, yell: 3, gren: 4 }

	def initialize(sym)
		@number = TEAMS[sym] || 0
	end

	def to_s
		TEAMS.key(@number).to_s
	end
end
