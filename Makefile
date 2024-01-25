.PHONY: docker

docker: Dockerfile
	docker build --tag gcnv-qc-update .
