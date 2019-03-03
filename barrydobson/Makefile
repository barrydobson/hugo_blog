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