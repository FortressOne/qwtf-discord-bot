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
RUN bundle install
ENTRYPOINT ["bundle", "exec", "bin/qwtf_discord_bot"]
