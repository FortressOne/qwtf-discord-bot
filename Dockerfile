FROM ruby:3.0
WORKDIR /discord-bot/
RUN gem install bundler
RUN git clone https://github.com/multiplay/qstat.git \
 && cd /discord-bot/qstat \
 && ./autogen.sh \
 && ./configure \
 && make install \
 && cd /discord-bot/
ENV PATH="/discord-bot/qstat/:${PATH}"
COPY . /discord-bot/
RUN bundle install \
 && gem build qwtf_discord_bot.gemspec \
 && gem install --local /discord-bot/qwtf_discord_bot-$(cat VERSION).gem
ENTRYPOINT ["qwtf_discord_bot"]
