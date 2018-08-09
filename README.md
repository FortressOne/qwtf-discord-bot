# QwtfDiscordBot

A Discord bot for checking the status of QuakeWorld Team Fortress servers

![screenshot of bot](screenshot.png)


## Dependencies

  - Ruby >= 2.5.0
  - [qstat](https://github.com/multiplay/qstat) version with JSON support.  Tested with commit [2ab78bd5c30fbd47b2bdd4a6279296d66424b37e](https://github.com/multiplay/qstat/tree/2ab78bd5c30fbd47b2bdd4a6279296d66424b37e). Should be added to `$PATH`.


## Installation

    $ gem install qwtf_discord_bot


## Usage

Create a bot on discord.

Edit the `.env.example` file, update with your bot's `client_id` and `token` and save as `.env`.

    $ source .env


### List commands

    $ bundle exec exe/qwtf-discord-bot server help

There are two features:


### Server

This responds to `!server` messages by providing information about your game
server. E.G.

    $ bundle exec exe/qwtf-discord-bot server --hostname fortressone.ga --port 27501

```
Usage:
  qwtf_discord_bot server

Options:
  [--hostname=HOSTNAME]
                         # Default: localhost
  [--port=N]
                         # Default: 27500
```


### Watcher

This watches the game server and announces if anyone has joined the server. It
polls the server once every 30 seconds and will only report a player joining if
they haven't been connected for more than ten minutes. E.G.

    $ bundle exec exe/qwtf-discord-bot watcher --hostname fortressone.ga --port 27501

```
Usage:
  qwtf_discord_bot watcher

Options:
  [--hostname=HOSTNAME]
                         # Default: localhost
  [--port=N]
                         # Default: 27500
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
