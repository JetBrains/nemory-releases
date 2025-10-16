#!/usr/bin/env sh

set -e
# Parse flags for this script
DONT_MODIFY_PATH=false
for arg in "$@"; do
  if [ "$arg" = "--dont-modify-path" ]; then
    DONT_MODIFY_PATH=true
    break
  fi
done

CURRENT_DIR=$(cd -P "$(dirname "$0")" 2>/dev/null && pwd)

add_nemory_to_path_if_needed() {
    NEMORY_BIN_DIR="$CURRENT_DIR/cli/bin"
    if [ "$DONT_MODIFY_PATH" = true ]; then
      echo "PATH will not be modified, make sure to add $NEMORY_BIN_DIR to your PATH variable"
      exit 0
    fi

    # Choose shell rc file: prefer zsh if detected/present, else bash
    RC_FILE="$HOME/.bashrc"
    if [ -n "$SHELL" ] && echo "$SHELL" | grep -q "zsh"; then
      RC_FILE="$HOME/.zshrc"
    elif [ -f "$HOME/.zshrc" ]; then
      RC_FILE="$HOME/.zshrc"
    fi
    if grep -q "$NEMORY_BIN_DIR" "$RC_FILE" >/dev/null 2>&1; then
      echo "$NEMORY_BIN_DIR is already in the PATH"
      exit 0
    fi
    echo "Attempting to add nemory to PATH in $RC_FILE..."
    cat >> "$RC_FILE" <<EOF
# Adding nemory to the PATH
export PATH=\$PATH:$NEMORY_BIN_DIR
EOF
    echo "Added PATH update to $RC_FILE. Restart your shell or 'source' the file to use 'nemory'."
}

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
    add_nemory_to_path_if_needed
else
    echo "Error: Extraction failed"
    exit 1
fi
