FROM ruby:2.6.5-slim-stretch
MAINTAINER Andy Duss <github@mindovermiles262>

ENV RAILS_ENV=development

# Update System
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y git build-essential libsqlite3-dev libmariadb-dev vim

# Copy and install Gems
COPY ./Gemfile      /syncing-server/Gemfile
COPY ./Gemfile.lock /syncing-server/Gemfile.lock
WORKDIR /syncing-server
RUN gem install bundler && bundle install

# Copy the remaining files
COPY . /syncing-server

# Migrate the DB and start development server
RUN rails db:migrate
CMD ["rails", "server", "-b", "0.0.0.0"]
