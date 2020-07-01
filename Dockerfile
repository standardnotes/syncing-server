FROM ruby:2.6.5-slim-stretch

ARG optimize_for_raspberry_pi

RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y git build-essential libmariadb-dev

WORKDIR /syncing-server

COPY Gemfile Gemfile.lock /syncing-server/

RUN if [ "$optimize_for_raspberry_pi" = true ] ; then sed -i 's/bcrypt (3.1.13)/bcrypt (3.1.12)/g' Gemfile.lock; fi

RUN gem install bundler && bundle install

COPY . /syncing-server

ENTRYPOINT [ "docker/entrypoint.sh" ]

CMD [ "start-web" ]
