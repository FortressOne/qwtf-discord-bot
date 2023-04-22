require 'pug'
require 'event_decorator'

class QwtfDiscordBotVote
  TIMER = 10
  NEW_MAP_EMOJI = "❌"
  CHOICE_EMOJIS = ["🍏", "🍊", "🍋", NEW_MAP_EMOJI]

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
    vote_thread = nil

    should_end_voting_mutex = Mutex.new
    should_end_voting = false

    choices_mutex = Mutex.new
    choices = {}

    vote_embed_mutex = Mutex.new
    vote_embed = nil

    embed_footer_mutex = Mutex.new
    embed_footer = {
      still_to_vote: [],
      seconds_remaining: TIMER,
      crosses: 0
    }

    bot.reaction_add do |event|
      next if event.message.id != @vote_message&.id

      emoji = event.emoji.to_s
      # event.message.delete_reaction(event.user, emoji)

      next if !vote_thread&.alive?
      next if !pug(event).joined?(event.user.id)
      next if event.user.current_bot?

      still_to_vote_players, new_map_vote_count = choices_mutex.synchronize do
        choices.each { |_emoji, hash| hash[:voters].delete(event.user) }
        choices[emoji][:voters] << event.user

        [
          still_to_vote(event: event, choices: choices),
          choices[NEW_MAP_EMOJI][:voters].count
        ]
      end

      embed_footer_mutex.synchronize do
        embed_footer[:still_to_vote] = still_to_vote_players
        embed_footer[:crosses] = new_map_vote_count
      end

      vote_embed_mutex.synchronize do
        @vote_message.edit(event.message, vote_embed)
      end

      # First map to reach teamsize votes is enough to prevent draws
      teamsize = pug(event).teamsize

      if choices[emoji][:voters].length >= teamsize || still_to_vote_players.empty?
        should_end_voting_mutex.synchronize { should_end_voting = true }
        announce_result(event, votes)
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
        choices.clear
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

        maps = JSON.parse(res.body) << nil

        map_choices = choices_mutex.synchronize do
          CHOICE_EMOJIS.each_with_index do |emoji, index|
            choices[emoji] = { map: maps[index], voters: [] }
          end

          choices.except(CHOICE_EMOJIS.last)
        end

        players = up_now_players(event)
        message = "#{players.map(&:display_name).to_sentence}; choose your maps"

        footer_text = embed_footer_mutex.synchronize do
          embed_footer[:still_to_vote] = players
          footer_to_string(embed_footer)
        end

        embed = vote_embed_mutex.synchronize do
          vote_embed = Discordrb::Webhooks::Embed.new

          map_choices.each do |emoji, attrs|
            vote_embed.add_field(
              inline: true,
              name: "#{emoji} #{attrs[:map]}",
              value: attrs[:voters].map(&:display_name).join("\n")
            )
          end

          vote_embed.footer = Discordrb::Webhooks::EmbedFooter.new(
            text: footer_text
          )

          vote_embed
        end

        @vote_message = event.channel.send_embed(message, embed).tap do
          puts(embed.description)
        end

        CHOICE_EMOJIS.each do |emoji|
          @vote_message.react(emoji)
        end

        sleep(1)

        vote_thread = Thread.new do
          TIMER.times do |i|
            break if should_end_voting

            footer_text = embed_footer_mutex.synchronize do
              embed_footer[:seconds_remaining] = TIMER - 1 - i
              footer_to_string(embed_footer)
            end

            vote_embed_mutex.synchronize do
              vote_embed = Discordrb::Webhooks::Embed.new

              map_choices.each do |emoji, attrs|
                vote_embed.add_field(
                  inline: true,
                  name: "#{emoji} #{attrs[:map]}",
                  value: attrs[:voters].map(&:display_name).join("\n")
                )
              end

              vote_embed.footer = Discordrb::Webhooks::EmbedFooter.new(
                text: footer_text
              )
            end

            @vote_message.edit(message, vote_embed)

            sleep(1) # Rate limit is 5 edits per 5 seconds per message

            if i == TIMER - 1
              choices_mutex.synchronize { announce_result(event, choices) }
            end
          end
        end

        nil
      end
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

  def announce_result(event, choices)
    max_votes = choices.values.map { |hash| hash[:voters].size }.max

    winners = choices
      .values
      .select { |hash| hash[:voters].size == max_votes }

    if winners.size > 1
      announce_draw(event, winners)
    else
      announce_winner(event, winners.first)
    end
  end

  def announce_winner(event, winner)
    event.respond("The winner is #{winner[:map]} with #{winner[:voters].length} votes.")
  end

  def announce_draw(event, winners)
    winner_maps = winners.map { |hash| hash[:map] }.compact.to_sentence
    event.respond("It's a draw between: #{winner_maps}")
  end

  def footer_to_string(embed_footer)
    <<~STRING
      #{embed_footer[:still_to_vote].map(&:display_name).to_sentence} still to vote
      #{embed_footer[:seconds_remaining]} seconds remaining
      #{CHOICE_EMOJIS.last * embed_footer[:crosses]}
    STRING
  end

  def up_now_players(event)
    pug(event).up_now_players.map do |discord_id|
      event.server.member(discord_id)
    end
  end

  def still_to_vote(event:, choices:)
    up_now_players(event) - choices.values.map { |hash| hash[:voters] }.flatten
  end
end
