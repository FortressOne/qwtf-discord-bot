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
    `!queue <@player> [@player2]` Move to back of queue
    `!team <team_no> [@player1] [@player2]` Join team
    `!unteam [@player1] [@player2]` Leave team and go to front of queue
    `!choose` Choose a bit fair a bit random teams.
    `!choose [n]` Choose fair teams. Pass number for nth fairest team
    `!end` End PUG. Kicks all players
    `!teamsize <no_of_players>` Set number of players in a team
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

    @bot.command :join, aliases: [:tpg, :juan] do |event, *args|
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
            message = "#{e.notify_roles} PUG started"
            description << "#{e.display_name} creates a PUG"
          elsif pug.slots_left.between?(1, 3)
            message = "#{pug.slots_left} more #{e.notify_roles}"
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

    @bot.command :leave, aliases: [:ntpg] do |event, *args|
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

        message = "#{pug.slots_left} more #{e.notify_roles}" if pug.slots_left == 1

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
          message = "#{pug.slots_left} more #{e.notify_roles}"
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

    @bot.command :queue do |event, *args|
      setup_pug(event) do |e, pug|
        if !pug.active?
          return send_embedded_message(
            description: no_active_pug_message,
            channel: e.channel
          )
        end

        errors = []
        queuees = []

        if args.empty?
          user_id = e.user_id
          display_name = e.display_name_for(user_id)

          pug.leave(user_id)
          pug.join(user_id)
          queuees << display_name
        else
          args.each do |mention|
            if !mention.match(VALID_MENTION)
              errors << "#{mention} isn't a valid mention"
              next
            end

            user_id = mention_to_user_id(mention)
            display_name = e.display_name_for(user_id) || mention

            pug.leave(user_id)
            pug.join(user_id)
            queuees << display_name
          end
        end

        message = ""
        description = []

        if queuees.any?
          description << [
            queuees.to_sentence,
            queuees.count == 1 ? "goes" : "go",
            "to the back of the queue"
          ].join(" ")
        end

        description = [errors, description.join(MSG_SNIPPET_DELIMITER)].join("\n")

        send_embedded_message(
          message: message,
          description: description,
          channel: e.channel
        )
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

          e.find_user(user_id).add_role(ENV['READY_ROLE'])
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
            e.find_user(user_id).add_role(ENV['READY_ROLE'])
            pug.join_team(team_no: team_no, player_id: user_id)
            display_name = e.display_name_for(user_id) || mention
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

    @bot.command :end, aliases: [:fim] do |event, *args|
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
      message = "#{e.notify_roles} PUG started"
    else
      snippets = ["#{e.display_name} joins the PUG", "#{pug.player_slots} joined"]
      message = "#{pug.slots_left} more #{e.notify_roles}" if pug.slots_left.between?(1, 3)
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
      # a rough zipf distribution
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
    event.find_users(pug.players).each do |player|
      player && player.remove_role(ENV['READY_ROLE'])
    end

    pug.end_pug

    send_embedded_message(
      description: 'PUG ended',
      channel: event.channel
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

    puts "========================"
    puts res.body
    puts "========================"

    JSON.parse(res.body).map(&:to_h)
  end

  def ten_minutes_ago
    Time.now.to_i - TEN_MINUTES
  end

  def discord_channel_leaderboard_url(channel_id)
    [ENV['RESULTS_APP_URL'], "discord_channels", channel_id].join('/')
  end
end
