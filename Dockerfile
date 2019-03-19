FROM ruby:2.5.4

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y postgresql postgresql-server-dev-all liblocal-lib-perl build-essential

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile      /usr/src/app
COPY Gemfile.lock /usr/src/app

RUN bundle install --deployment

COPY . /usr/src/app

# Sqitch expects partman
# RUN /usr/src/app/script/install-partman

# Install sqitch so migrations work
RUN /usr/src/app/script/install-sqitch

CMD /bin/bash
