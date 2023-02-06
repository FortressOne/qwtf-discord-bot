# frozen_string_literal: true

require 'pug'
require 'event_decorator'
require 'active_support/core_ext/array/conversions'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  MSG_SNIPPET_DELIMITER = ' · '
  TEAM_NAMES = { 1 => "Blue", 2 => "Red" }
  TEN_MINUTES = 10 * 60
  VALID_MENTION = /<@!?\d+>/

  COMMANDS = <<~MESSAGE
    `!status` Shows who has joined
    `!join [@player1] [@player2]` Join PUG. Can also join other players
    `!leave` Leave PUG
    `!kick <@player> [@player2]` Kick one or more other players
    `!team <team_no> [@player1] [@player2]` Join team
    `!unteam [@player1] [@player2]` Leave team and go to front of queue
    `!choose [n]` Choose fair teams. Pass number for nth fairest team
    `!shuffle` Choose random teams.
    `!win <team_no>` Report winning team
    `!draw` Report draw
    `!end` End PUG. Kicks all players
    `!teamsize <no_of_players>` Set number of players in a team
    `!addmap <map_name>` Add map to map list
    `!removemap <map_name>` Remove map from map list
    `!maps` Show map list
    `!map [map_name]` Show or set map
    `!notify <@role>` Set @role for alerts
  MESSAGE

  HELP = { commands: COMMANDS, footer: "!command <required> [optional]" }

  def run
    @bot = Discordrb::Commands::CommandBot.new(
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

    @bot.command :help do |event, *args|
      send_embedded_message(
        description: HELP[:commands],
        channel: event.channel
      ) do |embed|
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: HELP[:footer]
        )
      end
    end

    @bot.command :join do |event, *args|
      setup_pug(event) do |e, pug|
        if args.empty?
          if pug.joined?(e.user_id)
            return send_embedded_message(
              description: "You've already joined",
              channel: e.channel
            )
          end

          e.user.add_role(ENV['READY_ROLE'])
          join_pug(e, pug)
        else
          errors = []
          joiners = []

          args.each do |mention|
            if !mention.match(VALID_MENTION)
              errors << "#{mention} isn't a valid mention"
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || mention

            if pug.joined?(user_id)
              errors << "#{display_name} is already in this PUG"
              next
            end

            e.find_user(user_id).add_role(ENV['READY_ROLE'])
            pug.join(user_id)
            joiners << display_name
          end

          message = ""
          description = []

          if pug.total_player_count == 0
            message = "#{pug.notify_roles} PUG started"
            description << "#{e.display_name} creates a PUG"
          elsif pug.slots_left.between?(1, 3)
            message = "#{pug.slots_left} more #{pug.notify_roles}"
          end

          if joiners.any?
            description << [
              joiners.to_sentence,
              joiners.count == 1 ? "joins" : "join",
              "the PUG"
            ].join(" ")
          end

          description << [
            pug.total_player_count,
            pug.maxplayers
          ].join("/")

          send_embedded_message(
            message: message,
            description: [errors, description.join(MSG_SNIPPET_DELIMITER)].join("\n"),
            channel: e.channel
          )
        end

        start_pug(pug, e) if pug.has_exactly_maxplayers?
      end
    end

    @bot.command :choose do |event, *args|
      setup_pug(event) do |e, pug|
        if !pug.full?
          return send_embedded_message(
            description: "Not enough players, reduce !teamsize",
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

        message_obj = choose_teams(pug: pug, event: e, iteration: iteration)
        status(pug: pug, event: e, message_obj: message_obj) if message_obj
      end
    end

    @bot.command :shuffle do |event|
      setup_pug(event) do |e, pug|
        if !pug.full?
          return send_embedded_message(
            description: "Not enough players, reduce !teamsize",
            channel: event.channel
          )
        end

        message_obj = choose_teams(pug: pug, event: e)
        status(pug: pug, event: e, message_obj: message_obj) if message_obj
      end
    end

    @bot.command :status do |event, *args|
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

    @bot.command :teamsize do |event, *args|
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

    @bot.command :leave do |event, *args|
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

        e.user.remove_role(ENV['READY_ROLE'])
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

        end_pug(pug, e) if pug.empty?
      end
    end

    @bot.command :kick do |event, *args|
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

        errors = []
        kickees = []

        args.each do |mention|
          if !mention.match(VALID_MENTION)
            errors << "#{mention} isn't a valid mention"
            next
          end

          user_id = mention_to_user_id(mention)
          display_name = e.display_name_for(user_id) || mention

          unless pug.joined?(user_id)
            errors << "#{display_name} isn't in the PUG"
            next
          end

          e.find_user(user_id).remove_role(ENV['READY_ROLE'])
          pug.leave(user_id)

          kickees << display_name
        end

        message = ""
        description = []

        if pug.slots_left == 1
          message = "#{pug.slots_left} more #{pug.notify_roles}"
        end

        if kickees.any?
          description << [
            kickees.to_sentence,
            kickees.count == 1 ? "is" : "are",
            "kicked from the PUG"
          ].join(" ")
        end

        description << [
          [pug.total_player_count, pug.maxplayers].join("/"),
          "remain"
        ].join(" ")

        description = [errors, description.join(MSG_SNIPPET_DELIMITER)].join("\n")

        send_embedded_message(
          message: message,
          description: description,
          channel: e.channel
        )

        end_pug(pug, e) if pug.empty?
      end
    end

    @bot.command :team do |event, *args|
      setup_pug(event) do |e, pug|
        if args.empty?
          return send_embedded_message(
            description: "Which team? E.G. `!team 1`",
            channel: e.channel
          )
        end

        if ["1", "2"].none?(args.first)
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

          pug.join_team(team_no: team_no, player_id: user_id)

          send_embedded_message(
            description: [
              "#{e.display_name} joins #{TEAM_NAMES[team_no]}",
              "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
            ].join(MSG_SNIPPET_DELIMITER),
            channel: e.channel
          )
        else
          errors = []
          teamers = []

          args[1..-1].each do |mention|
            if !mention.match(VALID_MENTION)
              errors << "#{mention} isn't a valid mention"
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || mention
            pug.join_team(team_no: team_no, player_id: user_id)

            teamers << display_name
          end

          description = errors << [
            [
              teamers.to_sentence,
              teamers.count == 1 ? "joins" : "join",
              TEAM_NAMES[team_no]
            ].join(" "),
            [
              pug.team_player_count(team_no),
              pug.teamsize
            ].join("/")
          ].join(MSG_SNIPPET_DELIMITER)

          send_embedded_message(
            description: description.join("\n"),
            channel: e.channel
          )
        end

        start_pug(pug, e) if !pug_already_full && pug.has_exactly_maxplayers?
      end
    end

    @bot.command :unteam do |event, *args|
      setup_pug(event) do |e, pug|
        user_id = e.user_id

        if !pug.active?
          return send_embedded_message(
            description: 'No PUG has been started. `!join` to create',
            channel: e.channel
          )
        end

        if args.empty?
          if !pug.joined?(user_id)
            return send_embedded_message(
              description: "You aren't in this PUG",
              channel: e.channel
            )
          end

          if !pug.teamed_players.include?(user_id)
            return send_embedded_message(
              description: "You aren't in a team",
              channel: e.channel
            )
          end

          pug.unteam(user_id)

          send_embedded_message(
            description: "#{e.display_name} leaves team",
            channel: e.channel
          )
        else
          errors = []
          unteamers = []

          args.each do |mention|
            if !mention.match(VALID_MENTION)
              errors << "#{mention} isn't a valid mention"
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || mention

            if !pug.joined?(user_id)
              errors << "#{display_name} isn't in this PUG"
              next
            end

            pug.unteam(user_id)

            unteamers << display_name
          end

          description = errors << [
            unteamers.to_sentence,
            unteamers.count == 1 ? "goes" : "go",
            "into the queue"
          ].join(" ")

          send_embedded_message(
            description: description.join("\n"),
            channel: e.channel
          )
        end
      end
    end

    @bot.command :win do |event, *args|
      setup_pug(event) do |e, pug|
        unless args.any?
          return send_embedded_message(
            description: "Specify winning team; e.g. `!win 1`",
            channel: e.channel
          )
        end

        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if !pug.full?
          return send_embedded_message(
            description: "Can't report unless PUG is full",
            channel: event.channel
          )
        end

        if !pug.equal_number_of_players_on_each_team?
          return send_embedded_message(
            description: "Can't report unless teams have same number of players",
            channel: event.channel
          )
        end

        unless ["1", "2"].any?(args.first)
          return send_embedded_message(
            description: "Invalid team number",
            channel: e.channel
          )
        end

        if pug.last_result_time && pug.last_result_time > ten_minutes_ago
          return send_embedded_message(
            description: "A match was reported less than 10 minutes ago",
            channel: event.channel
          )
        end

        winning_team_no = args.first.to_i

        if pug.teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        team_results = pug.teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

          result = winning_team_no.to_i == name.to_i ? 1 : -1
          teams.merge({ name => { players: players, result: result } })
        end

        id = report(
          pug,
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
        ).body

        send_embedded_message(
          description: "#{TEAM_NAMES[winning_team_no]} wins game ##{id}. `!choose` again. [Results](#{discord_channel_leaderboard_url(e.channel.id)})",
          channel: e.channel
        )
      end
    end

    # exactly the same as !win but allows consecutive reports
    @bot.command :forcewin do |event, *args|
      setup_pug(event) do |e, pug|
        unless args.any?
          return send_embedded_message(
            description: "Specify winning team; e.g. `!win 1`",
            channel: e.channel
          )
        end

        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if !pug.full?
          return send_embedded_message(
            description: "Can't report unless PUG is full",
            channel: event.channel
          )
        end

        if !pug.equal_number_of_players_on_each_team?
          return send_embedded_message(
            description: "Can't report unless teams have same number of players",
            channel: event.channel
          )
        end

        unless ["1", "2"].any?(args.first)
          return send_embedded_message(
            description: "Invalid team number",
            channel: e.channel
          )
        end

        winning_team_no = args.first.to_i

        if pug.teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        team_results = pug.teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

          result = winning_team_no.to_i == name.to_i ? 1 : -1
          teams.merge({ name => { players: players, result: result } })
        end

        id = report(
          pug,
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
        ).body

        send_embedded_message(
          description: "#{TEAM_NAMES[winning_team_no]} wins game ##{id}. `!choose` again. [Results](#{discord_channel_leaderboard_url(e.channel.id)})",
          channel: e.channel
        )
      end
    end

    @bot.command :draw do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if !pug.full?
          return send_embedded_message(
            description: "Can't report unless PUG is full",
            channel: event.channel
          )
        end

        if !pug.equal_number_of_players_on_each_team?
          return send_embedded_message(
            description: "Can't report unless teams have same number of players",
            channel: event.channel
          )
        end

        if pug.teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        if pug.last_result_time && pug.last_result_time > ten_minutes_ago
          time_ago = Time.now.to_i - pug.last_result_time

          return send_embedded_message(
            description: "A match was reported less than 10 minutes ago",
            channel: event.channel
          )
        end

        team_results = pug.teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

        teams.merge({ name => { players: players, result: 0 } })
        end

        id = report(
          pug,
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
        ).body

        send_embedded_message(
          description: "Match ##{id} drawn. `!choose` again. [Results](#{discord_channel_leaderboard_url(e.channel.id)})",
          channel: e.channel
        )
      end
    end

    # exactly the same as !draw but allows consecutive reports
    @bot.command :forcedraw do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        if !pug.full?
          return send_embedded_message(
            description: "Can't report unless PUG is full",
            channel: event.channel
          )
        end

        if !pug.equal_number_of_players_on_each_team?
          return send_embedded_message(
            description: "Can't report unless teams have same number of players",
            channel: event.channel
          )
        end

        if pug.teams.count < 2
          return send_embedded_message(
            description: "There must be at least two teams with players to submit a result",
            channel: e.channel
          )
        end

        team_results = pug.teams.inject({}) do |teams, (name, player_ids)|
          players = player_ids.inject({}) do |memo, id|
            memo.merge({ id => e.display_name_for(id) })
          end

        teams.merge({ name => { players: players, result: 0 } })
        end

        id = report(
          pug,
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
        ).body

        send_embedded_message(
          description: "Match ##{id} drawn. `!choose` again. [Results](#{discord_channel_leaderboard_url(e.channel.id)})",
          channel: e.channel
        )
      end
    end

    @bot.command :end do |event, *args|
      setup_pug(event) do |e, pug|
        unless pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        end_pug(pug, e)
      end
    end

    @bot.command :addmap do |event, *args|
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

    @bot.command :removemap do |event, *args|
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

    @bot.command :maps do |event, *args|
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

    @bot.command :map do |event, *args|
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

    @bot.command :notify do |event, *args|
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

    @bot.run
  end

  private

  def team_name(team_no)
    return "Queue" if team_no == 0

    [team_no, TEAM_NAMES[team_no]].join(" ")
  end

  def mention_to_user_id(mention)
    mention[/\d+/].to_i
  end

  def join_pug(e, pug)
    e.user.add_role(ENV['READY_ROLE'])
    pug.join(e.user_id)

    if pug.total_player_count == 1
      snippets = ["#{e.display_name} creates a PUG", "#{pug.player_slots} joined"]
      message = "#{pug.notify_roles} PUG started"
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

  def choose_teams(pug:, event:, iteration: nil)
    if !pug.full?
      return send_embedded_message(
        description: "Not enough players, reduce !teamsize",
        channel: event.channel
      ) && nil
    end

    message_obj = send_embedded_message(
      description: "Choosing teams...",
      channel: event.channel
    )

    combinations = get_fair_teams(
      channel_id: event.channel.id, players: pug.up_now_players
    )

    if iteration
      teams = combinations[iteration]

      if !teams
        return send_embedded_message(
          description: "There are only #{combinations.count} possible combinations",
          channel: event.channel,
          message_obj: message_obj
        ) && nil
      end
    else
      weighted_combinations = combinations.map.with_index do |combination, index|
        { weight: 1/(index+1.0), combination: combination }
      end

      total = weighted_combinations.inject(0) do |sum, wt|
        sum + wt[:weight]
      end

      chosen_weighted_team_index = rand(0..total)
      counter = 0.0

      weighted_combination = weighted_combinations.find do |wt|
        counter += wt[:weight]
        chosen_weighted_team_index <= counter
      end

      teams = weighted_combination[:combination]
    end

    pug.destroy_teams

    teams.each do |team_no, player_ids|
      player_ids.each do |player_id|
        pug.join_team(team_no: team_no, player_id: player_id)
      end
    end

    message_obj
  end

  def status(pug:, event:, message_obj: nil)
    footer = [
      pug.game_map || "No map selected",
      "#{pug.player_slots} joined",
    ].compact.join(MSG_SNIPPET_DELIMITER)

    send_embedded_message(
      description: nil,
      channel: event.channel,
      message_obj: message_obj
    ) do |embed|
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: footer
      )

      if pug.queued_players.any?
        queue_display_names = pug.queued_players.map do |player_id|
          event.display_name_for(player_id)
        end

        embed.add_field(
          inline: true,
          name: "Queue",
          value: queue_display_names.join("\n")
        )
      end

      pug.teams.each do |team_no, player_ids|
        team_display_names = player_ids.map do |player_id|
          event.display_name_for(player_id)
        end

        embed.add_field(
          inline: true,
          name: team_name(team_no),
          value: team_display_names.join("\n")
        )
      end
    end
  end

  def start_pug(pug, event)
    mentions = pug.players.map do |player_id|
      event.mention_for(player_id)
    end

    mention_line = mentions.join(" ")

    send_embedded_message(
      message: mention_line,
      channel: event.channel,
      description: "Time to play. `!choose`, `!shuffle` or `!team` up."
    )
  end

  def end_pug(pug, event)
    channel_id = event.channel_id

    event.find_users(pug.players).map do |player|
      player.remove_role(ENV['READY_ROLE'])
    end

    pug.end_pug

    send_embedded_message(
      description: 'PUG ended',
      channel: channel_id
    )
  end

  def no_active_pug_message
    "There's no active PUG"
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

  def report(pug, json)
    pug.update_last_result_time
    post_results(json)
  end

  def post_results(json)
    uri = URI([ENV['RESULTS_API_URL'], 'matches'].join('/'))
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = json

    is_https = uri.scheme == "https"

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
      http.request(req)
    end
  end

  def get_fair_teams(channel_id:, players:)
    uri = URI([ENV['RESULTS_API_URL'], 'fair_teams', 'new'].join('/'))
    params = { :channel_id => channel_id, 'players[]' => players }
    uri.query = URI.encode_www_form(params)
    req = Net::HTTP::Get.new(uri)

    is_https = uri.scheme == "https"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: is_https) do |http|
      http.request(req)
    end

    JSON.parse(res.body).map(&:to_h)
  end

  def ten_minutes_ago
    Time.now.to_i - TEN_MINUTES
  end

  def discord_channel_leaderboard_url(channel_id)
    [ENV['RESULTS_APP_URL'], "discord_channels", channel_id].join('/')
  end
end
