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
          message = "You've already joined"
          send_and_log_message(message, e.channel)
        else
          pug.join(e.user_id)

          message = if pug.joined_player_count == 1
                      [
                        "#{e.username} creates a PUG",
                        pug.player_slots,
                        pug.notify_roles
                      ].join(' | ')
                    elsif pug.slots_left.between?(1,3)
                      [
                        "#{e.username} joins the PUG",
                        pug.player_slots,
                        "#{pug.slots_left} more",
                        pug.notify_roles
                      ].join(' | ')
                    else
                      [
                        "#{e.username} joins the PUG",
                        pug.player_slots
                      ].join(' | ')
                    end

          send_and_log_message(message, e.channel)

          if pug.full?
            message = start_pug(
              pug.player_slots,
              e.mentions_for(pug.joined_players)
            )

            send_and_log_message(message, e.channel)
          end
        end
      end
    end

    bot.command :status do |event, *args|
      set_pug(event) do |e, pug|
        message = if pug.active?
                    [
                      "#{e.usernames_for(pug.joined_players).join(', ')} joined",
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
          message = start_pug(
            pug.player_slots,
            e.mentions_for(pug.joined_players)
          )

          send_and_log_message(message, e.channel)
        end
      end
    end

    bot.command :leave do |event, *args|
      set_pug(event) do |e, pug|
        if !pug.active?
          message = "There's no active PUG to leave"
          send_and_log_message(message, e.channel)
        elsif !pug.joined_players.include?(e.user_id)
          message = "You're not in the PUG"
          send_and_log_message(message, e.channel)
        else
          pug.leave(e.user_id)
          message = "#{e.username} leaves the PUG | #{pug.player_slots} remain"
          send_and_log_message(message, e.channel)

          if pug.empty?
            message = end_pug(pug)
            send_and_log_message(message, e.channel)
          end
        end
      end
    end

    bot.command :end do |event, *args|
      set_pug(event) do |e, pug|
        message = if !pug.active?
                    "There's no active PUG to end"
                  else
                    end_pug(pug)
                  end

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

  def start_pug(player_slots, mentions)
    [
      'Time to play!',
      player_slots,
      mentions.join(' ')
    ].join(' | ')
  end

  def end_pug(pug)
    pug.end_pug
    'PUG ended'
  end

  def send_and_log_message(message, channel)
    channel.send_message(message) && puts(message)
  end
end
