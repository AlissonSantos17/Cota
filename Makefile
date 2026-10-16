.PHONY: test build format lint rebuild icon dmg

test:
	./scripts/test.sh

build:
	swift build $$(./scripts/sdk-flags.sh)

format:
	./scripts/format.sh

lint:
	./scripts/lint.sh

rebuild:
	./rebuild.sh

icon:
	./scripts/make-icon.sh

dmg:
	./scripts/make-dmg.sh
