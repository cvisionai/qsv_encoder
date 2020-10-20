.PHONY: build
build: Dockerfile
	docker build -t qsv_encoder .

.PHONY: run
run: 
	docker run --rm -ti --device=/dev/dri:/dev/dri qsv_encoder
