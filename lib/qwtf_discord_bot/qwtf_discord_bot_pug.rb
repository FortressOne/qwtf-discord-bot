# frozen_string_literal: true

require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  MSG_SNIPPET_DELIMITER = ' · '
  TEAM_NAMES = { 1 => "Blue", 2 => "Red" }

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

    bot.command :help do |event, *args|
      "Pug commands: `!status`, `!join`, `!team <team_no> [@player1] [@player2]`, `!unteam`, `!leave`, `!kick <@player>`, `!win <team_no>`, `!draw`, `!end`, `!teamsize <no_of_players>`, `!addmap <map_name>`, `!removemap <map_name>`, `!maps`, `!map [map_name]`, `!choose [n]`, `!notify <@role>`"
    end

    bot.command :join do |event, *args|
      setup_pug(event) do |e, pug|
        if pug.joined?(e.user_id)
          return send_embedded_message(
            description: "You've already joined",
            channel: e.channel
          )
        end

        join_pug(e, pug)
        start_pug(pug, e) if pug.full?
      end
    end

    bot.command :choose do |event, *args|
      setup_pug(event) do |e, pug|
        if pug.joined_players.count.odd?
          return send_embedded_message(
            description: "Can't choose teams with odd number of players",
            channel: event.channel
          )
        end

        if args.any? && args.first.to_i < 1
          return send_embedded_message(
            description: "Choose a number higher than 0; e.g. `!choose 2`",
            channel: e.channel
          )
        end

        iteration = if args.any?
                      args.first.to_i - 1
                    else
                      0
                    end

        choose_fair_teams(pug: pug, event: e, iteration: iteration)
        status(pug: pug, event: e)
      end
    end

    bot.command :status do |event, *args|
      setup_pug(event) do |e, pug|
        if !pug.active?
          return send_embedded_message(
            description: "No PUG has been started. `!join` to create",
            channel: e.channel
          )
        end

        status(pug: pug, event: e)
      end
    end

    bot.command :teamsize do |event, *args|
      setup_pug(event) do |e, pug|
        unless args.any?
          return send_embedded_message(
            description: [
              "Each team has #{pug.teamsize} players",
              "#{pug.player_slots} joined"
            ].join(MSG_SNIPPET_DELIMITER),
            channel: e.channel
          )
        end

        new_teamsize = args[0].to_i

        if new_teamsize < 1
          return send_embedded_message(
            description: "Team size should be 1 or more",
            channel: e.channel
          )
        end

        pug.teamsize = new_teamsize

        send_embedded_message(
          description: [
            "Each team has #{pug.teamsize} players",
            "#{pug.player_slots} joined"
          ].join(MSG_SNIPPET_DELIMITER),
          channel: e.channel
        )

        start_pug(pug, e) if pug.full?
      end
    end

    bot.command :leave do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        unless pug.joined?(e.user_id)
          return send_embedded_message(
            description: "You're not in the PUG",
            channel: e.channel
          )
        end

        pug.leave(e.user_id)

        snippets = [
          "#{e.display_name} leaves the PUG",
          "#{pug.player_slots} remain"
        ]

        message = "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

        send_embedded_message(
          message: message,
          description: snippets.join(MSG_SNIPPET_DELIMITER),
          channel: e.channel
        )

        end_pug(pug, e.channel) if pug.empty?
      end
    end

    bot.command :kick do |event, *args|
      setup_pug(event) do |e, pug|
        unless args.any?
          return send_embedded_message(
            description: "Kick who? e.g. `!kick @#{e.display_name}`",
            channel: e.channel
          )
        end

        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        args.each do |arg|
          unless arg.match(/<@!\d+>/)
            send_embedded_message(
              description: "#{arg} isn't a valid mention",
              channel: e.channel
            )
            next
          end

          user_id = mention_to_user_id(arg)
          display_name = e.display_name_for(user_id) || arg

          unless pug.joined?(user_id)
            send_embedded_message(
              description: "#{display_name} isn't in the PUG",
              channel: e.channel
            )
            next
          end

          pug.leave(user_id)

          snippets = [
            "#{display_name} is kicked from the PUG",
            "#{pug.player_slots} remain"
          ]

          message = "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

          send_embedded_message(
            message: message,
            description: snippets.join(MSG_SNIPPET_DELIMITER),
            channel: e.channel
          )

          break end_pug(pug, e.channel) if pug.empty?
        end
      end
    end

    bot.command :team do |event, *args|
      setup_pug(event) do |e, pug|
        unless args.any?
          return send_embedded_message(
            description: "Which team? E.G. `!team 1`",
            channel: e.channel
          )
        end

        unless ["1", "2"].any?(args.first)
          return send_embedded_message(
            description: "Choose `!team 1`, `!team 2`, or `!unteam` to leave team",
            channel: e.channel
          )
        end

        team_no = args.first.to_i
        pug_already_full = pug.full?

        if args.count == 1
          user_id = e.user_id

          if pug.team(team_no).include?(user_id)
            return send_embedded_message(
              description: "You're already in #{TEAM_NAMES[team_no]}",
              channel: e.channel
            )
          end

          join_pug(e, pug) unless pug.joined?(user_id)
          pug.join_team(team_no: team_no, player_id: user_id)

          send_embedded_message(
            description: [
              "#{e.display_name} joins #{TEAM_NAMES[team_no]}",
              "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
            ].join(MSG_SNIPPET_DELIMITER),
            channel: e.channel
          )
        else
          args[1..-1].each do |mention|
            unless mention.match(/<@!\d+>/)
              send_embedded_message(
                description: "#{arg} isn't a valid mention",
                channel: e.channel
              )
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || arg

            unless pug.joined?(user_id)
              send_embedded_message(
                description: "#{display_name} isn't in the PUG",
                channel: e.channel
              )
              next
            end

            pug.join_team(team_no: team_no, player_id: user_id)

            send_embedded_message(
              description: [
                "#{display_name} joins #{TEAM_NAMES[team_no]}",
                "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
              ].join(MSG_SNIPPET_DELIMITER),
              channel: e.channel
            )
          end
        end

        start_pug(pug, e) if !pug_already_full && pug.full?
      end
    end

    bot.command :unteam do |event, *args|
      setup_pug(event) do |e, pug|
        user_id = e.user_id

        unless pug.active?
          return send_embedded_message(
            description: 'No PUG has been started. `!join` to create',
            channel: e.channel
          )
        end

        unless pug.joined?(user_id)
          return send_embedded_message(
            description: "You aren't in this PUG",
            channel: e.channel
          )
        end

        if pug.team(0).include?(user_id)
          return send_embedded_message(
            description: "You aren't in a team",
            channel: e.channel
          )
        end

        pug.join_team(team_no: 0, player_id: user_id)

        send_embedded_message(
          description: "#{e.display_name} leaves team",
          channel: e.channel
        )
      end
    end

    bot.command :win do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        unless args.any?
          return send_embedded_message(
            description: "Specify winning team; e.g. `!win 1`",
            channel: e.channel
          )
        end

        unless ["1", "2"].any?(args.first)
          return send_embedded_message(
            description: "Invalid team number",
            channel: e.channel
          )
        end

        winning_team_no = args.first.to_i

        if pug.actual_teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        team_results = pug.actual_teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

          result = winning_team_no.to_i == name.to_i ? 1 : -1
          teams.merge({ name => { players: players, result: result } })
        end

        post_results(
          {
            match: {
              map: pug.game_map,
              teams: team_results,
              discord_channel: {
                channel_id: e.channel_id,
                name: "#{e.channel.server.name} ##{e.channel.name}"
              }
            }
          }.to_json
        )

        send_embedded_message(
          description: "#{TEAM_NAMES[winning_team_no]} wins. [Ratings](http://ratings.fortressone.org)",
          channel: e.channel
        )
      end
    end

    bot.command :draw do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if pug.actual_teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        team_results = pug.actual_teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

        teams.merge({ name => { players: players, result: 0 } })
        end

        post_results(
          {
            match: {
              map: pug.game_map,
              teams: team_results,
              discord_channel: {
                channel_id: e.channel_id,
                name: "#{e.channel.server.name} ##{e.channel.name}"
              }
            }
          }.to_json
        )

        send_embedded_message(
          description: "Match drawn. [Ratings](http://ratings.fortressone.org)",
          channel: e.channel
        )
      end
    end

    bot.command :end do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        end_pug(pug, e.channel)
      end
    end

    bot.command :addmap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args

        unless maps.any?
          return send_embedded_message(
            description: "What map? e.g. `!addmap 2fort5r`",
            channel: e.channel
          )
        end

        pug.add_maps(maps)

        send_embedded_message(
          description: "#{maps.join(', ')} added to maps",
          channel: e.channel)
      end
    end

    bot.command :removemap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args

        unless maps.any?
          return send_embedded_message(
            description: "What map? e.g. `!removemap 2fort5r`",
            channel: e.channel
          )
        end

        pug.remove_maps(maps)

        send_embedded_message(
          description: "#{maps.join(', ')} removed from maps",
          channel: e.channel
        )
      end
    end

    bot.command :maps do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps
        unless maps.any?
          return send_embedded_message(
            description: 'No maps have been added. `!addmap`',
            channel: e.channel
          )
        end

        send_embedded_message(
          description: maps.join(', '),
          channel: e.channel
        )
      end
    end

    bot.command :map do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps

        unless maps.any?
          return send_embedded_message(
            description: 'No maps have been added. `!addmap`',
            channel: e.channel
          )
        end

        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if args.empty?
          unless pug.game_map
            return send_embedded_message(
              description: 'No map has been set for the current PUG',
              channel: e.channel
            )
          end

          send_embedded_message(
            description: "Current map is #{pug.game_map}",
            channel: e.channel
          )
        else
          game_map = args.first

          unless maps.include?(game_map)
            return send_embedded_message(
              description: "#{game_map} isn't in the map list. `!addmap` to add it.",
              channel: e.channel
            )
          end

          pug.game_map = game_map

          send_embedded_message(
            description: "Map set to #{game_map}",
            channel: e.channel
          )
        end
      end
    end

    bot.command :notify do |event, *args|
      setup_pug(event) do |e, pug|
        roles = args.join(' ')
        pug.notify_roles = roles

        msg = if roles.empty?
                'Notification removed'
              else
                "Notification role set to #{roles}"
              end

        send_embedded_message(
          description: msg,
          channel: e.channel
        )
      end
    end

    bot.run
  end

  private

  def team_name(team_no)
    return "No team" if team_no == 0

    [team_no, TEAM_NAMES[team_no]].join(" ")
  end

  def mention_to_user_id(mention)
    mention[3..-2].to_i
  end

  def join_pug(e, pug)
    pug.join(e.user_id)

    if pug.joined_player_count == 1
      snippets = ["#{e.display_name} creates a PUG", "#{pug.player_slots} joined"]
      message = pug.notify_roles
    else
      snippets = ["#{e.display_name} joins the PUG", "#{pug.player_slots} joined"]
      message = "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left.between?(1, 3)
    end

    send_embedded_message(
      message: message,
      description: snippets.join(MSG_SNIPPET_DELIMITER),
      channel: e.channel
    )
  end

  def setup_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
    nil # stop discordrb printing return value
  end

  def choose_fair_teams(pug:, event:, iteration: 0)
    if !pug.full?
      return send_embedded_message(
        description: "Can't choose teams until PUG is full",
        channel: e.channel
      )
    end

    send_embedded_message(
      description: "Choosing fair teams...",
      channel: event.channel
    )

    combinations = get_fair_teams(pug.joined_players)
    teams = combinations[iteration]

    if !teams
      return send_embedded_message(
        description: "There are only #{combinations.count} possible combinations",
        channel: event.channel
      )
    end

    teams.each do |team_no, player_ids|
      player_ids.each do |player_id|
        pug.join_team(team_no: team_no, player_id: player_id)
      end
    end
  end

  def status(pug:, event:)
    footer = [
      pug.game_map,
      "#{pug.player_slots} joined"
    ].compact.join(MSG_SNIPPET_DELIMITER)

    send_embedded_message(
      description: nil,
      channel: event.channel
    ) do |embed|
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: footer
      )

      pug.teams.each do |team_no, player_ids|
        team_display_names = player_ids.map do |player_id|
          event.display_name_for(player_id)
        end

        embed.add_field(
          Discordrb::Webhooks::EmbedField.new(
            {
              inline: true,
              name: team_name(team_no),
              value: team_display_names.join("\n")
            }
          )
        )
      end
    end
  end

  def start_pug(pug, event)
    choose_fair_teams(pug: pug, event: event) unless pug.actual_teams.any?

    footer = [
      pug.game_map,
      "#{pug.player_slots} joined",
    ].compact.join(MSG_SNIPPET_DELIMITER)

    mentions = pug.joined_players.map do |player_id|
      event.mention_for(player_id)
    end

    mention_line = "Time to play! #{mentions.join(" ")}"

    send_embedded_message(
      message: mention_line,
      channel: event.channel
    ) do |embed|
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: footer
      )

      pug.teams.each do |team_no, player_ids|
        team_mentions = player_ids.map do |player_id|
          event.display_name_for(player_id)
        end

        embed.add_field(
          Discordrb::Webhooks::EmbedField.new(
            {
              inline: true,
              name: team_name(team_no),
              value: team_mentions.join("\n")
            }
          )
        )
      end
    end
  end

  def end_pug(pug, channel_id)
    pug.end_pug

    send_embedded_message(
      description: 'PUG ended',
      channel: channel_id
    )
  end

  def no_active_pug_message
    "There's no active PUG"
  end

  def send_embedded_message(message: nil, description: nil, channel:)
    embed = Discordrb::Webhooks::Embed.new
    embed.description = description
    yield(embed) if block_given?
    channel.send_embed(message, embed) && puts(message)
  end

  def post_results(json)
    uri = URI("#{ENV['RATINGS_API_URL']}matches/")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = json

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
  end

  def get_fair_teams(players)
    uri = URI("#{ENV['RATINGS_API_URL']}fair_teams/new")
    params = { 'players[]' => players }
    uri.query = URI.encode_www_form(params)
    req = Net::HTTP::Get.new(uri)

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    JSON.parse(res.body).map(&:to_h)
  end
end
