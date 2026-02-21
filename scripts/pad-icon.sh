#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/pad-icon.sh --image PATH [--padding PERCENT | --inner-size SIZE] [--output PATH] [--backup]

Description:
  Creates a padded PNG by shrinking artwork inside the original canvas size.
  You must provide exactly one sizing mode:
    --padding PERCENT    Padding percentage of canvas edge per side (0-49.9)
    --inner-size SIZE    Desired inner art size as either pixels (e.g. 860)
                         or percent of canvas (e.g. 84%)

Options:
  --image PATH           Source PNG path (required)
  --output PATH          Output PNG path (default: overwrite source image)
  --backup               Create <image>.backup.png before overwrite
  -h, --help             Show this help

Examples:
  scripts/pad-icon.sh --image assets/images/coqui-icon.png --inner-size 84%
  scripts/pad-icon.sh --image assets/images/coqui-icon.png --padding 10 --backup
  scripts/pad-icon.sh --image assets/images/coqui-icon.png --inner-size 860 --output assets/images/coqui-icon-padded.png
EOF
}

image=''
output=''
padding=''
innerSize=''
createBackup='false'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --padding)
      padding="${2:-}"
      shift 2
      ;;
    --inner-size)
      innerSize="${2:-}"
      shift 2
      ;;
    --backup)
      createBackup='true'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$image" ]]; then
  echo "Error: --image is required." >&2
  usage >&2
  exit 1
fi

if [[ -n "$padding" && -n "$innerSize" ]]; then
  echo "Error: use either --padding or --inner-size, not both." >&2
  exit 1
fi

if [[ -z "$padding" && -z "$innerSize" ]]; then
  echo "Error: provide one of --padding or --inner-size." >&2
  exit 1
fi

if [[ ! -f "$image" ]]; then
  echo "Error: image not found: $image" >&2
  exit 1
fi

if [[ "$image" != *.png ]]; then
  echo "Error: only PNG files are supported." >&2
  exit 1
fi

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
projectRoot="$(cd "$scriptDir/.." && pwd)"
pythonCmd="${PAD_ICON_PYTHON:-}"

if [[ -z "$pythonCmd" && -x "$projectRoot/.venv/bin/python" ]]; then
  pythonCmd="$projectRoot/.venv/bin/python"
fi

if [[ -z "$pythonCmd" ]]; then
  pythonCmd="python3"
fi

if ! command -v "$pythonCmd" >/dev/null 2>&1; then
  echo "Error: Python executable not found: $pythonCmd" >&2
  echo "Set PAD_ICON_PYTHON or install python3." >&2
  exit 1
fi

if [[ -z "$output" ]]; then
  output="$image"
fi

if [[ "$createBackup" == 'true' && "$output" == "$image" ]]; then
  backupPath="${image%.png}.backup.png"
  cp "$image" "$backupPath"
  echo "Backup created: $backupPath"
fi

"$pythonCmd" - "$image" "$output" "$padding" "$innerSize" <<'PY'
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except Exception:
    print("Error: Pillow is required. Install with: <python> -m pip install pillow", file=sys.stderr)
    raise SystemExit(1)

image_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
padding_raw = sys.argv[3]
inner_raw = sys.argv[4]

img = Image.open(image_path).convert("RGBA")
canvas_w, canvas_h = img.size

if canvas_w != canvas_h:
    print(f"Warning: source is not square ({canvas_w}x{canvas_h}); scaling uses independent width/height.", file=sys.stderr)

scale = None

if padding_raw:
    try:
        pad_pct = float(padding_raw)
    except ValueError:
        print("Error: --padding must be numeric (e.g. 10 or 8.5).", file=sys.stderr)
        raise SystemExit(1)
    if pad_pct < 0 or pad_pct >= 50:
        print("Error: --padding must be >= 0 and < 50.", file=sys.stderr)
        raise SystemExit(1)
    scale = (100.0 - (2.0 * pad_pct)) / 100.0

if inner_raw:
    pct_match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)%\s*", inner_raw)
    if pct_match:
        inner_pct = float(pct_match.group(1))
        if inner_pct <= 0 or inner_pct > 100:
            print("Error: --inner-size percent must be > 0 and <= 100.", file=sys.stderr)
            raise SystemExit(1)
        scale = inner_pct / 100.0
    else:
        try:
            inner_px = int(inner_raw)
        except ValueError:
            print("Error: --inner-size must be pixels (e.g. 860) or percent (e.g. 84%).", file=sys.stderr)
            raise SystemExit(1)
        if inner_px <= 0:
            print("Error: --inner-size pixels must be > 0.", file=sys.stderr)
            raise SystemExit(1)
        scale = inner_px / float(canvas_w)

if scale is None or scale <= 0:
    print("Error: invalid sizing options.", file=sys.stderr)
    raise SystemExit(1)

if scale > 1:
    print("Error: calculated inner size exceeds source canvas.", file=sys.stderr)
    raise SystemExit(1)

inner_w = max(1, int(round(canvas_w * scale)))
inner_h = max(1, int(round(canvas_h * scale)))
resized = img.resize((inner_w, inner_h), Image.Resampling.LANCZOS)

canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
offset = ((canvas_w - inner_w) // 2, (canvas_h - inner_h) // 2)
canvas.paste(resized, offset, resized)

output_path.parent.mkdir(parents=True, exist_ok=True)
canvas.save(output_path)

print(f"Source: {image_path}")
print(f"Output: {output_path}")
print(f"Canvas: {canvas_w}x{canvas_h}")
print(f"Inner : {inner_w}x{inner_h} ({(inner_w / canvas_w) * 100:.2f}%)")
print(f"Padding per side: {((canvas_w - inner_w) / 2) / canvas_w * 100:.2f}%")
PY
