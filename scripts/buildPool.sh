#!/bin/bash

rm -f ../pool.db ../pool.db.gz

# $1: filename
# $2: key
parse() {
    result="$(grep -io "^${2}.*" "../pool/${1}" | sed -e "s/${2}://gI" | sed -e 's/^\s*//g' | sed -e 's/\s*$//g')"
    if [[ -z "$result" ]]; then
        echo "%"
    else
        echo "$result"
    fi
}

for file in ../pool/*; do
    filename="$(sed -e 's|^.*/||g' <<< "$file")"
    echo "Parsing $filename ..."
    description="$(parse "$filename" "description")"
    apt="$(parse "$filename" "apt")"
    zypper="$(parse "$filename" "zypper")"
    dnf="$(parse "$filename" "dnf")"
    pacman="$(parse "$filename" "pacman")"
    portage="$(parse "$filename" "portage")"
    slackpkg="$(parse "$filename" "slackpkg")"
    pkg="$(parse "$filename" "pkg")"
    nix="$(parse "$filename" "nix")"
    apk="$(parse "$filename" "apk")"

    npm="$(parse "$filename" "npm")"
    pip="$(parse "$filename" "pip")"
    gem="$(parse "$filename" "gem")"
    cargo="$(parse "$filename" "cargo")"
    go="$(parse "$filename" "go")"
    cabal="$(parse "$filename" "cabal")"

    flatpak="$(parse "$filename" "flatpak")"
    snap="$(parse "$filename" "snap")"
    appimage="$(parse "$filename" "appimage")"

    if [[ -s "../packages/source/${filename}" ]]; then
        special="!"
    else
        special="%"
    fi

    result="${filename};${apt},${zypper},${dnf},${pacman},${portage},${slackpkg},${pkg},${nix},${apk};${npm},${pip},${gem},${cargo},${go},${cabal};${flatpak},${snap},${appimage};${special};${description}"
    echo "$result" >> ../pool.db
done

echo "Organizing ..."
sort -u ../pool.db -o ../pool.db
echo "Compressing ..."
gzip -c -9 ../pool.db > ../pool.db.gz

echo "Pool database compiled."
