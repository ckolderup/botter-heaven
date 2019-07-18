# sticking with stretch so we don't have to build opencv 2.x from scratch for now
# TODO: stop using ruby-opencv, allowing us to modern opencv versions
FROM ruby:2.6-stretch

RUN apt-get update -qq && \
  apt-get install -y unzip cmake git libc-dev libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev software-properties-common

# add ffmpeg
RUN apt-get install -y ffmpeg

# install imagemagick@6 manually
RUN apt-get install -y imagemagick libmagickcore-dev libmagickwand-dev

# install opencv@2
RUN apt-get install -y libopencv-dev
RUN bundle config build.ruby-opencv --with-opencv-dir=/usr/local

#### bot-specific dependencies:

#card-game-bot
RUN apt-get install -y libcairo2-dev libgirepository1.0-dev

#animorphs
RUN apt-get install -y bc

#### end bot-specific dependencies

COPY ./bin/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
# Add bundle entry point to handle bundle cache

ENV APP_HOME=/app

ENV BUNDLE_GEMFILE=$APP_HOME/Gemfile \
  BUNDLE_BIN=/bundle/bin \
  GEM_HOME=/bundle \
  BUNDLE_JOBS=2 \
  BUNDLE_PATH=/bundle

ENV PATH="${BUNDLE_BIN}:${PATH}"
# Bundle installs with binstubs to our custom /bundle/bin volume path.
# Let system use those stubs.
# set up files
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
# COPY . .

