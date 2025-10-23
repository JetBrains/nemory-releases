#!/usr/bin/env sh

need_major=4
need_minor=2
is_modern_bash() {
  local major=${BASH_VERSINFO[0]:-0}
  local minor=${BASH_VERSINFO[1]:-0}
  (( major > need_major )) || { (( major == need_major )) && (( minor >= need_minor )); }
}

find_modern_bash() {
  # Try common locations + brew prefix, if available
  local candidates
  candidates="/opt/homebrew/bin/bash /usr/local/bin/bash"
  if command -v brew >/dev/null 2>&1; then
    candidates="$candidates $(brew --prefix 2>/dev/null)/bin/bash"
  fi
  for nb in $candidates; do
    [ -x "$nb" ] || continue
    if "$nb" -c '(( BASH_VERSINFO[0] > 4 )) || (( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2 ))' >/dev/null 2>&1; then
      echo "$nb"
      return 0
    fi
  done
  return 1
}

ensure_modern_bash() {
  if is_modern_bash; then
    return 0
  fi

  if [[ "$OSTYPE" == darwin* ]]; then
    # If a suitable bash is already on disk, use it
    if nb="$(find_modern_bash)"; then
      exec "$nb" "$0" "$@"
    fi

    # Try to install/upgrade via Homebrew
    if command -v brew >/dev/null 2>&1; then
      echo "Bash >= 4.2 required (found: ${BASH_VERSION:-unknown})."
      echo "Attempting to install/upgrade Bash via Homebrew..."
      # If not installed, install; otherwise upgrade (no-op if current)
      if ! brew list bash >/dev/null 2>&1; then
        brew install bash || { echo "Homebrew install failed."; exit 1; }
      else
        brew upgrade bash || true
      fi

      # Re-scan for the modern bash and exec
      if nb="$(find_modern_bash)"; then
        echo "Using Bash at: $nb"
        exec "$nb" "$0" "$@"
      fi

      # Give PATH help if we still can’t find it
      echo "Bash installed but not found on PATH."
      echo "Try: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
      echo "Then re-run: \"\$(brew --prefix)/bin/bash\" \"$0\" $*"
      exit 1
    else
      echo "Bash >= 4.2 required (found: ${BASH_VERSION:-unknown})."
      echo "Homebrew not found. Install Homebrew from https://brew.sh then run: brew install bash"
      exit 1
    fi
  fi
}

ensure_modern_bash "$@"


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

# === Terms of Service agreement ===
TERMS_URL="https://www.jetbrains.com/legal/docs/terms/jetbrains-eap-nemory/"
echo
echo "By continuing, you agree to our Terms and Conditions."
echo "See: $TERMS_URL"
printf "Do you want to continue? [Yes (default)/No]: "
read -r REPLY </dev/tty

REPLY=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')

if [ "$REPLY" = "no" ] || [ "$REPLY" = "n" ]; then
  echo "Installation aborted."
  exit 1
fi

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
