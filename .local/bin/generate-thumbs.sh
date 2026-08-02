#!/usr/bin/env bash
# generate-thumbs.sh
# Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>
# Generates thumbnails for all wallpapers in wallpaper_dir into thumb_dir.
# Skips files that already have a thumbnail. Safe to run in the background.
#
# Emits progress on stdout so the caller can show it:
#   TOTAL <n>       once, only when there is work to do
#   PROGRESS <i>    after each thumbnail
# Nothing is printed at all when every thumbnail already exists, which is
# the common case -- the wallpaper picker relies on exactly that to decide
# whether anything is worth telling the user about.

WALLPAPER_DIR="${1:?Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>}"
THUMB_DIR="${2:?Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>}"

mkdir -p "$THUMB_DIR"

# First pass: work out what is actually missing. Counting up front is what
# makes a real fraction possible instead of an indeterminate spinner.
todo=()
for file in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp,gif,JPG,JPEG,PNG,WEBP,mp4,mkv,mov,webm,MP4,MKV,MOV,WEBM}; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    [ -f "$THUMB_DIR/$name" ] && continue
    todo+=("$file")
done

total=${#todo[@]}
[ "$total" -eq 0 ] && exit 0

echo "TOTAL $total"

made=0
for file in "${todo[@]}"; do
    name=$(basename "$file")
    case "$name" in
        *.mp4|*.mkv|*.mov|*.webm|*.MP4|*.MKV|*.MOV|*.WEBM)
            ffmpeg -y -i "$file" -ss 00:00:01 -vframes 1 \
                -vf "scale=-1:420" -f mjpeg "$THUMB_DIR/$name" 2>/dev/null || true
            ;;
        *)
            magick "$file" -resize x420 -quality 70 \
                "$THUMB_DIR/$name" 2>/dev/null || true
            ;;
    esac
    made=$((made + 1))
    echo "PROGRESS $made"
done
