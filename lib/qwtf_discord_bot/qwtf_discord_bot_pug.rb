# frozen_string_literal: true

require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug # :nodoc:
  include QwtfDiscordBot

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      setup_pug(event) do |e, pug|
        return message("You've already joined", e.channel) if pug.joined?(e.user_id)

        pug.join(e.user_id)

        message = if pug.joined_player_count == 1
                    [
                      "#{e.display_name} creates a PUG",
                      pug.player_slots,
                      pug.notify_roles
                    ].join(' | ')
                  elsif pug.slots_left.between?(1, 3)
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

        message(message, e.channel)

        start_pug(pug, e) if pug.full?
      end
    end

    bot.command :status do |event, *args|
      setup_pug(event) do |e, pug|
        message = if pug.active?
                    [
                      "#{e.display_names_for(pug.joined_players).join(', ')} joined",
                      pug.player_slots
                    ].join(' | ')
                  else
                    'No PUG has been started. `!join` to create'
                  end

        message(message, e.channel)
      end
    end

    bot.command :teamsize do |event, *args|
      setup_pug(event) do |e, pug|
        new_teamsize = args[0]

        if new_teamsize
          pug.teamsize = new_teamsize
          message(
            "Team size set to #{pug.teamsize} | #{pug.player_slots} joined",
            e.channel
          )
          start_pug(pug, e) if pug.full?
        else
          message(
            "Current team size is #{pug.teamsize} | #{pug.player_slots} joined",
            e.channel
          )
        end
      end
    end

    bot.command :leave do |event, *args|
      setup_pug(event) do |e, pug|
        return message(no_active_pug_message, e.channel) unless pug.active?
        return message("You're not in the PUG", e.channel) unless pug.joined?(e.user_id)

        pug.leave(e.user_id)

        message(
          "#{e.display_name} leaves the PUG | #{pug.player_slots} remain",
          e.channel
        )

        message(end_pug_message, e.channel) unless pug.active?
      end
    end

    bot.command :kick do |event, *args|
      setup_pug(event) do |e, pug|
        return message(no_active_pug_message, e.channel) unless pug.active?

        args.each do |mention|
          user_id = mention[3..-2].to_i
          display_name = e.display_name_for(user_id)

          unless pug.joined?(user_id)
            message(
              "#{display_name} isn't in the PUG",
              e.channel
            )

            next
          end

          pug.leave(user_id)

          message(
            "#{display_name} is kicked from the PUG | #{pug.player_slots} remain",
            e.channel
          )

          break message(end_pug_message, e.channel) unless pug.active?
        end
      end
    end

    bot.command :end do |event, *args|
      setup_pug(event) do |e, pug|
        return message(no_active_pug_message, e.channel) unless pug.active?

        pug.end_pug

        message(end_pug_message, e.channel)
      end
    end

    bot.command :notify do |event, *args|
      setup_pug(event) do |e, pug|
        roles = args.join(' ')
        pug.notify_roles = roles

        message = if roles.empty?
                    'Notification removed'
                  else
                    "Notification role set to #{roles}"
                  end

        message(message, e.channel)
      end
    end

    bot.run
  end

  private

  def setup_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
    nil # stop discordrb printing return value
  end

  def start_pug(pug, event)
    message(
      [
        'Time to play!',
        ['Team 1:', event.mentions_for(pug.team(1)).join(' ')].join(' '),
        ['Team 2:', event.mentions_for(pug.team(2)).join(' ')].join(' ')
      ].join("\n"),
      event.channel
    )
  end

  def start_pug_message(player_slots:, mentions:)
    ['Time to play!', player_slots, mentions.join(' ')].join(' | ')
  end

  def end_pug_message
    'PUG ended'
  end

  def no_active_pug_message
    "There's no active PUG"
  end

  def message(message, channel)
    channel.send_message(message) && puts(message)
  end
end
