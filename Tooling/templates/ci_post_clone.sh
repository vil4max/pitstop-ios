#!/bin/sh
# Installed by ios-agent-toolchain (docs/ci.md). Copy to ci_scripts/ci_post_clone.sh
# next to the .xcodeproj; Xcode Cloud runs it after cloning.
set -e

# Xcode Cloud's build number wins: every TestFlight round gets a unique
# CURRENT_PROJECT_VERSION without a build-number commit (docs/testflight.md).
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "==> CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
    find "$CI_PRIMARY_REPOSITORY_PATH" -name project.pbxproj -not -path '*/Pods/*' \
        -exec sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/g" {} +
    # Xcode 27.2's JSON format: "CURRENT_PROJECT_VERSION" or "CURRENT_PROJECT_VERSION[config=…]".
    find "$CI_PRIMARY_REPOSITORY_PATH" -name project.xcproj -not -path '*/Pods/*' \
        -exec sed -i '' -E "s/(\"CURRENT_PROJECT_VERSION(\[[^]\"]*\])?\"[[:space:]]*:[[:space:]]*)(\"?)[0-9]+\"?/\1\3$CI_BUILD_NUMBER\3/g" {} +
fi

# Xcode Cloud cannot answer the one-time "Trust & Enable" dialog for SwiftPM
# build-tool plugins and macros, so it refuses them unless validation is skipped.
# Harmless for an app without plugins.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
