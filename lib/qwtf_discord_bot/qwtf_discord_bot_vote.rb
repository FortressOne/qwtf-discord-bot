require 'pug'

class QwtfDiscordBotVote
  TIMER = 10
  REACTION_EMOJIS = ["🍏", "🍊", "🍋", "❌"]
  MSG_SNIPPET_DELIMITER = ' · '

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    # Add a help command to the bot
    bot.command(:help, description: 'Show a list of available commands') do |event|
      event.respond "Available commands:\n" + bot.commands.map { |name, command| "#{PREFIX}#{name} - #{command.attributes[:description]}" }.join("\n")
    end

    # Map votes
    votes = Hash.new(0)
    vote_thread = nil

    should_end_voting_mutex = Mutex.new
    should_end_voting = false

    map_names_mutex = Mutex.new
    map_names = []

    # Register the vote when someone adds a reaction
    bot.reaction_add do |event|
      if vote_thread&.alive? && event.message.id == @vote_message.id
        emoji = event.emoji.to_s
        if votes.key?(emoji)
          user_id = event.user.id
          unless event.user.current_bot?
            # Register the vote
            votes[emoji] += 1

            # Calculate the majority threshold
            majority = teamsize(event) + 1

            if votes[emoji] >= majority
              # A map has reached the majority of votes
              should_end_voting_mutex.synchronize { should_end_voting = true }
              announce_winner(event, [maps[emoji], votes[emoji]])
            end
          end
        end
      end
    end

    # Add a command to the bot for starting the voting process
    bot.command(:vote, description: 'Start the voting process') do |event|
      if vote_thread.nil? || !vote_thread.alive?
        # Reset the votes and the shared variable
        votes.clear
        should_end_voting_mutex.synchronize { should_end_voting = false }

        # Request map suggestions
        uri = URI([ENV['RESULTS_API_URL'], 'map_suggestions'].join('/'))
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

        req.body = {
          map_suggestion: { discord_channel_id: event.channel.id },
          size: 3
        }.to_json

        is_https = uri.scheme == "https"

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
          http.request(req)
        end

        body = JSON.parse(res.body)
        map_names_mutex.synchronize { map_names = body << "Different maps" }
        maps = REACTION_EMOJIS.zip(map_names).to_h

        # Create the vote message with reaction options

        embed = Discordrb::Webhooks::Embed.new
        embed.description = maps.map { |map| "#{map[0]} #{map[1]}" }.join("\n")
        message = "Voting started. #{TIMER} seconds."
        @vote_message = event.channel.send_embed(message, embed).tap do
          puts(embed.description)
        end

        # Voting process
        vote_thread = Thread.new do
          TIMER.times do
            break if should_end_voting
            sleep 1
          end

          if !should_end_voting
            # Voting time ended, announce the winner
            winner = votes.max_by { |_, v| v }
            announce_winner(event, winner)
          end
        end

        maps.each do |emoji, map_name|
          @vote_message.react(emoji)
          votes[emoji] = 0
        end
      else
        event.respond('Voting is already in progress!')
      end

      nil
    end

    # Function to announce the winner
    def announce_winner(event, winner)
      event.respond("The winner is #{winner[0]} with #{winner[1]} votes.")
    end

    def teamsize(event)
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)
      pug.teamsize
    end

    bot.run
  end
end
