include .envrc

# ==================================================================================== # 
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo 'Are you sure? [y/N] \c' && read ans && [ $${ans:-N} = y ]

# ==================================================================================== # 
# DEVELOPMENT
# ==================================================================================== #

# it’s possible to suppress commands from being echoed by prefixing 
# them with the @ character -> @go run ./cmd/web
## run/web: run the cmd/web application
.PHONY: run/web
run/web:
	@go run ./cmd/web -dsn=${THEBESTDEAL_DB_DSN}

## db/mysql: connect to the database using psql
.PHONY: db/mysql
db/mysql:
	mysql -D ${THEBESTDEAL_DB_NAME} --user=${THEBESTDEAL_DB_USER} --password=${THEBESTDEAL_DB_PASSWORD}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/migrations/new
db/migrations/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migrations/up: apply all up database migrations
.PHONY: db/migrations/up
db/migrations/up: confirm
	@echo 'Running up migrations...'
	migrate -path ./migrations -database ${THEBESTDEAL_DB_URL} up

## db/migrations/down: roll-back all database migrations
.PHONY: db/migrations/down
db/migrations/down: confirm
	@echo 'Running down migrations...'
	migrate -path ./migrations -database ${THEBESTDEAL_DB_URL} down

# ==================================================================================== # 
# QUALITY CONTROL
# ==================================================================================== #

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit 
audit: vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

## vendor: tidy and vendor dependencies
.PHONY: vendor 
vendor:
	@echo 'Tidying and verifying module dependencies...' 
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies...'
	go mod vendor

# ==================================================================================== # 
# BUILD
# ==================================================================================== #

# current_time = $(shell date --iso-8601=seconds)
current_time = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
git_description = $(shell git describe --always --dirty --tags --long)
linker_flags = '-s -X main.buildTime=${current_time} -X main.version=${git_description}'

# reduce the binary size by around 25% by instructing the Go linker to strip 
# the DWARF debugging information and symbol table from the binary -> -ldflags='-s'
## build/web: build the cmd/web application
.PHONY: build/web
build/web:
	@echo 'Building cmd/web...'
	go build -ldflags=${linker_flags} -o=./bin/web ./cmd/web
	GOOS=linux GOARCH=amd64 go build -ldflags=${linker_flags} -o=./bin/linux_amd64/web ./cmd/web

# ==================================================================================== # 
# PRODUCTION
# ==================================================================================== #

production_host_user = 'thebestdeal'
production_host_ip = '192.168.56.14'

## production/connect: connect to the production server
.PHONY: production/connect 
production/connect:
	ssh ${production_host_user}@${production_host_ip}

## production/setup/ssh: setup the production server ssh public key
.PHONY: production/setup/ssh 
production/setup/ssh:
	ssh-add -D
	ssh-keygen -R ${production_host_ip}
	ssh-add ~/.ssh/id_rsa_thebestdeal
	ssh-copy-id root@${production_host_ip}

## production/setup/service: setup the production server
.PHONY: production/setup/service 
production/setup/service:
	rsync -rP --delete ./remote/setup root@${production_host_ip}:/root
	ssh -t root@${production_host_ip} "bash /root/setup/01.sh"

## production/configure/web.service: configure the production systemd web.service file
.PHONY: production/configure/web.service 
production/configure/web.service:
	rsync -P ./remote/production/web.service ${production_host_user}@${production_host_ip}:~ 
	ssh -t ${production_host_user}@${production_host_ip} '\
	sudo mv ~/web.service /etc/systemd/system/ \ 
	&& sudo restorecon -v /etc/systemd/system/web.service \
	&& sudo systemctl daemon-reload \
	&& sudo systemctl enable web \
	&& sudo systemctl restart web \
	'

## production/configure/caddyfile: configure the production Caddyfile
.PHONY: production/configure/caddyfile 
production/configure/caddyfile:
	rsync -P ./remote/production/Caddyfile ${production_host_user}@${production_host_ip}:~ 
	ssh -t ${production_host_user}@${production_host_ip} '\
	sudo mv ~/Caddyfile /etc/caddy/ \
	&& sudo systemctl reload caddy \ 
	'

## production/deploy/web: deploy the web application to production
.PHONY: production/deploy/web 
production/deploy/web:
	rsync -rP --delete ./bin/linux_amd64/web ./migrations ${production_host_user}@${production_host_ip}:~
	ssh -t ${production_host_user}@${production_host_ip} 'migrate -path ~/migrations -database $$THEBESTDEAL_DB_URL up'

## production/deploy/all: deploy the application to production and configure the production files
.PHONY: production/deploy/all 
production/deploy/all:
	rsync -rP --delete ./bin/linux_amd64/web ./migrations ${production_host_user}@${production_host_ip}:~
	rsync -P ./remote/production/web.service ${production_host_user}@${production_host_ip}:~
	rsync -P ./remote/production/Caddyfile ${production_host_user}@${production_host_ip}:~
	ssh -t ${production_host_user}@${production_host_ip} '\
	migrate -path ~/migrations -database $$THEBESTDEAL_DB_URL up \
	&& sudo mv ~/web.service /etc/systemd/system/ \
	&& sudo restorecon -v /etc/systemd/system/web.service \
	&& sudo systemctl daemon-reload \
	&& sudo systemctl enable web.service \
	&& sudo systemctl restart web.service \
	&& sudo mv ~/Caddyfile /etc/caddy/ \
	&& sudo systemctl reload caddy \
	'

## production/deploy/all: deploy the application to production and configure the production files
# .PHONY: production/deploy/all 
# production/deploy/all:
# 	rsync -rP --delete ./bin/linux_amd64/web ./migrations ${production_host_user}@${production_host_ip}:~
# 	rsync -P ./remote/production/web.service ${production_host_user}@${production_host_ip}:~
# 	rsync -P ./remote/production/Caddyfile ${production_host_user}@${production_host_ip}:~
# 	ssh -t ${production_host_user}@${production_host_ip} '\
# 	migrate -path ~/migrations -database $$THEBESTDEAL_DB_URL up \
# 	&& sudo mv ~/web.service /etc/systemd/system/ \
# 	&& sudo systemctl daemon-reload \
#   && sudo setenforce 0 \
# 	&& sudo systemctl enable /etc/systemd/system/web.service \
# 	&& sudo systemctl restart /etc/systemd/system/web.service \
# 	&& sudo mv ~/Caddyfile /etc/caddy/ \
# 	&& sudo systemctl reload caddy \
# 	'