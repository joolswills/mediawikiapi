#!/bin/bash

. docker/functions.sh

WIKI_DIAGNOSTICS=${WIKI_DIAGNOSTICS:-0}
export WIKI_DIAGNOSTICS

WIKI_PASS=${WIKI_PASS:-pass123456}
export WIKI_PASS

WIKI_ADMIN=${WIKI_ADMIN:-admin}
export WIKI_ADMIN

WIKI_PORT=${WIKI_PORT:-$(getFreePort)}

WIKI_API_URL=${WIKI_API_URL:-http://localhost:$WIKI_PORT/api.php}
export WIKI_API_URL

# 1.27 does not work due to a change made in install.php
WIKI_IMAGE=${WIKI_IMAGE:-mediawiki:latest}

if [ -z "$WIKI_PORT" ]; then
	echo Could not find a free port to use.
	exit 10
fi

echo -n "Preparing container to listen on $WIKI_PORT... "
container=$(getContainerReady $WIKI_PORT $WIKI_IMAGE)
echo up as $container.

echo -n "Setting up SQLite-based MW... "
setupMW $container $WIKI_ADMIN $WIKI_PASS
echo done.

echo Running tests...
make; make test || echo FAILURES, but killing container anyway

echo -n "Tearing down container... "
teardownContainer $container
echo done.
