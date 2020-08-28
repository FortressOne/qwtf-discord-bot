# frozen_string_literal: true

require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  FOUR_HOURS = 4 * 60 * 60

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      set_pug(event) do |e, pug|
        if pug.joined_players.include?(e.user_id)
          return send_and_log_message("You've already joined", e.channel)
        end

        pug.join(e.user_id)

        message = if pug.joined_player_count == 1
                    [
                      "#{e.display_name} creates a PUG",
                      pug.player_slots,
                      pug.notify_roles
                    ].join(' | ')
                  elsif pug.slots_left.between?(1,3)
                    [
                      "#{e.display_name} joins the PUG",
                      pug.player_slots,
                      "#{pug.slots_left} more",
                      pug.notify_roles
                    ].join(' | ')
                  else
                    [
                      "#{e.display_name} joins the PUG",
                      pug.player_slots
                    ].join(' | ')
                  end

        send_and_log_message(message, e.channel)

        if pug.full?
          start_pug(
            player_slots: pug.player_slots,
            mentions: e.mentions_for(pug.joined_players),
            channel: e.channel
          )
        end
      end
    end

    bot.command :status do |event, *args|
      set_pug(event) do |e, pug|
        message = if pug.active?
                    [
                      "#{e.display_names_for(pug.joined_players).join(', ')} joined",
                      pug.player_slots
                    ].join(' | ')
                  else
                    'No PUG has been started. `!join` to create'
                  end

        send_and_log_message(message, e.channel)
      end
    end

    bot.command :maxplayers do |event, *args|
      set_pug(event) do |e, pug|
        new_maxplayers = args[0]

        message = if new_maxplayers
                    pug.maxplayers = new_maxplayers
                    "Max number of players set to #{pug.maxplayers} | #{pug.player_slots} joined"
                  else
                    "Current max number of players is #{pug.maxplayers} | #{pug.player_slots} joined"
                  end

        send_and_log_message(message, e.channel)

        if pug.full?
          start_pug(
            player_slots: pug.player_slots,
            mentions: e.mentions_for(pug.joined_players),
            channel: e.channel
          )
        end
      end
    end

    bot.command :leave do |event, *args|
      set_pug(event) do |e, pug|
        return no_active_pug(e.channel) if !pug.active?

        if !pug.joined_players.include?(e.user_id)
          return send_and_log_message("You're not in the PUG", e.channel)
        end

        pug.leave(e.user_id)

        send_and_log_message(
          "#{e.display_name} leaves the PUG | #{pug.player_slots} remain",
          e.channel
        )

        end_pug(pug: pug, channel: e.channel) if pug.empty?
      end
    end

    bot.command :kick do |event, *args|
      set_pug(event) do |e, pug|
        return no_active_pug(e.channel) unless pug.active?

        args.each do |mention|
          user_id = mention[3..-2].to_i
          display_name = e.display_name_for(user_id)

          if !pug.joined_players.include?(user_id)
            next send_and_log_message(
              "#{display_name} isn't in the PUG",
              e.channel
            )
          end

          pug.leave(user_id)

          send_and_log_message(
            "#{display_name} is kicked from the PUG | #{pug.player_slots} remain",
            e.channel
          )

          break end_pug(pug: pug, channel: e.channel) if pug.empty?
        end
      end
    end

    bot.command :end do |event, *args|
      set_pug(event) do |e, pug|
        return no_active_pug(e.channel) if !pug.active?

        message = end_pug(pug)

        send_and_log_message(message, e.channel)
      end
    end

    bot.command :notify do |event, *args|
      set_pug(event) do |e, pug|
        roles = args.join(' ')
        pug.notify_roles = roles

        message = if roles.empty?
                    'Notification removed'
                  else
                    "Notification role set to #{roles}"
                  end

        send_and_log_message(message, e.channel)
      end
    end

    bot.run
  end

  private

  def set_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
  end

  def start_pug(player_slots:, mentions:, channel:)
    message = [
      'Time to play!',
      player_slots,
      mentions.join(' ')
    ].join(' | ')

    send_and_log_message(message, channel)
  end

  def end_pug(pug:, channel:)
    pug.end_pug
    send_and_log_message('PUG ended', channel)
  end

  def no_active_pug(channel)
    message = "There's no active PUG"
    send_and_log_message(message, channel)
  end

  def send_and_log_message(message, channel)
    channel.send_message(message) && puts(message)
  end
end
