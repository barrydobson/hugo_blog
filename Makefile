
build_image:
	@echo "Building docker image"
	docker build -t hugo:0.54.0 .

run_hugo:
	@echo "Starting Hugo Container"
	docker run --rm -v `pwd`:/pwd/ -p 1313:1313/tcp -it -w '/pwd/barrydobson' hugo:0.54.0
	
