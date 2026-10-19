#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

DEBUG_MODE="${DEBUG_MODE:-0}"
if [[ "$DEBUG_MODE" == "1" ]]; then
    echo "[collect] DEBUG_MODE=1"
fi

rm -rf output
mkdir output
mkdir output/bin output/lib output/include output/embed_lib

cp -r openblas/installed/* output
cp -r llama-cpp/installed/* output

rm -f output/bin/test*

if ! command -v "patchelf" >/dev/null 2>&1; then
    if ! apt-get install --yes patchelf; then
        echo "Uable to install patchelf; this script need patchelf tool."
        exit 1
    fi
fi

find output/bin -type f -executable -exec sh -c '
    if file -b "$1" | grep -q "^ELF"; then
        echo "Patching executable: $1"
        patchelf --set-rpath "\$ORIGIN/../lib" --force-rpath "$1"
    fi
' sh {} \;

find output/bin -type f -name "*.so*" -exec sh -c '
    if file -b "$1" | grep -q "^ELF"; then
        echo "Patching bin library: $1"
        patchelf --set-rpath "\$ORIGIN/../lib" --force-rpath "$1"
    fi
' sh {} \;

find output/lib -type f -name "*.so*" -exec sh -c '
    if file -b "$1" | grep -q "^ELF"; then
        echo "Patching library: $1"
        patchelf --set-rpath "\$ORIGIN" --force-rpath "$1"
    fi
' sh {} \;

# Collect all shared objects into embed_lib for embedding/distribution use.
find output/bin output/lib -type f -name "*.so*" -exec cp -f {} output/embed_lib/ \;

# Build rewrite rules from versioned so names to unversioned so names.
declare -A NEEDED_REWRITE
mapfile -t EMBED_RAW < <(find output/embed_lib -maxdepth 1 -type f -name "*.so*" | sort -V)
for f in "${EMBED_RAW[@]}"; do
    bn="$(basename "$f")"
    if [[ "$bn" =~ ^(.+\.so)\..+$ ]]; then
        base="${BASH_REMATCH[1]}"
        NEEDED_REWRITE["$bn"]="$base"
    fi
done

# Normalize embed_lib filenames: force all versioned *.so.* to plain *.so.
find output/embed_lib -maxdepth 1 -type l -name "*.so*" -delete
while IFS= read -r f; do
    bn="$(basename "$f")"
    if [[ "$bn" =~ ^(.+\.so)\..+$ ]]; then
        base="${BASH_REMATCH[1]}"
        echo "Normalizing embed library filename: $bn -> $base"
        mv -f "$f" "output/embed_lib/$base"
    fi
done < <(find output/embed_lib -maxdepth 1 -type f -name "*.so*" | sort -V)

# Patch embed libraries after filename normalization.
mapfile -t EMBED_ELFS < <(find output/embed_lib -maxdepth 1 -type f -name "*.so" | sort)
for f in "${EMBED_ELFS[@]}"; do
    if ! file -b "$f" | grep -q "^ELF"; then
        continue
    fi

    echo "Patching embed library: $f"
    patchelf --set-rpath "\$ORIGIN" --force-rpath "$f"

    soname="$(basename "$f")"
    echo "Rewriting SONAME: $soname"
    patchelf --set-soname "$soname" "$f" || true
done

# For each embed file, iterate all rewrite rules and replace versioned NEEDED.
for f in "${EMBED_ELFS[@]}"; do
    if ! file -b "$f" | grep -q "^ELF"; then
        continue
    fi

    for old in "${!NEEDED_REWRITE[@]}"; do
        new="${NEEDED_REWRITE[$old]}"
        if [[ -f "output/embed_lib/$new" && "$old" != "$new" ]]; then
            patchelf --replace-needed "$old" "$new" "$f" || true
        fi
    done

    # Extra pass from current NEEDED entries.
    while IFS= read -r needed; do
        if [[ "$needed" =~ ^(.+\.so)\..+$ ]]; then
            base="${BASH_REMATCH[1]}"
            if [[ -f "output/embed_lib/$base" ]]; then
                patchelf --replace-needed "$needed" "$base" "$f" || true
            fi
        fi
    done < <(patchelf --print-needed "$f" 2>/dev/null || true)
done
echo "[collect] done"
