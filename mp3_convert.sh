#!/bin/bash
# Convert audio files (e.g., .mp3) to Asterisk/HamVoIP -law raw (.ulaw/.ul) using ffmpeg
# Output: 8000 Hz, mono, G.711 -law, headerless raw
# Requires: ffmpeg

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sound_convert.sh [-o OUTPUT_DIR] [--ext ulaw|ul] [--normalize -3.0] [--trim]
                   [--loudnorm] <path ...>

  <path> can be one or more files and/or directories (recursively searched).
  -o OUTPUT_DIR   Write outputs here (source tree mirrored). Default: alongside source files.
  --ext           Output extension: ulaw (default) or ul (both are headerless -law).
  --normalize N   Apply volume adjustment of N dB (e.g., -3.0). Default: none.
  --trim          Trim leading/trailing silence (~ -45 dB, ò0.5 s).
  --loudnorm      Use EBU R128 loudness normalization (slower, more consistent).
                  (If set, overrides --normalize.)

Examples:
  sound_convert.sh ~/prompts/fun.mp3
  sound_convert.sh -o /var/lib/asterisk/sounds/custom ~/prompts
  sound_convert.sh --ext ul --trim --normalize -3.0 ~/prompts/*.mp3
  sound_convert.sh --loudnorm ~/prompts
USAGE
}

# --- defaults ---
OUTDIR=""
EXT="ulaw"
NORM=""
DO_TRIM=0
DO_LOUDNORM=0

# --- parse args ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -o) OUTDIR="${2:-}"; shift 2 ;;
    --ext) EXT="${2:-}"; shift 2 ;;
    --normalize) NORM="${2:-}"; shift 2 ;;
    --trim) DO_TRIM=1; shift ;;
    --loudnorm) DO_LOUDNORM=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
  usage; exit 1
fi

# --- dependency check ---
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found. Install it (e.g., 'sudo pacman -Sy ffmpeg' on HamVoIP) and retry." >&2
  exit 2
fi

# Validate extension
case "$EXT" in
  ulaw|ul) ;;
  *) echo "ERROR: --ext must be 'ulaw' or 'ul'"; exit 2 ;;
esac

# Collect inputs, recursing into directories
mapfile -t INPUTS < <(
  for p in "${ARGS[@]}"; do
    if [[ -d "$p" ]]; then
      # find common audio types; extend as needed
      find "$p" -type f \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.m4a' -o -iname '*.flac' -o -iname '*.aac' \)
    elif [[ -f "$p" ]]; then
      printf '%s\n' "$p"
    fi
  done
)

if [[ ${#INPUTS[@]} -eq 0 ]]; then
  echo "No audio files found in inputs." >&2
  exit 3
fi

# Build filter chain
build_filters() {
  local filters=()

  # Loudness: EBU R128 (one-pass; good consistency; slower than simple volume)
  if [[ $DO_LOUDNORM -eq 1 ]]; then
    # Standard target values: I=-23 LUFS, TP=-2 dB, LRA=11 (common defaults)
    filters+=("loudnorm=I=-23:TP=-2:LRA=11:print_format=summary")
  elif [[ -n "$NORM" ]]; then
    # Simple relative gain in dB
    filters+=("volume=${NORM}dB")
  fi

  if [[ $DO_TRIM -eq 1 ]]; then
    # Trim leading/trailing sections < -45 dB for >= 0.5s
    filters+=("silenceremove=start_periods=1:start_duration=0.5:start_threshold=-45dB:stop_periods=1:stop_duration=0.5:stop_threshold=-45dB")
  fi

  if [[ ${#filters[@]} -gt 0 ]]; then
    printf '%s' "$(IFS=','; echo "${filters[*]}")"
  fi
}

# Convert each file
for src in "${INPUTS[@]}"; do
  base="$(basename "$src")"
  name="${base%.*}"

  if [[ -n "$OUTDIR" ]]; then
    dir="$(dirname "$src")"
    rel="${dir#/}"             # strip leading slash for mirroring
    outdir="${OUTDIR%/}/${rel}"
  else
    outdir="$(dirname "$src")"
  fi
  mkdir -p "$outdir"
  out="${outdir%/}/${name}.${EXT}"

  filters="$(build_filters)"
  if [[ -n "$filters" ]]; then
    ffmpeg -hide_banner -loglevel error -y -i "$src" \
      -ar 8000 -ac 1 -f mulaw -acodec pcm_mulaw \
      -filter:a "$filters" \
      "$out"
  else
    ffmpeg -hide_banner -loglevel error -y -i "$src" \
      -ar 8000 -ac 1 -f mulaw -acodec pcm_mulaw \
      "$out"
  fi

  echo "Converted: $src -> $out"
done

echo "Done."

