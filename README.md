# QwtfDiscordBot

A Discord bot for checking the status of QuakeWorld Team Fortress servers


## Dependencies

  - Ruby >= 2.5.0
  - [qstat](https://github.com/multiplay/qstat) version with JSON support.  Tested with commit [2ab78bd5c30fbd47b2bdd4a6279296d66424b37e](https://github.com/multiplay/qstat/tree/2ab78bd5c30fbd47b2bdd4a6279296d66424b37e). Should be added to `$PATH`.


## Installation

    gem install qwtf_discord_bot


## Usage

- Create a bot on discord
- Create a `~/.config/qwtf_discord_bot/config.yaml` file containing your bots
  credentials and server endpoints

  ```yaml
  ---
  token: "dhjksahdkjhhur43hu4hu5b4b5k34j12b4kj3b4kjb4j32kb4kjb4kb3k2b"
  client_id: "873298379487294398"
  endpoints:
    - "sydney.fortressone.org":
      - channel_ids:
        - 832749832749873298
        - 798437748937298448
    - "sydney.fortressone.org:27501":
      - channel_ids:
        - 590204247224745986
    - "dallas.fortressone.org":
      - channel_ids:
        - 480928490328409328
  emojis:
    red:
      scout: "<:scout_red:424097703127941130>"
      sniper: "<:sniper_red:424097704076115978>"
      soldier: "<:soldier_red:424097704197619712>"
      demoman: "<:demoman_red:424097687739301919>"
      medic: "<:medic_red:424097695418941451>"
      pyro: "<:pyro_red:424097704403271691>"
      hwguy: "<:hwguy_red:424097694030757889>"
      spy: "<:spy_red:424097704138899466>"
      engineer: "<:engineer_red:424097694680612864>"
    blue:
      scout: "<:scout_blue:456062063983460353>"
      sniper: "<:sniper_blue:456062061953417216>"
      soldier: "<:soldier_blue:456062062997536801>"
      demoman: "<:demoman_blue:456061938636554240>"
      medic: "<:medic_blue:456062056710537217>"
      pyro: "<:pyro_blue:456062062460928010>"
      hwguy: "<:hwguy_blue:456062063190736926>"
      spy: "<:spy_blue:456062062032846849>"
      engineer: "<:engineer_blue:456062031125020683>"
  dashboards:
    - server_id: 744911007859736616
      name: "active-servers"
      endpoints:
        - "sydney.fortressone.org"
        - "sydney.fortressone.org:27510"
        - "dallas.fortressone.org"
  ```

- Use  the `QWTF_DISCORD_BOT_CONFIG_FILE` environment variable to specify an
  alternative config file path.

      export QWTF_DISCORD_BOT_CONFIG_FILE="config.yaml"


### Commands

There are three modules:


#### Server

    qwtf-discord-bot server

This responds to discord messages:
  - `!server`
  - `!active`
  - `!all`

![screenshot of bot responding to !server command](server_screenshot.png)


#### Pug

    qwtf-discord-bot pug

This responds to discord messages:
- `!status` Shows who has joined
- `!join [@player1] [@player2]` Join PUG. Can also join other players
- `!leave` Leave PUG
- `!kick <@player> [@player2]` Kick one or more other players
- `!team <team_no> [@player1] [@player2]` Join team
- `!unteam [@player1] [@player2]` Leave team and go to front of queue
- `!choose` Choose a bit fair a bit random teams.
- `!choose [n]` Choose fair teams. Pass number for nth fairest team
- `!end` End PUG. Kicks all players
- `!teamsize <no_of_players>` Set number of players in a team
- `!maps` Show map list
- `!map` Suggest a map
- `!notify <@role>` Set @role for alerts


#### Watcher

    qwtf-discord-bot watcher

This watches the game server and announces if anyone has joined the server. It
polls the server once every 30 seconds and will only report a player joining if
they haven't been connected for more than ten minutes.

![screenshot of bot reporting player joining server](watcher_screenshot.png)


#### Vote

    qwtf-discord-bot vote

A map voting tool. `!vote` grabs the teamsize from Redis and sends this along with channel information to the API to get a list of recommended maps. Can also be used for arbitrary voting if voting options are provided as comma separated arguments.


## Gem

Build:

    gem build qwtf_discord_bot.gemspec


Install:


    gem install --local qwtf_discord_bot-$(cat VERSION).gem


Push:

    gem push qwtf_discord_bot-$(cat VERSION).gem


## Develop

```
bundle install
bundle exec bin/qwtf_discord_bot
```


## Docker

Run:

Assuming a `./config.yaml` file exists:

    docker-compose up


Only discord-bot server:

    docker run -it \
      --env QWTF_DISCORD_BOT_CONFIG_FILE=config.yaml \
      --mount type=bind,source="$(pwd)"/config.yaml,target=/discord-bot/config.yaml \
      discord-bot server


Only discord-bot watcher:

    docker run -it \
      --env QWTF_DISCORD_BOT_CONFIG_FILE=config.yaml \
      --mount type=bind,source="$(pwd)"/config.yaml,target=/discord-bot/config.yaml \
      discord-bot watcher


Only discord-bot pug:

    docker run -it \
      --env QWTF_DISCORD_BOT_CONFIG_FILE=config.yaml \
      --mount type=bind,source="$(pwd)"/config.yaml,target=/discord-bot/config.yaml \
      discord-bot pug


Only discord-bot vote:

    docker run -it \
      --env QWTF_DISCORD_BOT_CONFIG_FILE=config.yaml \
      --mount type=bind,source="$(pwd)"/config.yaml,target=/discord-bot/config.yaml \
      discord-bot vote


Build:

    docker build --tag=discord-bot .

Push:

    docker tag discord-bot fortressone/discord-bot:latest \
      && docker push fortressone/discord-bot:latest


Create AWS instance:

```
docker-machine create \
  --driver amazonec2 \
  --amazonec2-access-key <AWS_ACCESS_KEY> \
  --amazonec2-secret-key <AWS_SECRET_KEY> \
  --amazonec2-root-size 30 \
  --amazonec2-region ap-southeast-2 \
  discord-bot
```


### Deploy

Push image to dockerhub then:

```
source .env.discord-bot
eval $(docker-machine env discord-bot)
docker-compose pull
docker-compose up -d \
  discord-command-bot \
  discord-dashboard-bot \
  discord-pug-bot \
  discord-watcher-bot \
  discord-vote-bot
```


### Update configs in production

This is silly and needs to be fixed but in the meantime serves as a note to me so I don't forget:

Edit production.yaml then:
```
source .env.discord-bot
eval $(docker-machine env discord-bot)
docker-machine scp production.yaml discord-bot:/home/ubuntu/.config/qwtf_discord_bot/config.yaml
docker restart qwtf-discord-bot_discord-dashboard-bot_1
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).



## Todo
- [x] Fix !map
- [ ] Show still to vote
- [x] Finish vote when teamsizex2 have voted
- [x] Fix possible bug editing wrong message
- [ ] Click x for 'none of these'
- [ ] Add maps
