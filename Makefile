.PHONY: build app install run test check update check-updates
build:
	swift build
app:
	./scripts/build-app.sh
install:
	./scripts/install.sh
run:
	open /Applications/macTools.app
test:
	swift build --product MacToolsUpdate
	swift run MacToolsCoreTests
	swift run macTools --self-test
check:
	"$(HOME)/Applications/macTools.app/Contents/Helpers/finder_keys" --check

update:
	"$(HOME)/Applications/macTools.app/Contents/Helpers/macToolsUpdate"
check-updates:
	"$(HOME)/Applications/macTools.app/Contents/Helpers/macToolsUpdate" --check
