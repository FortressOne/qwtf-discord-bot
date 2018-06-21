require 'thor'

module DiscordQstatBot
	class CLI < Thor
		desc "server", "Runs the discord-qstat-bot"

		def server
			DiscordQstatBot::Server.run
		end
	end
end
