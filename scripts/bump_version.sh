#!/bin/bash
set -e

INPUT="${1:-patch}"

# Get latest version from git tags
get_latest_version() {
    LATEST=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -z "$LATEST" ]; then
        echo "1.0.0"  # Default to 1.0.0 for first release
    else
        echo "${LATEST#v}"  # Remove 'v' prefix
    fi
}

# Check if input is a custom version (contains dots)
if [[ "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    NEW_VERSION="$INPUT"
else
    CURRENT=$(get_latest_version)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

    case "$INPUT" in
        major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
        minor) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
        patch) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
        none)  NEW_VERSION="$CURRENT" ;;
        *)     echo "Invalid input: $INPUT"; exit 1 ;;
    esac
fi

BUILD_NUMBER=$(date +%s)

echo "Version: $NEW_VERSION (Build: $BUILD_NUMBER)"

# Export for GitHub Actions
[ -n "$GITHUB_ENV" ] && echo "VERSION_NUMBER=$NEW_VERSION" >> "$GITHUB_ENV"
[ -n "$GITHUB_ENV" ] && echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"

echo "$NEW_VERSION"
