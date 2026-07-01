BUILD := build

.PHONY: all app bundle bridge run install install-bridge test lint format clean

all: bundle bridge

app bundle:
	./scripts/bundle.sh

bridge:
	swift build --package-path bridge -c release
	@mkdir -p $(BUILD)
	@cp "$$(swift build --package-path bridge -c release --show-bin-path)/orca" $(BUILD)/orca
	@echo "==> bridge -> $(BUILD)/orca"

run: bundle
	open build/Orca.app

install:
	./scripts/dev-install.sh

install-bridge: bridge
	@mkdir -p $$HOME/.local/bin
	cp $(BUILD)/orca $$HOME/.local/bin/orca
	@echo "==> installed to ~/.local/bin/orca (ensure it is on PATH)"

test:
	swift test --package-path app
	swift test --package-path bridge

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo "swiftlint not found: brew install swiftlint"; exit 1; }
	swiftlint lint --config .swiftlint.yml

format:
	@command -v swiftformat >/dev/null 2>&1 || { echo "swiftformat not found: brew install swiftformat"; exit 1; }
	swiftformat . --config .swiftformat

clean:
	rm -rf build dist app/.build bridge/.build
