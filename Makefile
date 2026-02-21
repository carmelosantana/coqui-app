.PHONY: help setup deps icons splash pods-ios pods-macos pods clean \
       ios-debug ios-release ios-ipa ios-open \
	macos-debug macos-release macos-open \
	android-debug android-release android-install android-launch android-avds android-emulator \
       doctor test

# Default target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Setup & Dependencies ──────────────────────────────────────────────

setup: doctor deps icons splash pods ## Full first-time setup (run this first)

doctor: ## Check Flutter environment
	flutter doctor -v

deps: ## Install Flutter dependencies
	flutter pub get

icons: ## Regenerate app icons for all platforms
	dart run flutter_launcher_icons

splash: ## Regenerate splash screens
	dart run flutter_native_splash:create

# ─── CocoaPods ──────────────────────────────────────────────────────────

pods-ios: ## Install iOS CocoaPods
	cd ios && rm -f Podfile.lock && pod install --repo-update

pods-macos: ## Install macOS CocoaPods
	cd macos && rm -f Podfile.lock && pod install --repo-update

pods: pods-ios pods-macos ## Install CocoaPods for both platforms

clean-pods: ## Remove CocoaPods artifacts and reinstall
	cd ios && rm -rf Pods Podfile.lock && pod install --repo-update
	cd macos && rm -rf Pods Podfile.lock && pod install --repo-update

# ─── iOS Builds ─────────────────────────────────────────────────────────

ios-debug: ## Build iOS debug (for connected device)
	flutter build ios --debug

ios-release: ## Build iOS release
	flutter build ios --release

ios-ipa: ## Build iOS IPA for App Store / TestFlight
	flutter build ipa --release

ios-open: ## Open iOS project in Xcode
	open ios/Runner.xcworkspace

# ─── macOS Builds ───────────────────────────────────────────────────────

macos-debug: ## Build macOS debug
	flutter build macos --debug

macos-release: ## Build macOS release
	flutter build macos --release

macos-open: ## Open macOS project in Xcode
	open macos/Runner.xcworkspace

# ─── Android Builds & Device Helpers ────────────────────────────────────

android-debug: ## Build Android debug APK
	flutter build apk --debug

android-release: ## Build Android release App Bundle (.aab)
	flutter build appbundle --release

android-install: ## Install debug APK to connected Android device/emulator
	~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk

android-launch: ## Launch app on connected Android device/emulator
	~/Library/Android/sdk/platform-tools/adb shell monkey -p ai.coquibot.app.debug -c android.intent.category.LAUNCHER 1

android-avds: ## List available Android emulators (AVDs)
	~/Library/Android/sdk/emulator/emulator -list-avds

android-emulator: ## Start Android emulator (set AVD=<name>)
	@if [ -z "$(AVD)" ]; then \
		echo "Usage: make android-emulator AVD=<name>"; \
		exit 1; \
	fi
	~/Library/Android/sdk/emulator/emulator -avd $(AVD)

# ─── Testing ────────────────────────────────────────────────────────────

test: ## Run Flutter tests
	flutter test

# ─── Cleanup ────────────────────────────────────────────────────────────

clean: ## Clean all build artifacts
	flutter clean
	cd ios && rm -rf Pods Podfile.lock
	cd macos && rm -rf Pods Podfile.lock

rebuild: clean setup ## Clean everything and rebuild from scratch
