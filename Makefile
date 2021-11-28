bundle_cmd = /usr/bin/Bundle
vendor_path = ./vendor/bundle

all: target
	@echo "Please specify a target. Please use 'make target' to show targets."

target:
	@echo "install_gems : install or update all the required gems."
	@echo "install_pods : install or update all the cocoapods."
	@echo "install_all  : install gems then pods."
	@echo "check_gems   : check to see if all the gems in the Gemfile are installed in the vendor directory."
	@echo "bootstrap    : same as make install_all"
	@echo "update_pods  : update all the cocoapods."

check_bundle:
	@$(bundle_cmd) --version 1>/dev/null 2>/dev/null; \
	if [ $$? -ne 0 ]; then \
		echo "Bundle does not exist. Please install bundle."; \
		exit 1; \
	fi

check_gems: check_bundle
	@$(bundle_cmd) check --gemfile=./Gemfile --path=$(vendor_path); \
	if [ $$? -eq 0 ]; then \
		echo "All gems installed."; \
	else \
		echo "Some or all gemfiles have not been installed. Please use 'make install_gems'."; \
		exit 1; \
	fi

install_gems: check_bundle
	@$(bundle_cmd) install --path=$(vendor_path); \
	if [ $$? -ne 0 ]; then \
		echo "Error installing."; \
		exit 1; \
	else \
		echo "All gems installed."; \
	fi

install_pods: check_gems
	@$(bundle_cmd) exec pod install --repo-update; \
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

bootstrap: install_all

install_all: install_gems install_pods

clean:
	rm -rf $(vendor_path)
	rm -rf ./Pods/*

release:
	fastlane release
