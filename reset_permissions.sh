#!/bin/bash
# Reset macOS permissions and user configurations for EasyDemo
# Run this if you're having permission issues or want a fresh first-run

set -e

BUNDLE_ID="com.easydemo"

echo "Resetting EasyDemo permissions and preferences..."

echo "- Resetting TCC permissions (Camera/Microphone/ScreenCapture)"
tccutil reset Camera "$BUNDLE_ID" || true
tccutil reset Microphone "$BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" || true

echo "- Clearing app UserDefaults flags"
defaults delete "$BUNDLE_ID" screenRecordingPermissionAttempted 2>/dev/null || true
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo "- Flushing preferences cache"
killall cfprefsd 2>/dev/null || true

echo "- Removing preference plist files (if present)"
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist" 2>/dev/null || true
rm -f "$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Preferences/$BUNDLE_ID.plist" 2>/dev/null || true

echo ""
echo "✅ Permissions and app preferences reset successfully!"
echo ""
echo "Next steps:"
echo "1. Quit EasyDemo if it's running"
echo "2. Clean and rebuild the app in Xcode"
echo "3. Launch the app fresh from Xcode"
echo "4. Go through onboarding and re-trigger prompts"
