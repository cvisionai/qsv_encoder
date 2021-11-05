.PHONY: build
build: Dockerfile
	docker build -t cvisionai/qsv_encoder .

.PHONY: build_shared
build_shared: Dockerfile
	docker build -t cvisionai/qsv_shared -f shared.dockerfile .


.PHONY: run
run: 
	docker run --rm -ti --device=/dev/dri:/dev/dri cvisionai/qsv_encoder
