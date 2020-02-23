FROM ruby:2.6.5-slim-stretch
LABEL Andy Duss <github@mindovermiles262>
ARG optimize_for_raspberry_pi

# Update System
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y git build-essential libmariadb-dev

# Copy the syncing-server files
COPY . /syncing-server
WORKDIR /syncing-server

# On Raspberry Pi, we should use bcrypt 3.1.12 instead of 3.1.13 
# within the Gemfile.lock file
RUN if [ "$optimize_for_raspberry_pi" = true ] ; then sed -i 's/bcrypt (3.1.13)/bcrypt (3.1.12)/g' Gemfile.lock; fi

# Install gems
RUN gem install bundler && bundle install

# Migrate the DB and start development server
CMD "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0"
