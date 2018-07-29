require 'thor'

module QwtfDiscordBot
	class CLI < Thor
		desc "server", "Runs the qwtf-discord-bot"
		def server
			QwtfDiscordBot::Server.run
		end
	end
end
