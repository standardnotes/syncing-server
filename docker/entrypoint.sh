#!/bin/sh
set -e

COMMAND=$1 && shift 1

case "$COMMAND" in
  'start-local' )
    echo "Prestart Step 1/3 - Removing server lock"
    rm -f /syncing-server/tmp/pids/server.pid
    echo "Prestart Step 2/3 - Install dependencies"
    bundle install
    echo "Prestart Step 3/3 - Migrating database"
    bundle exec rails db:migrate
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
    bundle exec shoryuken -R -C config/shoryuken.yml
    ;;

  'daily-backup' )
    echo "Starting Daily Backup..."
    bundle exec rake "items:perform_daily_backup_jobs"
    ;;

  'daily-backup-no-email' )
    echo "Starting Daily Backup Without Emails..."
    bundle exec rake "items:perform_daily_backup_jobs[false]"
    ;;

  * )
    echo "Unknown command"
    ;;
esac

exec "$@"
