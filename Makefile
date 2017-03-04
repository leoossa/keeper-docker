.SILENT :
.PHONY : help up down wait config config-keycloak restart logs

# Get Makefile root dir
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

## This help screen
help:
	printf "Available targets:\n\n"
	awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-15s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Wait until a service ($$service) is up and running (needs health run flag)
wait:
	sid=`docker-compose ps -q $(service)`;\
	n=30;\
	while [ $${n} -gt 0 ] ; do\
		status=`docker inspect --format "{{json .State.Health.Status }}" $${sid}`;\
		if [ -z $${status} ]; then echo "No status informations."; exit 1; fi;\
		echo "Waiting for $(service) up and ready ($${status})...";\
		if [ "\"healthy\"" = $${status} ]; then exit 0; fi;\
		sleep 2;\
		n=`expr $$n - 1`;\
	done;\
	echo "Timeout" && exit 1

## Configure keycloak
config-keycloak:
	docker run --rm -it \
		--entrypoint=/bin/bash \
		--env-file=$(ROOT_DIR)/etc/keycloak.env \
		-u root:root \
		-v $(ROOT_DIR)/bin/setup-keycloak.sh:/opt/jboss/setup.sh \
		-v $(ROOT_DIR)/var/config:/opt/jboss/output \
		jboss/keycloak:latest \
		/opt/jboss/setup.sh

## Config a service ($$service)
config: wait
	echo "Configuring $(service)..."
	$(MAKE) config-$(service)

## Restart a service ($$service)
restart:
	echo "Restarting service: $(service) ..."
	docker-compose \
		-f docker-compose.yml \
		-f docker-compose.app.yml \
		restart $(service)

## View service logs ($$service)
logs:
	echo "Restarting service: $(service) ..."
	docker-compose \
		-f docker-compose.yml \
		-f docker-compose.app.yml \
		logs $(service)

## Build Web App
build-webapp:
	echo "Building Web App..."
	docker run --rm -it \
		--env-file=$(ROOT_DIR)/etc/keeper-web-app.env \
		-u root:root \
		-v $(ROOT_DIR)/var/config/keycloak.json:/usr/src/app/public/keycloak.json \
		-v $(ROOT_DIR)/var/www:/usr/src/app/build \
		ncarlier/keeper-web-app:latest \
		run build

## Setup infrastructure
up:
	echo "Setup Nunux Keeper..."
	docker-compose up -d
	$(MAKE) config service=keycloak
	$(MAKE) build-webapp
	docker-compose \
		-f docker-compose.yml \
		-f docker-compose.app.yml \
		up -d
	echo "Congrats! Nunux Keeeper up and running."

## Teardown infrastructure
down:
	echo "Teardown Nunux Keeper..."
	docker-compose \
		-f docker-compose.yml \
		-f docker-compose.app.yml \
		down
	echo "Nunux Keeeper stopped and removed:"
	echo ".var/ directory still contains generated data."
	echo "Manualy remove it if you want to start a fresh installation."
