#!/usr/bin/env bash
# Build Nino.Core (netstandard2.1 + net8.0), Nino.Generator and Nino.UnityTypes, then optionally
# install them into an ET project's cn.etetet.yiuinino package (homologous dual-TFM install).
# This repo is a side-path git tree: it never touches SVN/git metadata of the ET project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
CONFIG="${CONFIG:-Release}"
VERSION_SUFFIX="${VERSION_SUFFIX:-etmmo.4}"
BUILD_ONLY=0
INSTALL=0
DRY_RUN=0
ET_ROOT="${ETMMO_ROOT:-}"
TREES=()

usage() {
  cat <<'USAGE'
Usage: etmmo-build-install-dlls.sh [--build-only | --install] [--root <ET project>] [--trees "A B C"] [--dry-run] [--config Release|Debug]

  --build-only   Only build under Nino/src (default when no flag is given)
  --install      Build then copy into <root>/<tree>/Packages/cn.etetet.yiuinino
  --root <path>  ET project root holding the Unity trees (default: $ETMMO_ROOT, else the parent of this repo)
  --trees "..."  Space separated tree names (default: those of Client ClientServer Server Client2 that exist)
  --dry-run      With --install, print actions and md5 without writing
  --config       Build configuration (default Release)

Install layout (same fork commit):
  Runtime/Nino.Core.dll          netstandard2.1  (Unity)
  Runtime/Nino.Generator.dll     netstandard2.0  (Unity + DotNet analyzer)
  Runtime/Nino.UnityTypes.dll    netstandard2.1  (Unity only, binds UnityEngine.CoreModule)
  DotNet~/Nino.Core.dll          net8.0          (Server/CS DotNet runtime)

Never commits anything. Never puts a netstandard Core on the net10 server runtime.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) BUILD_ONLY=1; shift ;;
    --install) INSTALL=1; shift ;;
    --root) ET_ROOT="$2"; shift 2 ;;
    --trees) read -r -a TREES <<< "$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$INSTALL" -eq 0 && "$BUILD_ONLY" -eq 0 ]]; then
  BUILD_ONLY=1
fi

if [[ -z "$ET_ROOT" ]]; then
  ET_ROOT="$(cd "$ROOT/.." && pwd)"
fi

