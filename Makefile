brew_cmd = brew
bundle_cmd = ./vendor/bundle/gems/bundler-2.2.33/exe/bundle
gem_cmd = gem
bundle_gem = "bundler:2.2.33"
vendor_path = ./vendor/bundle
beautify_cmd = ./Pods/xcbeautify/xcbeautify
curl_cmd = /usr/bin/curl
compress_cmd = ./scripts/compress_chains
iphone_destination ?= iPhone 12 Pro
test14_target ?= 14.5
test15_target ?= 15.2

all: target
	@echo
	@echo "Please specify a target."
	@echo "iPhone destination is set to $(iphone_destination)."

target:
	@echo "install_bundle       : install the correct version of bundle."
	@echo "install_gems         : install all the required gems."
	@echo "install_pods         : install all the cocoapods."
	@echo "install_all          : install gems then pods."
	@echo "check_gems           : check to see if all the gems in the Gemfile are installed in the vendor directory."
	@echo "bootstrap            : install bundle followed by install all."
	@echo "test14               : run tests for iOS $(test14_target)."
	@echo "test15               : run tests for iOS $(test15_target)."
	@echo "test                 : run the tests for latest iOS."
	@echo "clean                : remove all the pods and gems and source clean the code."
	@echo "remove_installed_dir : remove the installed pod and gems."
	@echo "source_clean         : clean the source code of AlphaWallet for latest iOS."
	@echo "source_clean14       : clean the source code of AlphaWallet for $(test14_target)."
	@echo "source_clean15       : clean the source code of AlphaWallet for $(test15_target)."
	@echo "source_clean_all     : clean the source code of AlphaWallet for $(test14_target), $(test15_target), and latest."
	@echo "update_chains_file   : update the chains.zip file in the project."

check_brew:
	@$(brew_cmd) --version 1>/dev/null 2>/dev/null; \
	if [ $$? -ne 0 ]; then \
		echo "Homebrew is not installed. Please install Homebrew."; \
		exit 1; \
	fi

check_bundle:
	@$(bundle_cmd) --version 1>/dev/null 2>/dev/null; \
	if [ $$? -ne 0 ]; then \
		echo "Bundle does not exist. Please install bundle."; \
		exit 1; \
	fi

check_gems: check_bundle setup_path
	@$(bundle_cmd) check --gemfile=./Gemfile; \
	if [ $$? -eq 0 ]; then \
		echo "All gems installed."; \
	else \
		echo "Some or all gemfiles have not been installed. Please use 'make install_gems'."; \
		exit 1; \
	fi

check_beautify_cmd:
	@$(beautify_cmd) --version 1>/dev/null 2>/dev/null; \
        if [ $$? -ne 0 ]; then \
                echo "Beautify command is not installed. Please run make bootstrap."; \
                exit 1; \
        fi

install_gems: check_bundle setup_path
	@$(bundle_cmd) install --jobs=4; \
	if [ $$? -ne 0 ]; then \
		echo "Error installing."; \
		exit 1; \
	else \
		echo "All gems installed."; \
	fi

install_pods: check_gems
	@$(bundle_cmd) exec pod install; \
	if [ $$? -eq 0 ]; then \
		echo "All pods installed."; \
	else \
		echo "Error installing."; \
		exit 1; \
	fi

update_pods: check_gems
	@$(bundle_cmd) exec pod update; \
	if [ $$? -eq 0 ]; then \
		echo "All pods updated."; \
	else \
		echo "Error updating."; \
		exit 1; \
	fi

bootstrap: install_bundle install_all

install_all: setup_path install_gems install_pods

clean: remove_installed_dir source_clean_all

remove_installed_dir:
	rm -rf $(vendor_path)
	rm -rf ./Pods/*

source_clean:
	@xcodebuild -quiet -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=latest' clean

source_clean14:
	@xcodebuild -quiet -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=$(test14_target)' clean

source_clean15:
	@xcodebuild -quiet -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=$(test15_target)' clean

source_clean_all: source_clean source_clean14 source_clean15

release:
	fastlane release

setup_path:
	@$(bundle_cmd) config path $(vendor_path)

install_bundle:
	@$(gem_cmd) install --install-dir=$(vendor_path) $(bundle_gem)

test15: check_beautify_cmd
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=$(test15_target)' test | $(beautify_cmd)

test14: check_beautify_cmd
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=$(test14_target)' test | $(beautify_cmd)

test_latest:
	@xcodebuild -disableAutomaticPackageResolution -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=latest' test | $(beautify_cmd)

test: test_latest

build_and_run_booted: check_beautify_cmd
	#The simulator "name" specified doesn't matter
	@xcrun xcodebuild -disableAutomaticPackageResolution -scheme AlphaWallet -workspace AlphaWallet.xcworkspace -configuration Debug -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=15.4' -derivedDataPath ./build | $(beautify_cmd)
	@xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/AlphaWallet.app
	@xcrun simctl launch booted com.stormbird.alphawallet

build: check_beautify_cmd
	@xcodebuild -workspace AlphaWallet.xcworkspace -scheme AlphaWallet -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(iphone_destination),OS=latest' build | $(beautify_cmd)

update_chains_file:
	@echo "Deleting chains file in scripts folder."
	@rm -f ./scripts/chains.json
	@rm -f ./scripts/chains.json.zip
	@echo "Downloading chains file."
	@$(curl_cmd) --output ./scripts/chains.json https://chainid.network/chains.json
	@echo "Compressing."
	@$(compress_cmd)
	@echo "Moving compressed file into project."
	@mv scripts/chains.json.zip AlphaWallet/Rpc\ Network/chains.zip
	@rm -f ./scripts/chains.json
	@echo "Update completed."

