#!/bin/bash
set -e

# ─── OBS Remote Installer ───────────────────────────────────────────────
# Installs obs-web (local server) and obs-web-companion on macOS.
# Run: cd ~/Downloads/obs-web-installer && bash install.sh
# ─────────────────────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/obs-web-remote"
CONVEX_URL="https://useful-pika-111.convex.cloud"
DEFAULT_OBS_PASSWORD="obsremote"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       OBS Remote Setup Installer     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ─── Detect architecture ────────────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

# ─── Check for Homebrew ─────────────────────────────────────────────────
echo "Checking for Homebrew..."
if ! command -v brew &>/dev/null && [ ! -f "$BREW_PREFIX/bin/brew" ]; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this session
  eval "$($BREW_PREFIX/bin/brew shellenv)"
  echo "Homebrew installed."
else
  # Ensure brew is in PATH
  if ! command -v brew &>/dev/null; then
    eval "$($BREW_PREFIX/bin/brew shellenv)"
  fi
  echo "Homebrew found."
fi

# ─── Check for Node.js ──────────────────────────────────────────────────
echo "Checking for Node.js..."

# Source nvm if present
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
  echo "Node.js not found. Installing via Homebrew..."
  brew install node
  echo "Node.js installed: $(node --version)"
else
  echo "Node.js found: $(node --version)"
fi

# ─── Create install directory ────────────────────────────────────────────
echo ""
echo "Setting up $INSTALL_DIR ..."

if [ -d "$INSTALL_DIR" ]; then
  echo "Existing installation found. Updating..."
  rm -rf "$INSTALL_DIR/obs-web" "$INSTALL_DIR/companion"
else
  mkdir -p "$INSTALL_DIR"
fi

# ─── Copy files ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp -R "$SCRIPT_DIR/obs-web" "$INSTALL_DIR/obs-web"
cp -R "$SCRIPT_DIR/companion" "$INSTALL_DIR/companion"

# ─── Install dependencies ───────────────────────────────────────────────
echo ""
echo "Installing obs-web dependencies..."
cd "$INSTALL_DIR/obs-web"
npm ci --omit=dev

echo ""
echo "Installing companion dependencies..."
cd "$INSTALL_DIR/companion"
npm ci

# ─── Prompt for OBS WebSocket password ──────────────────────────────────
echo ""
read -p "OBS WebSocket password (default: $DEFAULT_OBS_PASSWORD): " OBS_PASSWORD
OBS_PASSWORD="${OBS_PASSWORD:-$DEFAULT_OBS_PASSWORD}"

# ─── Write .env.local for companion ─────────────────────────────────────
cat > "$INSTALL_DIR/companion/.env.local" <<ENVEOF
CONVEX_URL=$CONVEX_URL
ENVEOF

# ─── Write .env.local for obs-web ───────────────────────────────────────
cat > "$INSTALL_DIR/obs-web/.env.local" <<ENVEOF
PUBLIC_CONVEX_URL=$CONVEX_URL
OBS_WS_PASSWORD=$OBS_PASSWORD
DISABLE_AUTH=true
ENVEOF

# ─── Patch companion launch script to also start obs-web ────────────────
cat > "$INSTALL_DIR/companion/app/launch" <<LAUNCHEOF
#!/bin/bash
COMPANION_DIR="$INSTALL_DIR/companion"
OBS_WEB_DIR="$INSTALL_DIR/obs-web"

# Fix PATH for dock launches — homebrew and nvm aren't in the default PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"

# Load nvm if available
export NVM_DIR="\$HOME/.nvm"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  source "\$NVM_DIR/nvm.sh"
fi

# Load companion environment
if [ -f "\$COMPANION_DIR/.env.local" ]; then
  source "\$COMPANION_DIR/.env.local"
fi

# Load obs-web environment
if [ -f "\$OBS_WEB_DIR/.env.local" ]; then
  set -a
  source "\$OBS_WEB_DIR/.env.local"
  set +a
fi

# Start local obs-web server
cd "\$OBS_WEB_DIR"
PORT=8080 node build &
OBS_WEB_PID=\$!

# Run companion (publishes IP + launches OBS, then exits)
cd "\$COMPANION_DIR"
./node_modules/.bin/tsx src/launch-obs.ts 2>&1 | logger -t "OBS Launcher"

# Keep obs-web server running until it exits on its own
wait \$OBS_WEB_PID
LAUNCHEOF
chmod +x "$INSTALL_DIR/companion/app/launch"

# ─── Build OBS Launcher app ─────────────────────────────────────────────
echo ""
echo "Building OBS Launcher app..."
cd "$INSTALL_DIR/companion"
bash app/build-app.sh

# ─── Copy to Desktop ────────────────────────────────────────────────────
LAUNCHER_APP="$INSTALL_DIR/companion/app/OBS Launcher.app"
DESKTOP_APP="$HOME/Desktop/OBS Launcher.app"

if [ -d "$LAUNCHER_APP" ]; then
  rm -rf "$DESKTOP_APP"
  cp -R "$LAUNCHER_APP" "$DESKTOP_APP"
  xattr -cr "$DESKTOP_APP"
  echo ""
  echo "OBS Launcher copied to Desktop."
fi

# ─── Done ────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║          Setup Complete!             ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Before first use:"
echo "  1. Open OBS Studio"
echo "  2. Go to Tools > WebSocket Server Settings"
echo "  3. Enable the WebSocket server"
echo "  4. Set the password to: $OBS_PASSWORD"
echo ""
echo "To start broadcasting:"
echo "  Double-click 'OBS Launcher' on your Desktop"
echo "  Then visit obs.ella7.com on your phone"
echo ""
