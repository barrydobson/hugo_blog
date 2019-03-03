.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

build_image:
	@echo "Building docker image"
	docker build -t hugo:0.54.0 .

run_hugo:
	@echo "Starting Hugo Container"
	docker run --rm -v `pwd`:/pwd/ -p 1313:1313/tcp -it -w '/pwd/barrydobson' hugo:0.54.0
	
run_ghost_migrate:
	@echo "Starting Ghost Migrate Container"
	docker run --rm -v `pwd`:/pwd/ -p 1313:1313/tcp -it -w '/pwd/Ghost' ghostmigrate
