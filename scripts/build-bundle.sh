#!/bin/bash
set -e

# ─── Build obs-web installer bundle ─────────────────────────────────────
# Creates src/lib/bundle/obs-web-installer.zip for the /download endpoint.
# Requires ../obs-web-companion/ to exist alongside this repo.
# ─────────────────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPANION_DIR="$REPO_DIR/../obs-web-companion"
STAGING_DIR="$REPO_DIR/.bundle-staging"
INSTALLER_DIR="$STAGING_DIR/obs-web-installer"
BUNDLE_DIR="$REPO_DIR/src/lib/bundle"
ZIP_FILE="$BUNDLE_DIR/obs-web-installer.zip"

echo "Building obs-web installer bundle..."

# ─── Verify companion repo exists ───────────────────────────────────────
if [ ! -d "$COMPANION_DIR" ]; then
  echo "Error: obs-web-companion not found at $COMPANION_DIR"
  echo "Clone it alongside this repo first."
  exit 1
fi

# ─── Build obs-web with Node adapter ────────────────────────────────────
echo ""
echo "Building obs-web with Node adapter..."
cd "$REPO_DIR"
BUILD_ADAPTER=node npm run build

# ─── Clean staging area ─────────────────────────────────────────────────
rm -rf "$STAGING_DIR"
mkdir -p "$INSTALLER_DIR/obs-web"
mkdir -p "$INSTALLER_DIR/companion"
mkdir -p "$BUNDLE_DIR"

# ─── Stage obs-web ──────────────────────────────────────────────────────
echo "Staging obs-web files..."
cp -R "$REPO_DIR/build" "$INSTALLER_DIR/obs-web/build"
cp "$REPO_DIR/package.json" "$INSTALLER_DIR/obs-web/package.json"
cp "$REPO_DIR/package-lock.json" "$INSTALLER_DIR/obs-web/package-lock.json"

# ─── Stage companion ────────────────────────────────────────────────────
echo "Staging companion files..."
cd "$COMPANION_DIR"
# Copy everything except excluded dirs/files
rsync -a \
  --exclude='node_modules' \
  --exclude='.git' \
  --exclude='.env.local' \
  --exclude='*.app' \
  --exclude='.DS_Store' \
  . "$INSTALLER_DIR/companion/"

# ─── Copy install script ────────────────────────────────────────────────
cp "$REPO_DIR/scripts/install-template.sh" "$INSTALLER_DIR/install.sh"
chmod +x "$INSTALLER_DIR/install.sh"

# ─── Create zip ──────────────────────────────────────────────────────────
echo "Creating zip..."
cd "$STAGING_DIR"
rm -f "$ZIP_FILE"
zip -r -q "$ZIP_FILE" obs-web-installer

# ─── Clean up ────────────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

# ─── Report ──────────────────────────────────────────────────────────────
SIZE=$(du -h "$ZIP_FILE" | cut -f1)
echo ""
echo "Bundle created: $ZIP_FILE ($SIZE)"
echo "Ready to deploy."
