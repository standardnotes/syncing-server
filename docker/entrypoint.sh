#!/bin/sh
set -e

case "$1" in
  'start-web' )
    echo "Prestart Step 1/2 - Removing server lock"
    rm -f /syncing-server/tmp/pids/server.pid
    echo "Prestart Step 2/2 - Migrating database"
    bundle exec rails db:migrate
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
