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

Edit the `.env.example` file, update with your bot's `client_id` and `token` and save as `.env`. Then:

    $ source .env
    $ bundle exec exe\qwtf-discord-bot server


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
