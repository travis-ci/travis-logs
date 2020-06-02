FROM ruby:2.5.8

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

RUN ( \
  apt-get update; \
  apt-get upgrade -y --no-install-recommends; \
  apt-get install -y curl postgresql postgresql-server-dev-all liblocal-lib-perl build-essential; \
  rm -rf /var/lib/apt/lists/* ; \
)

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

RUN bundle install --deployment

COPY . /app

# Sqitch expects partman
# RUN /app/script/install-partman

# Install sqitch so migrations work
RUN /app/script/install-sqitch
