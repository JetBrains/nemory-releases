#!/usr/bin/env bash

set -e

echo "Downloading latest Nemory release..."

# GitHub repository
REPO="JetBrains/nemory-releases"
FILENAME="cli.tar"

# Get the latest release URL
LATEST_RELEASE_URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep "browser_download_url.*${FILENAME}" | cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "Error: Could not find ${FILENAME} in the latest release"
    exit 1
fi

echo "Downloading from: ${LATEST_RELEASE_URL}"

# Download the file
curl -L -o "${FILENAME}" "${LATEST_RELEASE_URL}"

if [ ! -f "${FILENAME}" ]; then
    echo "Error: Download failed"
    exit 1
fi

echo "Download completed successfully"
echo "Extracting ${FILENAME}..."

tar -xf "${FILENAME}"

if [ $? -eq 0 ]; then
    echo "Extraction completed successfully"
    echo "Cleaning up..."
    rm "${FILENAME}"
    echo "Installation complete!"
else
    echo "Error: Extraction failed"
    exit 1
fi
