#!/usr/bin/env bash
# Generate AppIcon.icns (and a PNG set) for WhisPlayInfo from the master art.
#
# Prefers the vector master (WhisPlayInfo-icon-A.svg) for crisp output at every
# size; falls back to resizing the 1024 PNG with `sips` if no SVG renderer is found.
#
# Usage:  ./generate_icns.sh
# Output: build/AppIcon.iconset/  +  build/AppIcon.icns  +  build/png/icon_<n>.png
#
# Requires (any one for vector path): rsvg-convert  |  inkscape  |  cairosvg
# Always available on macOS: sips, iconutil

set -euo pipefail
cd "$(dirname "$0")"

SVG="WhisPlayInfo-icon-A.svg"
PNG="WhisPlayInfo-icon-A-1024.png"
OUT="build"
ICONSET="$OUT/AppIcon.iconset"
PNGDIR="$OUT/png"

rm -rf "$OUT"
mkdir -p "$ICONSET" "$PNGDIR"

# Pick a renderer
RENDERER=""
if   command -v rsvg-convert >/dev/null 2>&1; then RENDERER="rsvg"
elif command -v inkscape     >/dev/null 2>&1; then RENDERER="inkscape"
elif command -v cairosvg     >/dev/null 2>&1; then RENDERER="cairosvg"
fi

render() { # $1 = size, $2 = outfile
  local s="$1" out="$2"
  case "$RENDERER" in
    rsvg)     rsvg-convert -w "$s" -h "$s" "$SVG" -o "$out" ;;
    inkscape) inkscape "$SVG" --export-type=png --export-filename="$out" -w "$s" -h "$s" >/dev/null 2>&1 ;;
    cairosvg) cairosvg "$SVG" -o "$out" -W "$s" -H "$s" ;;
    *)        sips -z "$s" "$s" "$PNG" --out "$out" >/dev/null ;;  # fallback: resize raster
  esac
}

echo "Renderer: ${RENDERER:-sips (raster fallback)}"

# macOS iconset requires these exact filenames/sizes
declare -a SPECS=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

for spec in "${SPECS[@]}"; do
  size="${spec%%:*}"; name="${spec##*:}"
  render "$size" "$ICONSET/$name"
  echo "  ✓ $name (${size}px)"
done

# Also drop a clean, deduped PNG set for web / other uses
for s in 16 32 48 64 128 256 512 1024; do
  render "$s" "$PNGDIR/icon_${s}.png"
done

# Compile .icns
iconutil -c icns "$ICONSET" -o "$OUT/AppIcon.icns"
echo ""
echo "Done →"
echo "  $OUT/AppIcon.icns"
echo "  $ICONSET/"
echo "  $PNGDIR/  (16…1024 standalone PNGs)"
