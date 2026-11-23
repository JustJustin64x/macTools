.PHONY: build app install run test check
build:
	swift build
app:
	./scripts/build-app.sh
install:
	./scripts/install.sh
run:
	open "$(HOME)/Applications/macTools.app"
test:
	swift run MacToolsCoreTests
	swift run macTools --self-test
check:
	"$(HOME)/Applications/macTools.app/Contents/Helpers/finder_keys" --check
