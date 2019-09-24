FROM ruby:2.5.4

LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

RUN ( \
  apt-get update; \
  apt-get upgrade -y --no-install-recommends; \
  apt-get install -y postgresql postgresql-server-dev-all liblocal-lib-perl build-essential gettext-base; \
  rm -rf /var/lib/apt/lists/* ; \
  groupadd -r travis && useradd -m -r -g travis travis; \
  mkdir -p /usr/src/app; \
  chown -R travis:travis /usr/src/app \
)

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

USER travis
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
