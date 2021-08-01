#!/bin/sh

# Author: Jarrod Cameron (z5210220)
# Date:   13/05/21  9:35

# Exit on non-zero return status
set -e

if [ "$(which docker hugo 2>/dev/null | wc -l)" != '2' ]; then
	echo 'ERROR: `docker` or `hugo` is not installed!' >&2
	echo 'Consider running the following command:' >&2
	echo '    apt update && apt install -y docker hugo' >&2
	exit 1
fi

hugo

if [ "$(docker inspect website)" = '[]' ]; then
	docker build -t website .
fi

if [ -z "$(docker ps --format='{{json .}}' | jq 'select(.Names == "website")')" ]; then

	id="$(docker images --format='{{json .}}' | jq --raw-output 'select(.Repository == "website") | .ID')"
	docker run --publish 80:80 --detach=true --interactive=true --name 'website' "$id" >/dev/null

	id="$(docker ps --format='{{json .}}' | jq --raw-output 'select(.Names == "website") | .ID')"
	docker exec -ti "$id" /usr/sbin/nginx
fi



