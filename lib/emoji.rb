class Emoji
	LOOKUP = {
		"red" => {
			"scout"    => "<:scout_red:424097703127941130>",
			"sniper"   => "<:sniper_red:424097704076115978>",
			"soldier"  => "<:soldier_red:424097704197619712>",
			"demoman"  => "<:demoman_red:424097687739301919>",
			"medic"    => "<:medic_red:424097695418941451>",
			"pyro"     => "<:pyro_red:424097704403271691>",
			"hwguy"    => "<:hwguy_red:424097694030757889>",
			"spy"      => "<:spy_red:424097704138899466>",
			"engineer" => "<:engineer_red:424097694680612864>"
		},
		"blue" => {
			"scout"    => "<:scout_blue:456062063983460353>",
			"sniper"   => "<:sniper_blue:456062061953417216>",
			"soldier"  => "<:soldier_blue:456062062997536801>",
			"demoman"  => "<:demoman_blue:456061938636554240>",
			"medic"    => "<:medic_blue:456062056710537217>",
			"pyro"     => "<:pyro_blue:456062062460928010>",
			"hwguy"    => "<:hwguy_blue:456062063190736926>",
			"spy"      => "<:spy_blue:456062062032846849>",
			"engineer" => "<:engineer_blue:456062031125020683>"
		}
	} 

	def initialize(team:, player_class:)
		@team = team
		@player_class = player_class
	end

	def id
		@id ||= LOOKUP[@team][@player_class]
	end
end
