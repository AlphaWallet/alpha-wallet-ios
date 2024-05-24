beautify_cmd = ./Pods/xcbeautify/xcbeautify
curl_cmd = /usr/bin/curl
compress_cmd = ./scripts/compress_chains

default: generate_project

generate_project:
	touch ./AlphaWallet/R.generated.swift
	xcodegen
	bundle exec pod install

bootstrap: install_xcodegen install_gems generate_project

all: help

help:
	@echo "default            : generate the project and workspace files. Use after adding/removing/moving files"
	@echo "bootstrap          : usually just use right after cloning the repo"
	@echo "install_gems       : run after updating Gemfile"
	@echo "install_pods       : run after updating Podfile"
	@echo "test14             : run tests for iOS 14.5."
	@echo "test15             : run tests for iOS 15.2."
	@echo "test               : run the tests for latest iOS (15.2)."
	@echo "update_chains_file : update the chains.zip file in the project."

install_xcodegen:
	brew install xcodegen

install_gems:
	bundle

install_pods:
	bundle exec pod install

test15:
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12,OS=15.4' test | $(beautify_cmd)

test14:
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12,OS=14.5' test | $(beautify_cmd)

test_latest:
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12,OS=latest' test | $(beautify_cmd)

test: test_latest

build_and_run_booted:
	#The simulator "name" specified doesn't matter
	@xcrun xcodebuild -disableAutomaticPackageResolution -scheme AlphaWallet -workspace AlphaWallet.xcworkspace -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 12 Pro,OS=15.4' -derivedDataPath ./build | $(beautify_cmd)
	@xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/AlphaWallet.app
	@xcrun simctl launch booted com.stormbird.alphawallet

update_chains_file:
	@echo "Deleting chains file in scripts folder."
	@rm -f ./scripts/chains.json
	@rm -f ./scripts/chains.json.zip
	@echo "Downloading chains file."
	@$(curl_cmd) --output ./scripts/chains.json https://chainid.network/chains.json
	@echo "Compressing."
	@$(compress_cmd)
	@echo "Moving compressed file into project."
	@mv scripts/chains.json.zip AlphaWallet/Resources/chains.zip
	@rm -f ./scripts/chains.json
	@echo "Update completed."

