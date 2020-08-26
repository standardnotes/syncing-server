FROM ruby:2.6.5-alpine

ARG optimize_for_raspberry_pi
ARG UID=1000
ARG GID=1000

RUN addgroup -S snotes -g $GID && adduser -D -S snotes -G snotes -u $UID

RUN apk add --update --no-cache \
    alpine-sdk \
    mariadb-dev \
    tzdata

WORKDIR /syncing-server

RUN chown -R $UID:$GID .

USER snotes

COPY --chown=$UID:$GID Gemfile Gemfile.lock /syncing-server/

RUN if [ "$optimize_for_raspberry_pi" = true ] ; then sed -i 's/bcrypt (3.1.13)/bcrypt (3.1.12)/g' Gemfile.lock; fi

RUN gem install bundler && bundle install

COPY --chown=$UID:$GID . /syncing-server

ENTRYPOINT [ "docker/entrypoint.sh" ]

CMD [ "start-web" ]
