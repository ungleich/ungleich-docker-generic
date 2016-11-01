#!/bin/bash

set -e

# Path where kea.conf file will be saved
export DESTINATION_DIR=${1-${0%/*}}

#########################################
# Start of parameters declaration section
#########################################

#
# User defined network parameters
#

#Optional. Default value "ethz-scientific"
DOCKER_NETWORK_NAME=""

# Required
export DOCKER_NETWORK_SUBNET=""
DOCKER_NETWORK_GATEWAY=""
DOCKER_NETWORK_IP_RANGE=""

#
# Kea parameters
#

# Optional. Default value "kea"
KEA_CONTAINER_NAME=""

# Required
export KEA_POOL_SUBNET=""

#
# Postgres parameters
#

# Optional. Default value "postgres"
POSTGRES_CONTAINER_NAME="" 

# Required
export POSTGRES_HOSTNAME=""
export POSTGRES_DB=""
export POSTGRES_USER=""
export POSTGRES_PASSWORD=""

#
# nginx parameters
#

# Optional. Default value "nginx"
NGINX_CONTAINER_NAME="" 

# Required
NGINX_HOSTNAME=""
NGINX_LOCAL_FILES_PATH=""

#
# TFTP server parameters
#

# Optional. Default value "tftp"
TFTP_CONTAINER_NAME="" 

# Required
export TFTP_SERVER_IP="" # NOTE: This should be part of DOCKER_NETWORK_IP_RANGE
export TFTP_SERVER_HOSTNAME=""

# Regarding TFTP server, you might serve the iPXE built by the container or 
# choose your own files. Your own files have preference, so if you use this
# option, the built-in iPXE image will be ignored.

# Any local path on the host
TFTP_LOCAL_FILES_PATH=""

if [ -n "$TFTP_LOCAL_FILES_PATH" ]; then
	TFTP_FILES="-v ${TFTP_LOCAL_FILES_PATH}:/var/lib/tftpboot:ro"
else
	TFTP_FILES="-e HTTP_SERVER=${NGINX_HOSTNAME}"
fi

#
# cdist trigger parameters
#

# Optional. Default value "trigger"
CDIST_TRIGGER_CONTAINER_NAME="" 
# Optional. Default value "3000"
CDIST_TRIGGER_TRIGGER_PORT=""

# Required
CDIST_TRIGGER_HOSTNAME=""

#########################################
# End of parameters declaration section
#########################################

#
# Create Kea configuration file, using parameters defined above.
#

sh ${0%/*}/kea_config_builder.sh

#################################
# Docker related section
#################################

#
# Retrieving images from Docker Hub
#

docker pull ungleich/ungleich-kea
docker pull ungleich/ungleich-postgres-kea
docker pull ungleich/ungleich-tftp
docker pull ungleich/ungleich-cdist-trigger
docker pull nginx:stable

#
# User defined network creation
#
if [ -z `docker network ls | grep -w "${DOCKER_NETWORK_NAME:-ethz-scientific}"` ]; then
docker network create --subnet="$DOCKER_NETWORK_SUBNET" \
						--gateway="$DOCKER_NETWORK_GATEWAY" \
						--ip-range="$DOCKER_NETWORK_IP_RANGE" \
						--driver=bridge "${DOCKER_NETWORK_NAME:-ethz-scientific}"
else
	echo "Network with name ${DOCKER_NETWORK_NAME:-ethz-scientific} already exists" >&2
fi

#
# Containers creation
#

# Creating TFTP container
docker run --name "${TFTP_CONTAINER_NAME:-tftp}" \
			--network="${DOCKER_NETWORK_NAME:-ethz-scientific}" \
			--network-alias "$TFTP_SERVER_HOSTNAME" \
			--ip "$TFTP_SERVER_IP" \
			"$TFTP_FILES" \
			-d ungleich/ungleich-tftp

# Creating Postgres container
docker run --name "${POSTGRES_CONTAINER_NAME:-postgres}" \
			--network="${DOCKER_NETWORK_NAME:-ethz-scientific}" \
			--network-alias="$POSTGRES_HOSTNAME" \
			-e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
			-e POSTGRES_USER="$POSTGRES_USER" \
			-e POSTGRES_DB="$POSTGRES_DB" \
			-d ungleich/ungleich-postgres-kea

# Give enough time to Postgres to start
sleep 10

# Creating Kea container
docker run --name "${KEA_CONTAINER_NAME:-kea}" \
			--network="${DOCKER_NETWORK_NAME:-ethz-scientific}" \
			-v "${DESTINATION_DIR}/kea.conf":/usr/local/etc/kea/kea.conf:ro \
			-d ungleich/ungleich-kea 

# Creating cdist-trigger container
docker run --name "${CDIST_TRIGGER_CONTAINER_NAME:-trigger}" \
			--network="${DOCKER_NETWORK_NAME:-ethz-scientific}" \
			--network-alias="$CDIST_TRIGGER_HOSTNAME" \
			--expose "${CDIST_TRIGGER_PORT:-3000}" \
			-d ungleich/ungleich-cdist-trigger \
			--http-port "${CDIST_TRIGGER_PORT:-3000}"

# Creating nginx container
docker run --name "${NGINX_CONTAINER_NAME:-nginx}" \
			--network="${DOCKER_NETWORK_NAME:-ethz-scientific}" \
			--network-alias="$NGINX_HOSTNAME" \
			-v "$NGINX_LOCAL_FILES_PATH":/usr/share/nginx/html:ro \
			-d nginx:stable
