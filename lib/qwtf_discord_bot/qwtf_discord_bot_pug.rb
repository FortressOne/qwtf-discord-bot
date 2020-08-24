require 'pug'
require 'event_decorator'

class QwtfDiscordBotPug
  include QwtfDiscordBot

  FOUR_HOURS = 4 * 60 * 60

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :join do |event, *_args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)

      pug.join(e.user_id)

      message = if pug.full?
                  [
                    "Time to play!",
                    pug.player_slots,
                    e.mentions_for(pug.joined_players).join(" "),
                  ].join(" | ")
                elsif pug.joined_player_count == 1
                  [
                    "#{e.username} creates a PUG",
                    pug.player_slots,
                    pug.role,
                  ].join(" | ")
                elsif pug.slots_left <= 3
                  [
                    "#{e.username} joins the PUG",
                    pug.player_slots,
                    "#{pug.slots_left} more",
                    pug.role,
                  ].join(" | ")
                else
                  [
                    "#{e.username} joins the PUG",
                    pug.player_slots,
                  ].join(" | ")
                end

      send_and_log_message(message, e.channel)
    end

    bot.command :status do |event, *args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)

      message = if pug.active?
                  [
                    "#{e.usernames_for(pug.joined_players).join(" ")} joined",
                    pug.player_slots
                  ].join(" | ")
                else
                  "No PUG has been started. `!join` to create"
                end

      send_and_log_message(message, e.channel)
    end

    bot.command :maxplayers do |event, *args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)
      new_maxplayers = args[0]

      message = if new_maxplayers
        pug.maxplayers = new_maxplayers
        "Max number of players set to #{pug.maxplayers} | #{pug.player_slots}"
      else
        "Current max number of players is #{pug.maxplayers} | #{pug.player_slots}"
      end

      send_and_log_message(message, e.channel)

      if pug.full?
        message = [
          "Time to play!",
          pug.player_slots,
          e.mentions_for(pug.joined_players).join(" "),
        ].join(" | ")

        send_and_log_message(message, e.channel)
      end
    end

    bot.command :leave do |event, *_args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)

      pug.leave(e.user_id)

      message = "#{e.username} leaves the PUG | #{pug.player_slots} remain"

      send_and_log_message(message, e.channel)

      if pug.empty?
        pug.end_pug

        message = "PUG ended"
        send_and_log_message(message, e.channel)
      end
    end

    bot.command :end do |event, *_args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)

      pug.end_pug

      message = "PUG ended"
      send_and_log_message(message, e.channel)
    end

    bot.command :role do |event, *args|
      e = EventDecorator.new(event)
      pug = Pug.for(e.channel_id)
      role = args.join(" ")

      pug.role = role

      message = "Notification role set to #{role}"
      send_and_log_message(message, e.channel)
    end

    bot.run
  end

  private

  def send_and_log_message(message, channel)
    channel.send_message(message)
    puts message
  end
end
