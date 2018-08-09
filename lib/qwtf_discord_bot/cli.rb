#!/usr/bin/env ruby

require 'qwtf_discord_bot'
require 'thor'

class QwtfDiscordBot < Thor
  def self.exit_on_failure?
    true
  end

  desc 'server', 'Runs the qwtf-discord-bot server'
  def server
    QwtfDiscordBot::Server.run
  end

  desc 'watcher', 'Runs the qwtf-discord-bot watcher'
  def watcher
    QwtfDiscordBot::Watcher.run
  end
end

QwtfDiscordBot.start
