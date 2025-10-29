#!/bin/bash
# Reset macOS permissions for EasyDemo
# Run this if you're having permission issues

echo "Resetting EasyDemo permissions..."

tccutil reset Camera com.easydemo
tccutil reset Microphone com.easydemo
tccutil reset ScreenCapture com.easydemo

echo ""
echo "✅ Permissions reset successfully!"
echo ""
echo "Next steps:"
echo "1. Clean and rebuild the app in Xcode"
echo "2. Quit EasyDemo if it's running"
echo "3. Launch the app fresh from Xcode"
echo "4. You should see the permission dialogs when you enable webcam/recording"
