#!/bin/sh
set -e

# SIGHUP-handler
sighup_handler() {
  echo "Reloading nginx configuration and certificates..."
  nginx -s reload
}

# SIGTERM-handler
sigterm_handler() {
  # kubernetes sends a sigterm, where nginx needs SIGQUIT for graceful shutdown
  echo "Gracefully shutting down nginx..."
  nginx -s quit
  echo "Finished shutting down nginx!"

  # stop inotifywait
  inotifywait_pid=$(pgrep inotifywait)
  echo "Received SIGTERM, killing inotifywait with pid $inotifywait_pid..."
  kill -SIGTERM "$inotifywait_pid"
  wait "$inotifywait_pid"
  echo "Killed inotifywait"
}

# setup handlers
echo "Setting up signal handlers..."
trap 'kill ${!}; sighup_handler' 1 # SIGHUP
trap 'kill ${!}; sigterm_handler' 15 # SIGTERM

# watch for ssl certificate changes
init_inotifywait() {
  echo "Starting inotifywait to detect changes in certificates..."
  while inotifywait -e modify,move,create,delete /certificates; do
    echo "Files in /certificates changed, reloading nginx..."
    nginx -s reload
  done
}
init_inotifywait &

# run nginx
echo "Starting nginx..."
nginx &

# wait forever until sigterm_handler stops all background processes
while true
do
  tail -f /dev/null & wait ${!}
done
