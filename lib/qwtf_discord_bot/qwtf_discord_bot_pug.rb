# frozen_string_literal: true

require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  MSG_SNIPPET_DELIMITER = ' · '

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg("You've already joined", e.channel) if pug.joined?(e.user_id)

        join_pug(e, pug)
        start_pug(pug, e) if pug.full?
      end
    end

    bot.command :status do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg('No PUG has been started. `!join` to create', e.channel) unless pug.active?

        send_msg(
          [
            "#{pug.player_slots} joined",
            "Map: #{pug.game_map}",
            pug_teams_message(pug, e).join("\n")
          ].join("\n"),
          e.channel
        )
      end
    end

    bot.command :teamsize do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg("Team size is #{pug.teamsize}", e.channel) unless args.any?

        new_teamsize = args[0].to_i
        return send_msg('Team size should be a number higher than 0', e.channel) unless new_teamsize > 0

        if new_teamsize
          pug.teamsize = new_teamsize

          send_msg(
            [
              "Team size set to #{pug.teamsize}",
              "#{pug.player_slots} joined"
            ].join(MSG_SNIPPET_DELIMITER),
            e.channel
          )

          start_pug(pug, e) if pug.full?
        else
          send_msg(
            [
              "Current team size is #{pug.teamsize}",
              "#{pug.player_slots} joined"
            ].join(MSG_SNIPPET_DELIMITER),
            e.channel
          )
        end
      end
    end

    bot.command :leave do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg(no_active_pug_message, e.channel) unless pug.active?
        return send_msg("You're not in the PUG", e.channel) unless pug.joined?(e.user_id)

        pug.leave(e.user_id)

        snippets = [
          "#{e.display_name} leaves the PUG",
          "#{pug.player_slots} remain"
        ]

        snippets << "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

        send_msg(
          snippets.join(MSG_SNIPPET_DELIMITER),
          e.channel
        )

        end_pug(pug, e.channel) if pug.empty?
      end
    end

    bot.command :kick do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg("Kick who? e.g. `!kick @#{e.display_name}`", e.channel) unless args.any?
        return send_msg(no_active_pug_message, e.channel) unless pug.active?

        args.each do |arg|
          unless arg.match(/<@!\d+>/)
            send_msg("#{arg} isn't a valid mention", e.channel)
            next
          end

          user_id = mention_to_user_id(arg)
          display_name = e.display_name_for(user_id) || arg

          unless pug.joined?(user_id)
            send_msg("#{display_name} isn't in the PUG", e.channel)
            next
          end

          pug.leave(user_id)

          snippets = [
            "#{display_name} is kicked from the PUG",
            "#{pug.player_slots} remain"
          ]

          snippets << "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

          send_msg(
            snippets.join(MSG_SNIPPET_DELIMITER),
            e.channel
          )

          break end_pug(pug, e.channel) if pug.empty?
        end
      end
    end

    bot.command :team do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg("Which team? E.G. `!team 1`", e.channel) unless args.any?

        team_no = args[0].to_i
        return send_msg("Choose a team between 0 and 4", e.channel) unless team_no.between?(0, 4)

        pug_already_full = pug.full?

        if args.count == 1
          user_id = e.user_id
          return send_msg("You're already in team #{team_no}", e.channel) if pug.team(team_no).include?(user_id)

          join_pug(e, pug) unless pug.joined?(user_id)
          pug.join_team(team_no: team_no, player_id: user_id)

          send_msg(
            [
              "#{e.display_name} joins team #{team_no}",
              "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
            ].join(MSG_SNIPPET_DELIMITER), e.channel
          )
        else
          args[1..-1].each do |mention|
            unless mention.match(/<@!\d+>/)
              send_msg("#{arg} isn't a valid mention", e.channel)
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || arg

            unless pug.joined?(user_id)
              send_msg("#{display_name} isn't in the PUG", e.channel)
              next
            end

            pug.join_team(team_no: team_no, player_id: user_id)

            send_msg(
              [
                "#{display_name} joins team #{team_no}",
                "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
              ].join(MSG_SNIPPET_DELIMITER), e.channel
            )
          end
        end

        start_pug(pug, e) if !pug_already_full && pug.full?
      end
    end

    bot.command :unteam do |event, *args|
      setup_pug(event) do |e, pug|
        user_id = e.user_id
        return send_msg('No PUG has been started. `!join` to create', e.channel) unless pug.active?
        return send_msg("You aren't in this PUG", e.channel) unless pug.joined?(user_id)
        return send_msg("You aren't in a team", e.channel) if pug.team(0).include?(user_id)

        pug.join_team(team_no: 0, player_id: user_id)
        send_msg("#{e.display_name} has no team", e.channel)
      end
    end

    bot.command :win do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg(no_active_pug_message, e.channel) unless pug.active?

        winning_team_no = args[0]

        return send_msg("Not a valid team", e.channel) unless pug.team(winning_team_no).any?

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

        # winning_team = pug.team(winning_team_no).map do |player_id|
        #   e.display_name_for(player_id)
        # end

        # non_winning_teams = pug.actual_teams.tap { |team| team.delete(winning_team_no) }

        # losing_players = non_winning_teams.values.flatten.map do |player_id|
        #   e.display_name_for(player_id)
        # end

        send_msg("Team #{winning_team_no} wins", e.channel)
      end
    end

    bot.command :draw do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg(no_active_pug_message, e.channel) unless pug.active?

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

        send_msg("Match drawn", e.channel)
      end
    end

    bot.command :end do |event, *args|
      setup_pug(event) do |e, pug|
        return send_msg(no_active_pug_message, e.channel) unless pug.active?

        end_pug(pug, e.channel)
      end
    end

    bot.command :addmap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args
        return send_msg("What map? e.g. `!addmap 2fort5r`", e.channel) unless maps.any?

        pug.add_maps(maps)
        send_msg("#{maps.join(', ')} added to maps", e.channel)
      end
    end

    bot.command :removemap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args
        return send_msg("What map? e.g. `!removemap 2fort5r`", e.channel) unless maps.any?

        pug.remove_maps(maps)
        send_msg("#{maps.join(', ')} removed from maps", e.channel)
      end
    end

    bot.command :maps do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps
        return send_msg('No maps have been added. `!addmap`', e.channel) unless maps.any?

        send_msg(maps.join(', '), e.channel)
      end
    end

    bot.command :map do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps
        return send_msg('No maps have been added. `!addmap`', e.channel) unless maps.any?
        return send_msg(no_active_pug_message, e.channel) unless pug.active?

        if args.empty?
          return send_msg('No map has been set for the current PUG', e.channel) unless pug.game_map
          send_msg("Current map is #{pug.game_map}", e.channel)
        else
          game_map = args.first
          return send_msg("#{game_map} isn't in the map list. `!addmap` to add it.", e.channel) unless maps.include?(game_map)

          pug.game_map = game_map
          send_msg("Map set to #{game_map}", e.channel)
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

        send_msg(msg, e.channel)
      end
    end

    bot.run
  end

  private

  def mention_to_user_id(mention)
    mention[3..-2].to_i
  end

  def join_pug(e, pug)
    pug.join(e.user_id)

    if pug.joined_player_count == 1
      snippets = ["#{e.display_name} creates a PUG", pug.player_slots, pug.notify_roles]
    else
      snippets = ["#{e.display_name} joins the PUG", pug.player_slots]
      snippets << "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left.between?(1, 3)
    end

    send_msg(snippets.join(MSG_SNIPPET_DELIMITER), e.channel)
  end

  def setup_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
    nil # stop discordrb printing return value
  end

  def start_pug(pug, event)
    pug_teams = pug.teams.map do |team_no, player_ids|
      team_mentions = player_ids.map do |player_id|
        event.mention_for(player_id)
      end

      team_status_line(
        team_no: team_no.to_i,
        names: team_mentions,
        teamsize: pug.teamsize
      )
    end

    msg = [
      'Time to play!',
      pug_teams
    ].join("\n")

    send_msg(msg, event.channel)
  end

  def pug_teams_message(pug, event)
    pug.teams.map do |team_no, player_ids|
      team_display_names = player_ids.map do |player_id|
        event.display_name_for(player_id)
      end

      team_status_line(
        team_no: team_no.to_i,
        names: team_display_names,
        teamsize: pug.teamsize
      )
    end
  end

  def team_status_line(team_no:, names:, teamsize:)
    if team_no.to_i.zero?
      ["No team: #{names.join(', ')}"]
    else
      [
        "Team #{team_no}: #{names.join(', ')}",
        "#{names.count}/#{teamsize}"
      ].join(MSG_SNIPPET_DELIMITER)
    end
  end

  def end_pug(pug, channel_id)
    pug.end_pug
    send_msg('PUG ended', channel_id)
  end

  def no_active_pug_message
    "There's no active PUG"
  end

  def send_msg(message, channel)
    channel.send_message(message) && puts(message)
  end

  def post_results(json)
    uri = URI("#{ENV['RATINGS_API_URL']}matches/")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = json
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
  end
end
