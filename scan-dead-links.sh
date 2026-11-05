#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
cat << EOF
  Usage: $0 [OPTION]...

  Find symlinks that would stay broken after install.sh overlays
  links/ on top of src/ (chain links are resolved transitively).

  OPTIONS:
    -d, --dir DIR    Scan an already-installed/merged theme directory
                     instead of the repo (plain dangling-symlink check)
    -h, --help       Show help

  Exit status: 0 = no broken links, 1 = broken links found.
EOF
}

NORM=

normalize() {
  local IFS=/
  local path=$1 part
  local -a parts=() out=()
  read -ra parts <<< "$path"
  for part in "${parts[@]}"; do
    case $part in
      ''|.) ;;
      ..)
        ((${#out[@]})) || return 1
        unset "out[${#out[@]}-1]"
        ;;
      *) out+=("$part") ;;
    esac
  done
  printf -v NORM '%s' "${out[*]}"
}

declare -A VISITED
REASON=

follow() {
  local rel=$1 target=$2
  if [[ -n "${VISITED[$rel]:-}" ]]; then
    REASON="symlink loop via '$rel'"
    return 1
  fi
  VISITED[$rel]=1
  if [[ "$target" == /* ]]; then
    REASON="absolute target '$target'"
    return 1
  fi
  if ! normalize "${rel%/*}/$target"; then
    REASON="target '$target' escapes theme root"
    return 1
  fi
  if [[ -z "$NORM" ]]; then
    REASON="empty target"
    return 1
  fi
  if [[ -L "$ROOT_DIR/links/$NORM" ]]; then
    follow "$NORM" "$(readlink "$ROOT_DIR/links/$NORM")"
  elif [[ -e "$ROOT_DIR/links/$NORM" ]]; then
    return 0
  elif [[ -L "$ROOT_DIR/src/$NORM" ]]; then
    follow "$NORM" "$(readlink "$ROOT_DIR/src/$NORM")"
  elif [[ -e "$ROOT_DIR/src/$NORM" ]]; then
    return 0
  else
    REASON="target '$NORM' missing from links/ and src/"
    return 1
  fi
}

scan_repo() {
  local base link target rel theme_rel
  for base in links src; do
    while IFS=$'\t' read -r -d '' link target; do
      total=$((total + 1))
      VISITED=()
      REASON=
      rel=${link#"$ROOT_DIR"/}
      theme_rel=${rel#*/}
      if follow "$theme_rel" "$target"; then
        ok=$((ok + 1))
      else
        broken=$((broken + 1))
        printf 'BROKEN %s -> %s (%s)\n' "$rel" "$target" "$REASON"
      fi
    done < <(find "$ROOT_DIR/$base" -type l -printf '%p\t%l\0')
  done
}

scan_dir() {
  local dir=$1 link all=0
  while IFS= read -r -d '' link; do
    all=$((all + 1))
  done < <(find "$dir" -type l -print0)
  while IFS= read -r -d '' link; do
    broken=$((broken + 1))
    printf 'BROKEN %s -> %s\n' "$link" "$(readlink "$link")"
  done < <(find "$dir" -xtype l -print0)
  total=$all
  ok=$((all - broken))
}

total=0 ok=0 broken=0
dir=

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unrecognized option '$1'."
      echo "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

if [[ -n "$dir" ]]; then
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: Not a directory: $dir"
    exit 1
  fi
  scan_dir "$dir"
else
  scan_repo
fi

if (( broken == 0 )); then
  printf 'OK: %d symlinks scanned, none broken\n' "$total"
else
  printf '%d of %d symlinks broken\n' "$broken" "$total"
  exit 1
fi
