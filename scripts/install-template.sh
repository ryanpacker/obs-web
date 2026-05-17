#!/bin/bash
set -e

# ─── OBS Remote Installer ───────────────────────────────────────────────
# Installs obs-web (local server) and obs-web-companion on macOS.
# Run: cd ~/Downloads/obs-web-installer && bash install.sh
# ─────────────────────────────────────────────────────────────────────────

# Fix PATH — homebrew and manually installed node may not be in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Load nvm if available
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

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
if [ "$ARCH" != "arm64" ]; then
  echo "Error: this installer only supports Apple Silicon Macs (arm64)."
  echo "Detected architecture: $ARCH"
  exit 1
fi
BREW_PREFIX="/opt/homebrew"

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
  # Kill any running obs-web server before overwriting its files. Otherwise
  # the old process keeps serving its in-memory code from the now-deleted
  # build/ directory, masking the new install.
  EXISTING_8080_PID=$(lsof -ti tcp:8080 2>/dev/null || true)
  if [ -n "$EXISTING_8080_PID" ]; then
    echo "Stopping obs-web server on port 8080 (pid $EXISTING_8080_PID)..."
    kill "$EXISTING_8080_PID" 2>/dev/null || true
    sleep 1
  fi
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

# ─── Re-exec as native arch if launched under Rosetta ───────────────────
# Defends against stale LaunchServices preferences that can override
# LSRequiresNativeExecution=true (per-app "Open using Rosetta" cache survives
# .app reinstalls because it's keyed by bundle ID).
if [ "\${OBS_LAUNCHER_NATIVE_REEXEC:-}" != "1" ] \\
   && [ "\$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] \\
   && [ "\$(/usr/bin/arch)" != "arm64" ]; then
  export OBS_LAUNCHER_NATIVE_REEXEC=1
  exec /usr/bin/arch -arm64 /bin/bash "\$0" "\$@"
fi

# ─── Persistent logging ─────────────────────────────────────────────────
LOG_DIR="\$HOME/Library/Logs/OBSLauncher"
LOG_FILE="\$LOG_DIR/launch.log"
mkdir -p "\$LOG_DIR" 2>/dev/null

log() {
  local ts msg
  ts="\$(date '+%Y-%m-%d %H:%M:%S')"
  msg="\$ts \$*"
  printf '%s\n' "\$msg" >> "\$LOG_FILE"
  printf '%s\n' "\$msg" | logger -t "OBS Launcher"
}

# "is set" / "is NOT set" without leaking the value
var_state() {
  if [ -n "\${1:-}" ]; then printf "is set"; else printf "is NOT set"; fi
}

# Native machine arch (independent of how this script was invoked / Rosetta)
if [ "\$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then
  NATIVE_ARCH="arm64"
else
  NATIVE_ARCH="x86_64"
fi

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "Invocation: \$(date '+%Y-%m-%d %H:%M:%S')  pid=\$\$  user=\$USER  host=\$(hostname)"
  echo "Launched from: \${0}"
  echo "Bash arch: \$(/usr/bin/arch)  Native arch: \${NATIVE_ARCH}"
  echo "Caller PATH: \${PATH}"
} >> "\$LOG_FILE"

log "OBS Launcher starting (installed version, bash=\$(/usr/bin/arch), native=\${NATIVE_ARCH})"
log "COMPANION_DIR=\$COMPANION_DIR"
log "OBS_WEB_DIR=\$OBS_WEB_DIR"

# ─── Augment PATH for GUI launches ──────────────────────────────────────
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
log "Augmented PATH=\$PATH"

export NVM_DIR="\$HOME/.nvm"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  source "\$NVM_DIR/nvm.sh"
  log "Sourced nvm from \$NVM_DIR/nvm.sh"
else
  log "nvm.sh not found at \$NVM_DIR/nvm.sh (continuing — relying on PATH for node)"
fi

NODE_BIN="\$(command -v node || echo '<not found>')"
NODE_VER="\$([ "\$NODE_BIN" != "<not found>" ] && arch -"\$NATIVE_ARCH" "\$NODE_BIN" --version || echo '<n/a>')"
log "node=\$NODE_BIN (\$NODE_VER, forced \${NATIVE_ARCH})"

# ─── Load environment ───────────────────────────────────────────────────
if [ -f "\$COMPANION_DIR/.env.local" ]; then
  set -a
  source "\$COMPANION_DIR/.env.local"
  set +a
  log "Loaded \$COMPANION_DIR/.env.local (CONVEX_URL \$(var_state "\${CONVEX_URL:-}"))"
else
  log "WARNING: \$COMPANION_DIR/.env.local not found"
fi

if [ -f "\$OBS_WEB_DIR/.env.local" ]; then
  set -a
  source "\$OBS_WEB_DIR/.env.local"
  set +a
  log "Loaded \$OBS_WEB_DIR/.env.local (PUBLIC_CONVEX_URL \$(var_state "\${PUBLIC_CONVEX_URL:-}"), OBS_WS_PASSWORD \$(var_state "\${OBS_WS_PASSWORD:-}"))"
else
  log "WARNING: \$OBS_WEB_DIR/.env.local not found"
fi

# ─── Sanity-check OBS is installed ──────────────────────────────────────
if [ -d "/Applications/OBS.app" ]; then
  log "Found /Applications/OBS.app"
else
  log "WARNING: /Applications/OBS.app not found — 'open -a OBS' will fail"
fi

# ─── Manage obs-web server on port 8080 ─────────────────────────────────
EXISTING_PID=\$(lsof -ti tcp:8080 2>/dev/null)
SERVER_RUNNING=false

if [ -n "\$EXISTING_PID" ]; then
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "^[23]"; then
    log "obs-web server already running on port 8080 (pid \$EXISTING_PID), reusing"
    SERVER_RUNNING=true
  else
    log "Something on port 8080 (pid \$EXISTING_PID) is not healthy — killing"
    kill \$EXISTING_PID 2>/dev/null
    sleep 1
  fi
fi

if [ "\$SERVER_RUNNING" = false ]; then
  log "Starting obs-web server (PORT=8080 node build) from \$OBS_WEB_DIR — detached, native \${NATIVE_ARCH}"
  cd "\$OBS_WEB_DIR" || { log "ERROR: failed to cd to \$OBS_WEB_DIR"; exit 1; }
  # Detach via nohup + disown so the .app's bash can exit cleanly (no zombie that
  # blocks the next launch with a "not responding" dialog).
  nohup arch -"\$NATIVE_ARCH" env PORT=8080 node build >> "\$LOG_FILE" 2>&1 &
  OBS_WEB_PID=\$!
  disown \$OBS_WEB_PID 2>/dev/null
  log "obs-web server pid=\$OBS_WEB_PID (detached)"
fi

# ─── Run companion (publishes IP + launches OBS, then exits) ────────────
cd "\$COMPANION_DIR" || { log "ERROR: failed to cd to \$COMPANION_DIR"; exit 1; }
log "Running: arch -\${NATIVE_ARCH} ./node_modules/.bin/tsx src/launch-obs.ts"

arch -"\$NATIVE_ARCH" ./node_modules/.bin/tsx src/launch-obs.ts 2>&1 | tee -a "\$LOG_FILE" | logger -t "OBS Launcher"
TSX_STATUS=\${PIPESTATUS[0]}

if [ "\$TSX_STATUS" -eq 0 ]; then
  log "launch-obs.ts exited 0 (success)"
else
  log "ERROR: launch-obs.ts exited \$TSX_STATUS"
fi

log "OBS Launcher finished (server detached, .app exiting)"
exit "\$TSX_STATUS"
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
