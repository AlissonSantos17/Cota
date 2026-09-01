.PHONY: test build format lint rebuild

test:
	./scripts/test.sh

build:
	swift build

format:
	./scripts/format.sh

lint:
	./scripts/lint.sh

rebuild:
	./rebuild.sh
