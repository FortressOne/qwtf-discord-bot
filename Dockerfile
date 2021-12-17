FROM ruby:3.0
WORKDIR /discord-bot/
COPY . /discord-bot/
RUN gem install bundler
RUN git clone https://github.com/multiplay/qstat.git \
 && cd /discord-bot/qstat \
 && ./autogen.sh \
 && ./configure \
 && make install
RUN cd /discord-bot/ \
 && bundle install
ENV PATH="/discord-bot/qstat/:${PATH}"
ENTRYPOINT ["bundle", "exec", "bin/qwtf_discord_bot"]
