require 'pug'
require 'event_decorator'

class QwtfDiscordBotVote
  TIMER = 60
  NEW_MAPS_EMOJI = "❌"
  CHOICE_EMOJIS = ["🍏", "🍊", "🍋", NEW_MAPS_EMOJI]

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
      prefix: proc do |message|
        match = /^\!(\w+)(.*)/.match(message.content)
        if match
          first = match[1]
          rest = match[2]
          # Return the modified string with the first word lowercase:
          "#{first.downcase}#{rest}"
        end
      end
    )

    # Map votes
    @state_mutex = Mutex.new
    @state = {}

    bot.reaction_add do |event|
      channel_id = event.channel.id
      current_state = @state_mutex.synchronize { @state[channel_id] }
      next if event.message.id != current_state[:vote_message]&.id

      emoji = event.emoji.to_s

      reasons_to_remove_reaction = [
        !pug(event).joined?(event.user.id),
        !CHOICE_EMOJIS.include?(emoji),
        event.user.current_bot?,
        current_state[:should_end_voting]
      ]

      if reasons_to_remove_reaction.any?
        event.message.delete_reaction(event.user, emoji)
        break
      end

      current_state = @state_mutex.synchronize do
        @state[channel_id].tap do |channel_state|
          channel_state[:choices].each { |_emoji, hash| hash[:voters].delete(event.user) }
          channel_state[:choices][emoji][:voters] << event.user
          channel_state[:footer][:still_to_vote] = still_to_vote(event: event, choices: channel_state[:choices])
          channel_state[:footer][:crosses] = channel_state[:choices][NEW_MAPS_EMOJI][:voters].count
        end
      end

      current_state[:choices].except(emoji).keys.each do |emoji|
        event.message.delete_reaction(event.user, emoji)
      end

      # First map to reach teamsize votes is enough to prevent draws
      teamsize = pug(event).teamsize

      reasons_to_end_vote = [
        current_state[:choices][emoji][:voters].length >= teamsize,
        current_state[:footer][:crosses] >= current_state[:footer][:new_maps_threshold],
        current_state[:footer][:still_to_vote].empty?
      ]

      if reasons_to_end_vote.any?
        current_state = @state_mutex.synchronize do
          @state[channel_id].merge!(should_end_voting: true)
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
      run_vote(event, "Time to vote")
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
                                "I'm out of ideas, you choose"
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

  def run_vote(event, message)
    channel_id = event.channel.id
    players = up_now_players(event)
    teamsize = pug(event).teamsize

    current_state = @state_mutex.synchronize do
      @state[channel_id] = {
        should_end_voting: false,
        footer: {
          seconds_remaining: TIMER,
          still_to_vote: players,
          crosses: 0,
          new_maps_threshold: teamsize / 2
        }
      }
    end

    uri = URI([ENV['RESULTS_API_URL'], 'map_suggestions', 'vote'].join('/'))
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

    req.body = {
      map_suggestion: {
        channel_id: channel_id,
        for_teamsize: teamsize,
      }
    }.to_json

    is_https = uri.scheme == "https"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
      http.request(req)
    end

    maps = JSON.parse(res.body) << nil # nil for the ❌ new maps option

    choices = CHOICE_EMOJIS.zip(maps).inject({}) do |hash, (emoji, map)|
      hash.merge(emoji => { map: map, voters: [] })
    end

    current_state = @state_mutex.synchronize do
      @state[channel_id].merge!(choices: choices)
    end

    embed = Discordrb::Webhooks::Embed.new

    choices.except(NEW_MAPS_EMOJI).each do |emoji, attrs|
      embed.add_field(
        inline: true,
        name: "#{emoji} #{attrs[:map]}",
        value: attrs[:voters].map(&:display_name).join("\n")
      )
    end

    embed.footer = Discordrb::Webhooks::EmbedFooter.new(
      text: footer_text(current_state[:footer])
    )

    vote_message = event.channel.send_embed(message, embed)

    current_state = @state_mutex.synchronize do
      @state[channel_id].tap do |channel_state|
        channel_state[:vote_message] = vote_message
      end
    end

    Thread.new do
      CHOICE_EMOJIS.each do |emoji|
        vote_message.react(emoji) # discordrb rate limits these to 250ms a pop
      end

      TIMER.times do |i|
        break if current_state[:should_end_voting]

        current_state = @state_mutex.synchronize do
          @state[channel_id][:footer][:seconds_remaining] = TIMER - 1 - i
          @state[channel_id]
        end

        sleep(1)
        update_embed(current_state)

        if i == (TIMER - 1)
          current_state = @state_mutex.synchronize do
            @state[channel_id].merge!(should_end_voting: true)
          end
        end
      end

      announce_result(event: event, state: current_state)
    end

    nil
  end

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

  def update_embed(state)
    embed = Discordrb::Webhooks::Embed.new

    state[:choices].except(NEW_MAPS_EMOJI).each do |emoji, attrs|
      embed.add_field(
        inline: true,
        name: "#{emoji} #{attrs[:map]}",
        value: attrs[:voters].map(&:display_name).join("\n")
      )
    end

    embed.footer = Discordrb::Webhooks::EmbedFooter.new(
      text: footer_text(state[:footer])
    )

    state[:vote_message].edit(state[:vote_message], embed)
  end

  def announce_result(event:, state:)
    maps = state[:choices].values
    max_votes = maps.map { |hash| hash[:voters].size }.max
    winners = maps.select { |hash| hash[:voters].size == max_votes }

    if max_votes <= 0
      message = "No votes casted, aborting vote"
      state[:footer][:status] = message
      update_embed(state)
      event.channel.send_message(message)
    elsif winners.size > 1
      if winners.map { |winner| winner[:map] }.include?(nil)
        message = "No clear winner, revote"
        state[:footer][:status] = message
        update_embed(state)
        run_vote(event, message)
      else
        # announce draw
        winner_maps = winners.map { |hash| hash[:map] }.compact.to_sentence
        message = "It's a draw between: #{winner_maps}"
        state[:footer][:status] = message
        update_embed(state)
        event.respond(message)
      end
    else
      winner = winners.first

      if winner[:map] == nil
        message = "New maps chosen!"
        state[:footer][:status] = message
        update_embed(state)
        run_vote(event, message)
      else
        # announce winner
        number_of_winning_votes = winner[:voters].length
        vote_s = number_of_winning_votes == 1 ? "vote" : "votes"
        message = "The winner is #{winner[:map]} with #{number_of_winning_votes} #{vote_s}"
        state[:footer][:status] = message
        update_embed(state)
        event.respond(message)
      end
    end
  end

  def footer_text(footer)
    still_to_vote = if footer[:still_to_vote].empty?
               "Everyone has voted"
             else
               "#{footer[:still_to_vote].map(&:display_name).to_sentence} still to vote"
             end

    second_s = footer[:seconds_remaining] == 1 ? "second" : "seconds"
    status = footer[:status] || "#{footer[:seconds_remaining]} #{second_s} remaining"

    new_maps_indicator = [
      NEW_MAPS_EMOJI * footer[:crosses],
      "🔳" * (footer[:new_maps_threshold] - footer[:crosses])
    ].join

    [
      still_to_vote,
      status,
      new_maps_indicator
    ].compact.join("\n")
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
