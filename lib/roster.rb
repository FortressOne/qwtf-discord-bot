class Roster
  attr_reader :teams

  def initialize
    @teams = []
  end

  def enroll(player)
    team_name = player.team
    team = @teams.find { |team| team.name == team_name }

    unless team
      team = Team.new(team_name)
      @teams << team
    end

    team.enlist(player)
  end
end
