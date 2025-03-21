#!/bin/bash
set -e

# This script generates a version string based on git information
# It can be used in CI/CD pipelines to automatically version builds

# Check if we're in a git repository
if [ ! -d .git ]; then
  echo "Error: Not a git repository" >&2
  exit 1
fi

# Get the most recent tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# Get number of commits since tag
COMMITS_SINCE_TAG=$(git rev-list ${LATEST_TAG}..HEAD --count)

# Get short commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)

# If we have commits since the tag, create a pre-release version
if [ "$COMMITS_SINCE_TAG" -gt "0" ]; then
  # Format: v1.0.0-5-g3d4d2a (tag-commits-hash)
  VERSION="${LATEST_TAG}-${COMMITS_SINCE_TAG}-${COMMIT_HASH}"
else
  # If we're exactly on a tag, use that
  VERSION="${LATEST_TAG}"
fi

# Output the version
echo "$VERSION"

# Optionally set environment variable if requested
if [ "$1" = "--export" ]; then
  echo "VERSION=$VERSION" >> $GITHUB_ENV
fi