.PHONY: build test run clean lint format resolve

# Default Xcode toolchain — override with XCODE_PATH if needed
SCHEME = Transcribo
CONFIGURATION = Debug

# --- SPM commands (work without .xcodeproj) ---

build:
	swift build

test:
	swift test

run:
	swift run Transcribo

clean:
	swift package clean
	rm -rf .build DerivedData

resolve:
	swift package resolve

# --- Xcode commands (require .xcodeproj or Package.swift open in Xcode) ---

xcode-build:
	xcodebuild build \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS'

xcode-test:
	xcodebuild test \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS'

xcode-archive:
	xcodebuild archive \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath build/Transcribo.xcarchive \
		-destination 'platform=macOS'

# --- Linting ---

lint:
	swiftlint lint --strict

format:
	swiftlint lint --fix
