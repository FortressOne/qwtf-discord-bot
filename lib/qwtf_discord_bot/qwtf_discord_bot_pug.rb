# frozen_string_literal: true

require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  MSG_SNIPPET_DELIMITER = ' · '
  TEAM_NAMES = { 0 => "No team", 1 => "Blue", 2 => "Red" }

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
      "Pug commands: `!status`, `!join`, `!team <team_no>`, `!unteam`, `!leave`, `!kick <@player>`, `!win <team_no>`, `!draw`, `!end`, `!teamsize <no_of_players>`, `!addmap <map_name>`, `!removemap <map_name>`, `!maps`, `!map <map_name>`, `!notify <@role>`"
    end

    bot.command :join do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message("You've already joined", e.channel) if pug.joined?(e.user_id)

        join_pug(e, pug)
        start_pug(pug, e) if pug.full?
      end
    end

    bot.command :status do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message('No PUG has been started. `!join` to create', e.channel) unless pug.active?

        message = [
          "#{pug.player_slots} joined",
          "Map: #{pug.game_map}",
        ].join(MSG_SNIPPET_DELIMITER),

        send_embedded_message(message, e.channel) do |embed|
          pug.teams.each do |team_no, player_ids|
            team_display_names = player_ids.map do |player_id|
              e.display_name_for(player_id)
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
    end

    bot.command :teamsize do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message("Team size is #{pug.teamsize}", e.channel) unless args.any?

        new_teamsize = args[0].to_i
        return send_embedded_message('Team size should be a number higher than 0', e.channel) unless new_teamsize > 0

        if new_teamsize
          pug.teamsize = new_teamsize

          send_embedded_message(
            [
              "Team size set to #{pug.teamsize}",
              "#{pug.player_slots} joined"
            ].join(MSG_SNIPPET_DELIMITER),
            e.channel
          )

          start_pug(pug, e) if pug.full?
        else
          send_embedded_message(
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
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?
        return send_embedded_message("You're not in the PUG", e.channel) unless pug.joined?(e.user_id)

        pug.leave(e.user_id)

        snippets = [
          "#{e.display_name} leaves the PUG",
          "#{pug.player_slots} remain"
        ]

        snippets << "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

        send_embedded_message(
          snippets.join(MSG_SNIPPET_DELIMITER),
          e.channel
        )

        end_pug(pug, e.channel) if pug.empty?
      end
    end

    bot.command :kick do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message("Kick who? e.g. `!kick @#{e.display_name}`", e.channel) unless args.any?
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?

        args.each do |arg|
          unless arg.match(/<@!\d+>/)
            send_embedded_message("#{arg} isn't a valid mention", e.channel)
            next
          end

          user_id = mention_to_user_id(arg)
          display_name = e.display_name_for(user_id) || arg

          unless pug.joined?(user_id)
            send_embedded_message("#{display_name} isn't in the PUG", e.channel)
            next
          end

          pug.leave(user_id)

          snippets = [
            "#{display_name} is kicked from the PUG",
            "#{pug.player_slots} remain"
          ]

          snippets << "#{pug.slots_left} more #{pug.notify_roles}" if pug.slots_left == 1

          send_embedded_message(
            snippets.join(MSG_SNIPPET_DELIMITER),
            e.channel
          )

          break end_pug(pug, e.channel) if pug.empty?
        end
      end
    end

    bot.command :team do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message("Which team? E.G. `!team 1`", e.channel) unless args.any?
        return send_embedded_message("Choose a team between 0 and 2", e.channel) unless ["0", "1", "2"].any?(args.first)

        team_no = args.first.to_i
        pug_already_full = pug.full?

        if args.count == 1
          user_id = e.user_id
          return send_embedded_message("You're already in #{team_name(team_no)}", e.channel) if pug.team(team_no).include?(user_id)

          join_pug(e, pug) unless pug.joined?(user_id)
          pug.join_team(team_no: team_no, player_id: user_id)

          send_embedded_message(
            [
              "#{e.display_name} joins #{team_name(team_no)}",
              "#{pug.team_player_count(team_no)}/#{pug.teamsize}"
            ].join(MSG_SNIPPET_DELIMITER), e.channel
          )
        else
          args[1..-1].each do |mention|
            unless mention.match(/<@!\d+>/)
              send_embedded_message("#{arg} isn't a valid mention", e.channel)
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || arg

            unless pug.joined?(user_id)
              send_embedded_message("#{display_name} isn't in the PUG", e.channel)
              next
            end

            pug.join_team(team_no: team_no, player_id: user_id)

            send_embedded_message(
              [
                "#{display_name} joins #{team_name(team_no)}",
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
        return send_embedded_message('No PUG has been started. `!join` to create', e.channel) unless pug.active?
        return send_embedded_message("You aren't in this PUG", e.channel) unless pug.joined?(user_id)
        return send_embedded_message("You aren't in a team", e.channel) if pug.team(0).include?(user_id)

        pug.join_team(team_no: 0, player_id: user_id)
        send_embedded_message("#{e.display_name} has no team", e.channel)
      end
    end

    bot.command :win do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?
        return send_embedded_message("Specify winning team; e.g. `!win 1`", e.channel) unless args.any?
        return send_embedded_message("Invalid team number", e.channel) unless ["1", "2"].any?(args.first)

        winning_team_no = args.first.to_i

        if pug.actual_teams.count < 2
          return send_embedded_message(
            "There must be at least two teams with players to submit a result", e.channel
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

        send_embedded_message("#{TEAM_NAMES[winning_team_no]} team wins. [Ratings](http://ratings.fortressone.org)", e.channel)
      end
    end

    bot.command :draw do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?

        if pug.actual_teams.count < 2
          return send_embedded_message(
            "There must be at least two teams with players to submit a result", e.channel
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

        send_embedded_message("Match drawn. [Ratings](http://ratings.fortressone.org)", e.channel)
      end
    end

    bot.command :end do |event, *args|
      setup_pug(event) do |e, pug|
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?

        end_pug(pug, e.channel)
      end
    end

    bot.command :addmap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args
        return send_embedded_message("What map? e.g. `!addmap 2fort5r`", e.channel) unless maps.any?

        pug.add_maps(maps)
        send_embedded_message("#{maps.join(', ')} added to maps", e.channel)
      end
    end

    bot.command :removemap do |event, *args|
      setup_pug(event) do |e, pug|
        maps = args
        return send_embedded_message("What map? e.g. `!removemap 2fort5r`", e.channel) unless maps.any?

        pug.remove_maps(maps)
        send_embedded_message("#{maps.join(', ')} removed from maps", e.channel)
      end
    end

    bot.command :maps do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps
        return send_embedded_message('No maps have been added. `!addmap`', e.channel) unless maps.any?

        send_embedded_message(maps.join(', '), e.channel)
      end
    end

    bot.command :map do |event, *args|
      setup_pug(event) do |e, pug|
        maps = pug.maps
        return send_embedded_message('No maps have been added. `!addmap`', e.channel) unless maps.any?
        return send_embedded_message(no_active_pug_message, e.channel) unless pug.active?

        if args.empty?
          return send_embedded_message('No map has been set for the current PUG', e.channel) unless pug.game_map
          send_embedded_message("Current map is #{pug.game_map}", e.channel)
        else
          game_map = args.first
          return send_embedded_message("#{game_map} isn't in the map list. `!addmap` to add it.", e.channel) unless maps.include?(game_map)

          pug.game_map = game_map
          send_embedded_message("Map set to #{game_map}", e.channel)
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

        send_embedded_message(msg, e.channel)
      end
    end

    bot.run
  end

  private

  def team_name(team_no)
    [team_no, TEAM_NAMES[team_no]].join(MSG_SNIPPET_DELIMITER)
  end

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

    send_embedded_message(snippets.join(MSG_SNIPPET_DELIMITER), e.channel)
  end

  def setup_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
    nil # stop discordrb printing return value
  end

  def start_pug(pug, event)
    if !pug.actual_teams.any?
      teams = get_fair_teams(pug.joined_players)

      teams.each do |team_no, player_ids|
        player_ids.each do |player_id|
          pug.join_team(team_no: team_no, player_id: player_id)
        end
      end
    end

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

    send_embedded_message(msg, event.channel)
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
    [
      "#{TEAM_NAMES[team_no]}: #{names.join(', ')}",
      "#{names.count}/#{teamsize}"
    ].join(MSG_SNIPPET_DELIMITER)
  end

  def end_pug(pug, channel_id)
    pug.end_pug
    send_embedded_message('PUG ended', channel_id)
  end

  def no_active_pug_message
    "There's no active PUG"
  end

  def send_embedded_message(message, channel)
    embed = Discordrb::Webhooks::Embed.new
    embed.description = message
    yield(embed) if block_given?
    channel.send_embed(nil, embed) && puts(message)
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
    JSON.parse(res.body).first.to_h
  end
end
