FROM ruby:2.6.5-alpine

ARG optimize_for_raspberry_pi

RUN apk add --update --no-cache \
    alpine-sdk \
    mariadb-dev \
    tzdata

WORKDIR /syncing-server

COPY Gemfile Gemfile.lock /syncing-server/

RUN if [ "$optimize_for_raspberry_pi" = true ] ; then sed -i 's/bcrypt (3.1.16)/bcrypt (3.1.12)/g' Gemfile.lock; fi

RUN gem install bundler && bundle install

COPY . /syncing-server

ENTRYPOINT [ "docker/entrypoint.sh" ]

CMD [ "start-web" ]
