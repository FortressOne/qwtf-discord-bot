class Team
	attr_accessor :number

	TEAMS = {1 => "blue", 2 => "red", 3 => "yell", 4 => "gren"}

	def initialize(str)
		@number = str if TEAMS.keys.include?(str)
		@number = TEAMS.key(str) if TEAMS.values.include?(str)
	end

	def colour
		TEAMS[@number]
	end
end
