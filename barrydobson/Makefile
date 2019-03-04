# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
post: ## Create a new post. set name={name of post}
	@echo "Making new Post"
	test $(name)
	hugo new post/$(name).md

start: ## Start the hugo local server with drafts
	@echo "Starting Hugo"
	hugo server -D --enableGitInfo --bind "0.0.0.0"

build: ## Build the site and output to public folder
	@echo "Building site"
	hugo --enableGitInfo