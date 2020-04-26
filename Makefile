.PHONY: docs

ci: test

test: lint
	@crystal spec

lint: bin/ameba
	@bin/ameba

docs:
	@crystal doc

# Run this to initialize your development environment
install:
	shards

bin/ameba:
	@make install

