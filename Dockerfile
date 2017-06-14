FROM ruby:2.4.1

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile      /usr/src/app
COPY Gemfile.lock /usr/src/app

RUN bundle install --deployment

COPY . /usr/src/app

# Install sqitch so migrations work
RUN env BINDIR=/usr/local/bin /usr/src/app/script/install-sqitch

CMD /bin/bash
