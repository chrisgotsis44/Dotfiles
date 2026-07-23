#!/usr/bin/env bash
# generate-thumbs.sh
# Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>
# Generates thumbnails for all wallpapers in wallpaper_dir into thumb_dir.
# Skips files that already have a thumbnail. Safe to run in the background.

WALLPAPER_DIR="${1:?Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>}"
THUMB_DIR="${2:?Usage: generate-thumbs.sh <wallpaper_dir> <thumb_dir>}"

mkdir -p "$THUMB_DIR"

for file in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp,gif,JPG,JPEG,PNG,WEBP,mp4,mkv,mov,webm,MP4,MKV,MOV,WEBM}; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    [ -f "$THUMB_DIR/$name" ] && continue
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
done
