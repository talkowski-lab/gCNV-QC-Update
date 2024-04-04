VERSION ::= 0.0.2

.PHONY: docker

docker: Dockerfile
	docker build --tag gcnv-qc-update:$(VERSION) .
