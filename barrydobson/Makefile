.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

new_post:
	@echo "Making new Post"
	test $(name)
	hugo new post/$(name).md

start_server:
	@echo "Starting Hugo"
	hugo server -D --bind "0.0.0.0"

build_site:
	@echo "Building site"
	hugo