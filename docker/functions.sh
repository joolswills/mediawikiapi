# Shell functions for running docker containers -*- bash -*-

startContainer() {
	port=$1
	containerName=$2

	docker run -d -p $port:80 -e LC_ALL=C.UTF-8 $containerName
}

isContainerUp() {
	container=$1

	docker logs $container 2>&1 | grep -q apache2.-D.FOREGROUND
	echo $?
}

getContainerReady() {
	port=$1
	containerName=$2

	container=$(startContainer $port $containerName)
	ready=$(isContainerUp $container)

	while [ "$ready" -ne 0 ] ; do
		ready=$(isContainerUp $container)

		sleep 1
	done
	echo $container
}

setupMW() {
	container=$1
	wikiadmin=$2
	wikipass=$3

	docker exec $container php /var/www/html/maintenance/install.php	\
		   --dbtype=sqlite --dbpath=/tmp --pass=$wikipass 				\
		   --skins=Vector --scriptpath= core $wikiadmin |				\
		grep -q 'MediaWiki has been successfully installed'
	if [ $? -ne 0 ]; then
		echo Trouble installing MediaWiki in container! 1>&2
		teardownContainer $container
		exit 2
	fi
	docker exec $container sh -c										\
		   'chown www-data /tmp/*.sqlite /var/www/html/images			\
		   		  /var/www/html/cache'
	# Turn on uploads for the tests
	docker exec $container sh -c										\
		   'echo "\$wgEnableUploads = true;" >>							\
		   		  /var/www/html/LocalSettings.php'
	# Allow i18n caching to disk
	docker exec $container sh -c										\
		   'echo "\$wgCacheDirectory = \"\$IP/cache\";" >>				\
		   		  /var/www/html/LocalSettings.php'
	# Turn off most caching
	docker exec $container sh -c										\
		   'echo "\$wgMainCacheType = CACHE_NONE;" >>					\
		   		  /var/www/html/LocalSettings.php'
	# Run a lot of jobs each time
	docker exec $container sh -c										\
		   'echo "\$wgRunJobsAsync = false;" >>							\
		   		  /var/www/html/LocalSettings.php'
	docker exec $container sh -c										\
		   'echo "\$wgJobRunRate = 10;" >>								\
		   		  /var/www/html/LocalSettings.php'
	# Debug logs for troubleshooting
	docker exec $container sh -c										\
		   'echo "\$wgDebugLogFile = \"/tmp/debug.log\";" >>			\
		   		  /var/www/html/LocalSettings.php'
}

teardownContainer() {
	container=$1

	result=$(docker kill $container)
	if [ "$result" != "$container" ]; then
		echo Some problem with the kill?
		exit 3
	fi

	result=$(docker rm $container)
	if [ "$result" != "$container" ]; then
		echo Some problem with removal?
		exit 4
	fi
}

# From https://unix.stackexchange.com/a/358101
getFreePort() {
	netstat -aln | awk '
  $6 == "LISTEN" {
    if ($4 ~ "[.:][0-9]+$") {
      split($4, a, /[:.]/);
      port = a[length(a)];
      p[port] = 1
    }
  }
  END {
    for (i = 3000; i < 65000 && p[i]; i++){};
    if (i == 65000) {exit 1};
    print i
  }
'
}
