FROM ruby:2.6.5-slim-stretch
MAINTAINER Andy Duss <github@mindovermiles262>

ENV RAILS_ENV=docker_development

# Update System
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y git build-essential libmariadb-dev

# Copy and install Gems
COPY ./Gemfile      /syncing-server/Gemfile
COPY ./Gemfile.lock /syncing-server/Gemfile.lock
WORKDIR /syncing-server
RUN gem install bundler && bundle install

# Copy the remaining files
COPY . /syncing-server

# Migrate the DB and start development server
CMD "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0"
