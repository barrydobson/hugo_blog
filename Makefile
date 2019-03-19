
hugoversion ?= 0.54.0

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	
run_ghost_migrate: ## Run a container to help migrate Ghost to Hugo
	@echo "Starting Ghost Migrate Container"
	docker run --rm -v `pwd`:/pwd/ -p 1313:1313/tcp -it -w '/pwd/Ghost' ghostmigrate

new-post: ## Make a new post
	test $(name)
	@docker-compose build hugo
	@docker-compose run --rm --entrypoint "hugo new post/$(name).md" hugo

run: ## Run server locally
	@docker-compose build hugo
	@docker-compose run --rm --service-ports --entrypoint "hugo server -D --enableGitInfo --bind \"0.0.0.0\"" hugo

build: ## Build for deployment
	@docker-compose build hugo
	@docker-compose run --rm --entrypoint "hugo --enableGitInfo" hugo