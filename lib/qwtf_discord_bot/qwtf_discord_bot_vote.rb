require 'pug'
require 'event_decorator'

class QwtfDiscordBotVote
  TIMER = 60
  REACTION_EMOJIS = ["🍏", "🍊", "🍋"] # "❌"

  COMMANDS = <<~MESSAGE
    `!map` Suggest a map
    `!maps` See map suggestion list for this channel
    `!vote` Map vote. Only !joined players can vote. Ends after three minutes, or when an option reaches teamsize.
  MESSAGE

  HELP = { commands: COMMANDS, footer: "!command <required> [optional]" }

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    # Map votes
    votes = Hash.new(0)
    vote_thread = nil
    should_end_voting_mutex = Mutex.new
    should_end_voting = false
    map_names_mutex = Mutex.new
    map_names = []
    vote_embed_mutex = Mutex.new
    vote_embed = nil

    bot.reaction_add do |event|
      next if event.message.id != @vote_message&.id

      emoji = event.emoji.to_s
      event.message.delete_reaction(event.user, emoji)

      next if !vote_thread&.alive?
      next if !pug(event).joined?(event.user.id)

      map_name = REACTION_EMOJIS.zip(map_names).to_h[emoji]

      if !event.user.current_bot? && votes.key?(map_name)
        # Remove player's vote from all maps
        votes.each { |_map_name, voters| voters.delete(event.user) }

        # Add player's vote to selected map
        votes[map_name] << event.user

        # Update embedded message
        vote_embed_mutex.synchronize do
          map_field = vote_embed.fields.each do |field|
            map_name = field.name.split(" ").last
            field.value = votes[map_name].map(&:display_name).join("\n")

            users = pug(event).up_now_players.map do |discord_id|
              event.server.member(discord_id)
            end

            users -= votes.inject([]) { |users, vote| users += vote[1] }

            footer_lines = vote_embed.footer.text.split("\n")

            footer_text = [
              "#{users.map(&:display_name).join(", ")} still to vote",
              footer_lines[1]
            ].join("\n")

            vote_embed.footer.text = footer_text
          end
        end

        @vote_message.edit(event.message, vote_embed)

        # First map to reach teamsize votes is enough to prevent draws
        teamsize = pug(event).teamsize

        # If majority reached, or all players have voted
        if votes[map_name].length >= teamsize || votes.values.sum(&:count) >= (teamsize * 2)
          should_end_voting_mutex.synchronize { should_end_voting = true }
          announce_result(event, votes)
        end
      end
    end

    bot.command :help do |event, *args|
      send_embedded_message(
        description: HELP[:commands],
        channel: event.channel
      ) do |embed|
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: HELP[:footer]
        )
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
        maps = REACTION_EMOJIS.zip(map_names).select { |emoji, map_name| !map_name.nil? }.to_h
        vote_embed = Discordrb::Webhooks::Embed.new

        maps.map do |map|
          vote_embed.add_field(
            inline: true,
            name: "#{map[0]} #{map[1]}",
            value: ""
          )
        end

        users = pug(event).up_now_players.map do |discord_id|
          event.server.member(discord_id)
        end

        users -= votes.inject([]) { |users, vote| users += vote[1] }

        vote_embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: "#{users.map(&:display_name).join(", ")} still to vote\n#{TIMER} seconds remaining",
        )

        message = "#{users.map(&:display_name).join(", ")} choose your maps"

        @vote_message = event.channel.send_embed(message, vote_embed).tap do
          puts(vote_embed.description)
        end

        vote_thread = Thread.new do
          TIMER.times do |i|
            break if should_end_voting

              users = pug(event).up_now_players.map do |discord_id|
                event.server.member(discord_id)
              end

              users -= votes.inject([]) { |users, vote| users += vote[1] }

              footer_lines = vote_embed.footer.text.split("\n")

              footer_text = [
                "#{users.map(&:display_name).join(", ")} still to vote",
                "#{TIMER - i} seconds remaining"
              ].join("\n")

            vote_embed_mutex.synchronize do
              vote_embed.footer.text = footer_text
            end

            @vote_message.edit(message, vote_embed)

            sleep 1
          end

          if !should_end_voting
            vote_embed_mutex.synchronize do
              vote_embed.footer = Discordrb::Webhooks::EmbedFooter.new(
                text: "0 seconds remaining"
              )
            end

            @vote_message.edit(message, vote_embed)
            announce_result(event, votes)
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
          channel_id: event.channel.id,
          discord_player_id: event.user.id,
          for_teamsize: pug(event).teamsize,
        }
      }.to_json

      is_https = uri.scheme == "https"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
        http.request(req)
      end

      body = JSON.parse(res.body)
      map_embed = Discordrb::Webhooks::Embed.new

      map_embed.description = if body
                                "How about #{body}?"
                              else
                                "I'm out of ideas, you choose."
                              end

      event.channel.send_embed(nil, map_embed).tap do
        puts(map_embed.description)
      end
    end

    bot.command :maps do |event, *args|
      uri = URI([ENV['RESULTS_API_URL'], 'map_suggestions'].join('/'))

      uri.query = URI.encode_www_form(
        "map_suggestion[discord_channel_id]" => event.channel.id
      )

      req = Net::HTTP::Get.new(uri)
      is_https = uri.scheme == "https"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
        http.request(req)
      end

      maps_embed = Discordrb::Webhooks::Embed.new
      body = JSON.parse(res.body)

      body.each do |teamsize, maps|
        if maps.any?
          maps_embed.add_field(name: "#{teamsize}v#{teamsize}", value: maps.join(", "))
        end
      end

      if maps_embed.fields.empty?
        maps_embed.description = "No maps set for this channel"
      end

      event.channel.send_embed(nil, maps_embed).tap do
        puts(maps_embed.description)
      end
    end

    bot.run
  end

  private

  # todo refactor (shared with qwtf_discord_bot_pug.rb)
  def pug(event)
    Pug.for(event.channel.id)
  end

  def send_embedded_message(message: nil, description: nil, channel:, message_obj: nil)
    embed = Discordrb::Webhooks::Embed.new
    embed.description = description
    yield(embed) if block_given?

    if message_obj
      message_obj.edit(message, embed).tap do
        puts(message)
      end
    else
      channel.send_embed(message, embed).tap do
        puts(message)
      end
    end
  end

  def announce_result(event, votes)
    max_votes = votes.values.map(&:size).max
    winners = votes.select { |_, v| v.size == max_votes }

    if winners.size > 1
      announce_draw(event, winners)
    else
      announce_winner(event, winners.first)
    end
  end

  def announce_winner(event, winner)
    event.respond("The winner is #{winner[0]} with #{winner[1].length} votes.")
  end

  def announce_draw(event, winners)
    winner_maps = winners.keys.join(', ')
    event.respond("It's a draw between: #{winner_maps}")
  end
end
