require 'pug'

class QwtfDiscordBotVote
  TIMER = 10
  # REACTION_EMOJIS = ["🍏", "🍊", "🍋", "❌"]
  REACTION_EMOJIS = ["🍏", "🍊", "🍋"]

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

    embed_mutex = Mutex.new
    embed = nil

    bot.reaction_add do |event|
      next if !vote_thread&.alive?
      next if !pug(event).joined?(event.user.id)
      next if event.message.id != @vote_message.id

      emoji = event.emoji.to_s
      map_name = REACTION_EMOJIS.zip(map_names).to_h[emoji]

      if votes.key?(map_name)
        user_id = event.user.id

        if !event.user.current_bot?
          votes.each { |map_name, voters| voters.delete(event.user.name) }
          votes[map_name] << event.user.name
          majority = pug(event).teamsize + 1
          event.message.delete_reaction(event.user, emoji)

          # Update the embed with the user's name
          embed_mutex.synchronize do
            map_field = embed.fields.each do |field|
              map_name = field.name.split(" ").last
              field.value = votes[map_name].join("\n")
            end

            @vote_message.edit(nil, embed)
          end

          if votes[map_name].length >= majority
            should_end_voting_mutex.synchronize { should_end_voting = true }
            announce_winner(event, [maps[emoji], votes[map_name].length])
          end
        end
      end
    end

    bot.command(:vote, description: 'Start the voting process') do |event|
      if vote_thread.nil? || !vote_thread.alive?
        votes.clear
        should_end_voting_mutex.synchronize { should_end_voting = false }

        uri = URI([ENV['RESULTS_API_URL'], 'map_suggestions', 'vote'].join('/'))
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

        req.body = {
          map_suggestion: {
            channel_id: event.channel.id,
            for_teamsize: pug(event).teamsize,
          }
        }.to_json

        is_https = uri.scheme == "https"

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
          http.request(req)
        end

        body = JSON.parse(res.body)
        map_names_mutex.synchronize { map_names = body }
        maps = REACTION_EMOJIS.zip(map_names).to_h

        # Create the vote message with reaction options
        embed = Discordrb::Webhooks::Embed.new

        maps.map do |map|
          embed.add_field(
            inline: true,
            name: "#{map[0]} #{map[1]}",
            value: ""
          )
        end

        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "")

        message = "Joined players, choose your maps"
        @vote_message = event.channel.send_embed(message, embed).tap do
          puts(embed.description)
        end

        # Voting process
        vote_thread = Thread.new do
          TIMER.times do |i|
            break if should_end_voting

            embed_mutex.synchronize do
              embed.footer = Discordrb::Webhooks::EmbedFooter.new(
                text: "#{TIMER - i} seconds remaining"
              )
            end

            @vote_message.edit(message, embed)

            sleep 1
          end

          if !should_end_voting
            embed_mutex.synchronize do
              embed.footer = Discordrb::Webhooks::EmbedFooter.new(
                text: "0 seconds remaining"
              )
            end

            @vote_message.edit(message, embed)

            winning_votes = votes.values.max
            winners = votes.select { |_, v| v == winning_votes }

            if winners.size > 1
              announce_draw(event, winners)
            else
              announce_winner(event, winners.first)
            end
          end
        end

        maps.each do |emoji, map_name|
          @vote_message.react(emoji)
          votes[map_name] = []
        end
      else
        event.respond('Voting is already in progress!')
      end

      nil
    end

    bot.command :map do |event, *args|
      uri = URI([ENV['RESULTS_API_URL'], 'map_suggestions'].join('/'))
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

      req.body = {
        map_suggestion: {
          discord_channel_id: event.channel.id,
          discord_player_id: event.user.id,
          discord_player_name: evenr.user.nickname
        }
      }.to_json

      is_https = uri.scheme == "https"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
        http.request(req)
      end

      body = JSON.parse(res.body)

      description = if body
                      "How about #{body}?"
                    else
                      "I'm out of ideas, you choose."
                    end

      send_embedded_message(
        description: description,
        channel: event.channel
      )
    end

    def announce_winner(event, winner)
      event.respond("The winner is #{winner[0]} with #{winner[1].length} votes.")
    end

    def announce_draw(event, winners)
      winner_maps = winners.keys.join(', ')
      event.respond("It's a draw between: #{winner_maps}")
    end

    def pug(event)
      Pug.for(event.channel.id)
    end

    bot.run
  end
end
