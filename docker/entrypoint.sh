#!/bin/sh
set -e

case "$1" in
  'start-local' )
    echo "Prestart Step 1/3 - Removing server lock"
    rm -f /syncing-server/tmp/pids/server.pid
    echo "Prestart Step 2/3 - Install dependencies"
    bundle install
    echo "Prestart Step 3/3 - Migrating database"
    # bundle exec rails db:migrate
    bundle exec rake db:migrate:ignore_concurrent
    echo "Starting Server..."
    bundle exec rails server -b 0.0.0.0
    ;;

  'start-web' )
    echo "Prestart Step 1/2 - Removing server lock"
    rm -f /syncing-server/tmp/pids/server.pid
    echo "Prestart Step 2/2 - Migrating database"
    bundle exec rake db:migrate:ignore_concurrent
    echo "Starting Server..."
    bundle exec rails server -b 0.0.0.0
    ;;

  'start-worker' )
    echo "Starting Worker..."
    bundle exec shoryuken -q $SQS_QUEUE -R
    ;;

   * )
    echo "Unknown command"
    ;;
esac

exec "$@"