if [[ ${#TREES[@]} -eq 0 ]]; then
  for t in Client ClientServer Server Client2; do
    [[ -d "$ET_ROOT/$t/Packages" ]] && TREES+=("$t")
  done
fi

BASE_VERSION="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$SRC/Directory.Build.props" | head -1)"
[[ -n "$BASE_VERSION" ]] || { echo "FATAL: cannot read <Version> from src/Directory.Build.props" >&2; exit 1; }
PKG_VERSION="$BASE_VERSION+$VERSION_SUFFIX"

core_ns="$SRC/Nino.Core/bin/$CONFIG/netstandard2.1/Nino.Core.dll"
core_net8="$SRC/Nino.Core/bin/$CONFIG/net8.0/Nino.Core.dll"
gen_out="$SRC/Nino.Generator/bin/$CONFIG/netstandard2.0/Nino.Generator.dll"
unity_types="$SRC/Nino.UnityTypes/bin/$CONFIG/netstandard2.1/Nino.UnityTypes.dll"

md5of() { md5 -q "$1" 2>/dev/null || md5sum "$1" | cut -d' ' -f1; }

build() {
  echo "==> restore + build ($CONFIG) : Core(ns2.1+net8) / Generator / UnityTypes"
  (
    cd "$SRC"
    dotnet build Nino.Core/Nino.Core.csproj -c "$CONFIG" --no-incremental -v q
    dotnet build Nino.Generator/Nino.Generator.csproj -c "$CONFIG" --no-incremental -v q
    dotnet build Nino.UnityTypes/Nino.UnityTypes.csproj -c "$CONFIG" --no-incremental -v q
  )
  for f in "$core_ns" "$core_net8" "$gen_out" "$unity_types"; do
    [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
  done
  echo "Built ($BASE_VERSION):"
  echo "  ns2.1 Core   $(md5of "$core_ns")  $(ls -l "$core_ns" | awk '{print $5}')B"
  echo "  net8  Core   $(md5of "$core_net8")  $(ls -l "$core_net8" | awk '{print $5}')B"
  echo "  Generator    $(md5of "$gen_out")  $(ls -l "$gen_out" | awk '{print $5}')B"
  echo "  UnityTypes   $(md5of "$unity_types")  $(ls -l "$unity_types" | awk '{print $5}')B"
}

install_one() {
  local tree="$1"
  local pkg="$ET_ROOT/$tree/Packages/cn.etetet.yiuinino"
  local dest="$pkg/Runtime"
  local dotnet_dest="$pkg/DotNet~"
  if [[ ! -d "$dest" ]]; then
    echo "SKIP $tree: no Runtime at $dest"
    return 0
  fi
  case "$dest" in
    */Packages/cn.etetet.yiuinino/Runtime) ;;
    *) echo "FATAL: refuse unexpected dest $dest" >&2; exit 1 ;;
  esac

  echo "-- $tree"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would install Core+Generator+UnityTypes + DotNet~/Nino.Core.dll ($PKG_VERSION)"
    [[ -f "$dest/Nino.Core.dll" ]] && echo "  cur Runtime Core $(md5of "$dest/Nino.Core.dll") -> $(md5of "$core_ns")"
    [[ -f "$dest/Nino.Generator.dll" ]] && echo "  cur Generator    $(md5of "$dest/Nino.Generator.dll") -> $(md5of "$gen_out")"
    [[ -f "$dotnet_dest/Nino.Core.dll" ]] && echo "  cur DotNet Core  $(md5of "$dotnet_dest/Nino.Core.dll") -> $(md5of "$core_net8")"
    return 0
  fi

  mkdir -p "$dotnet_dest"
  cp -f "$core_ns" "$dest/Nino.Core.dll"
  cp -f "$gen_out" "$dest/Nino.Generator.dll"
  cp -f "$unity_types" "$dest/Nino.UnityTypes.dll"
  cp -f "$core_net8" "$dotnet_dest/Nino.Core.dll"

  cat > "$dotnet_dest/README.txt" <<'README'
Nino.Core.dll here is net8.0, built from the same /Nino fork commit as Runtime/Nino.Core.dll (netstandard2.1).
Server/ClientServer DotNet ET.Model must Reference this path, NOT Runtime/Nino.Core.dll (net10 OverflowException).
Unity ignores folders ending with ~.
README

  local rpkg="$dest/package.json"
  if [[ -f "$rpkg" ]]; then
    python3 - "$rpkg" "$PKG_VERSION" "$CONFIG" "$dest" "$dotnet_dest" <<'PY'
import json, sys, pathlib, hashlib

pkg, version, config, dest, dotnet_dest = sys.argv[1:6]
p = pathlib.Path(pkg)
data = json.loads(p.read_text())

def md5(path):
    h = hashlib.md5()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    except FileNotFoundError:
        return None
    return h.hexdigest()

data["version"] = version
data["_etmmo"] = {
    "note": "Homologous fork install: Unity ns2.1 Core + Server net8 Core + shared Generator + UnityTypes. Not NuGet dual-track.",
    "unity_core": "Runtime/Nino.Core.dll netstandard2.1",
    "server_core": "DotNet~/Nino.Core.dll net8.0",
    "generator": "Runtime/Nino.Generator.dll netstandard2.0",
    "unity_types": "Runtime/Nino.UnityTypes.dll netstandard2.1",
    "config": config,
    "md5": {
        "unity_core": md5(f"{dest}/Nino.Core.dll"),
        "server_core": md5(f"{dotnet_dest}/Nino.Core.dll"),
        "generator": md5(f"{dest}/Nino.Generator.dll"),
        "unity_types": md5(f"{dest}/Nino.UnityTypes.dll"),
    },
}
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"  package.json version -> {version}")
PY
  fi
  echo "  installed."
}

build

if [[ "$INSTALL" -eq 1 ]]; then
  echo "==> install $PKG_VERSION into $ET_ROOT trees: ${TREES[*]}"
  for t in "${TREES[@]}"; do
    install_one "$t"
  done
  echo "Done. Nothing was committed."
else
  echo "Build-only done. Re-run with --install to copy into yiuinino."
fi
