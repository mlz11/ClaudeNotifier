#!/bin/bash
# Generate AppIcon.icns from SVG with color variants
# Usage: ./generate-icon.sh [variant]
#        ./generate-icon.sh --all
# Requires: rsvg-convert (brew install librsvg)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SVG_SOURCE="$PROJECT_DIR/assets/icon.svg"
RESOURCES_DIR="$PROJECT_DIR/Resources"
TEMP_DIR=$(mktemp -d)

# Icon sizes needed for macOS iconset
SIZES="16 32 128 256 512"

# Available variants
VARIANTS="brown blue green"
DEFAULT_VARIANT="brown"

# Original colors to replace
ORIG_BODY="#3b2418"
ORIG_SHADING="#2a160f"
ORIG_HIGHLIGHT="#4a2d1f"
ORIG_EYES="#140a06"
ORIG_BG_TOP="#f4e3ce"
ORIG_BG_BOTTOM="#d7b896"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

check_dependencies() {
    if ! command -v rsvg-convert &> /dev/null; then
        echo "Error: rsvg-convert not found"
        echo "Install with: brew install librsvg"
        exit 1
    fi
}

list_variants() {
    echo "Available icon variants:"
    for variant in $VARIANTS; do
        if [ "$variant" = "$DEFAULT_VARIANT" ]; then
            echo "  $variant (default)"
        else
            echo "  $variant"
        fi
    done
}

get_palette() {
    local variant="$1"
    # Returns: body shading highlight eyes bg_top bg_bottom
    case "$variant" in
        brown)  echo "#3b2418 #2a160f #4a2d1f #140a06 #f4e3ce #d7b896" ;;
        blue)   echo "#1a3a5c #0f2a4a #2a4a6c #060a14 #cee3f4 #96b8d7" ;;
        green)  echo "#1a4a2a #0f3a1a #2a5a3a #060f0a #cef4d8 #96d7a8" ;;
        *)      echo "" ;;
    esac
}

apply_palette() {
    local svg_content="$1"
    local variant="$2"

    local palette
    palette=$(get_palette "$variant")
    if [ -z "$palette" ]; then
        echo "Error: Unknown variant '$variant'" >&2
        list_variants >&2
        exit 1
    fi

    set -- $palette
    local body="$1"
    local shading="$2"
    local highlight="$3"
    local eyes="$4"
    local bg_top="$5"
    local bg_bottom="$6"

    echo "$svg_content" | \
        sed "s/$ORIG_BODY/$body/g" | \
        sed "s/$ORIG_SHADING/$shading/g" | \
        sed "s/$ORIG_HIGHLIGHT/$highlight/g" | \
        sed "s/$ORIG_EYES/$eyes/g" | \
        sed "s/$ORIG_BG_TOP/$bg_top/g" | \
        sed "s/$ORIG_BG_BOTTOM/$bg_bottom/g"
}

generate_iconset() {
    local variant="$1"
    local svg_file="$2"
    local iconset_dir="$TEMP_DIR/${variant}.iconset"

    mkdir -p "$iconset_dir"

    for size in $SIZES; do
        # Standard resolution
        rsvg-convert -w "$size" -h "$size" "$svg_file" -o "$iconset_dir/icon_${size}x${size}.png"

        # Retina (@2x)
        local size2x=$((size * 2))
        rsvg-convert -w "$size2x" -h "$size2x" "$svg_file" -o "$iconset_dir/icon_${size}x${size}@2x.png"
    done

    echo "$iconset_dir"
}

generate_icns() {
    local variant="$1"
    local output_file="$2"

    echo "Generating $variant icon..."

    # Read source SVG
    local svg_content
    svg_content=$(cat "$SVG_SOURCE")

    # Apply color palette (skip for brown/default since it's already the original)
    local transformed_svg="$TEMP_DIR/${variant}.svg"
    if [ "$variant" = "brown" ]; then
        cp "$SVG_SOURCE" "$transformed_svg"
    else
        apply_palette "$svg_content" "$variant" > "$transformed_svg"
    fi

    # Generate iconset
    local iconset_dir
    iconset_dir=$(generate_iconset "$variant" "$transformed_svg")

    # Convert to icns
    iconutil -c icns "$iconset_dir" -o "$output_file"

    echo "  Created: $output_file"
}

generate_all() {
    echo "Generating all icon variants..."
    mkdir -p "$RESOURCES_DIR"

    for variant in $VARIANTS; do
        generate_icns "$variant" "$RESOURCES_DIR/AppIcon-${variant}.icns"
    done

    # Copy default variant to AppIcon.icns
    cp "$RESOURCES_DIR/AppIcon-${DEFAULT_VARIANT}.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo ""
    echo "Default icon (AppIcon.icns) set to: $DEFAULT_VARIANT"
    echo "Done! Generated 3 variants."
}

is_valid_variant() {
    local check="$1"
    for v in $VARIANTS; do
        if [ "$v" = "$check" ]; then
            return 0
        fi
    done
    return 1
}

# Main
check_dependencies

case "${1:-}" in
    --all|-a)
        generate_all
        ;;
    --list|-l)
        list_variants
        ;;
    --help|-h)
        echo "Usage: $0 [variant|--all|--list]"
        echo ""
        echo "Options:"
        echo "  <variant>    Generate specific variant (e.g., blue, green)"
        echo "  --all, -a    Generate all variants"
        echo "  --list, -l   List available variants"
        echo "  --help, -h   Show this help"
        echo ""
        list_variants
        ;;
    "")
        # Default: generate all
        generate_all
        ;;
    *)
        # Specific variant
        variant="$1"
        if ! is_valid_variant "$variant"; then
            echo "Error: Unknown variant '$variant'"
            list_variants
            exit 1
        fi
        mkdir -p "$RESOURCES_DIR"
        generate_icns "$variant" "$RESOURCES_DIR/AppIcon-${variant}.icns"
        ;;
esac
