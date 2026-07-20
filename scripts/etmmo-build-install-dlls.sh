#!/usr/bin/env bash
# Build Nino.Core (netstandard2.1 + net8.0) + Nino.Generator and install into ETMMO yiuinino.
# Side-path git tree only; does NOT svn commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
ETMMO_ROOT="$(cd "$ROOT/.." && pwd)"
CONFIG="${CONFIG:-Release}"
VERSION_SUFFIX="${VERSION_SUFFIX:-etmmo.3}"
BUILD_ONLY=0
INSTALL=0
DRY_RUN=0
TREES=(Server ClientServer Client Client2)

usage() {
  cat <<'USAGE'
Usage: etmmo-build-install-dlls.sh [--build-only | --install] [--dry-run] [--config Release|Debug]

  --build-only   Only build under Nino/src
  --install      Build then copy into four trees' cn.etetet.yiuinino
  --dry-run      With --install, print actions and md5 without writing
  --config       Build configuration (default Release)

Install layout (same fork commit):
  Runtime/Nino.Core.dll          netstandard2.1  (Unity)
  Runtime/Nino.Generator.dll     netstandard2.0  (Unity + DotNet Analyzer)
  DotNet~/Nino.Core.dll          net8.0          (Server/CS DotNet runtime)

Never svn commit. Never put netstandard Core on Server net10 runtime.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) BUILD_ONLY=1; shift ;;
    --install) INSTALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$INSTALL" -eq 0 && "$BUILD_ONLY" -eq 0 ]]; then
  BUILD_ONLY=1
fi

if svn info "$ROOT" &>/dev/null; then
  echo "FATAL: $ROOT is unexpectedly a SVN working copy. Abort." >&2
  exit 1
fi
if svn info "$ETMMO_ROOT" &>/dev/null; then
  echo "FATAL: ETMMO root became a SVN WC. Abort." >&2
  exit 1
fi

core_ns="$SRC/Nino.Core/bin/$CONFIG/netstandard2.1/Nino.Core.dll"
core_net8="$SRC/Nino.Core/bin/$CONFIG/net8.0/Nino.Core.dll"
gen_out="$SRC/Nino.Generator/bin/$CONFIG/netstandard2.0/Nino.Generator.dll"

build() {
  echo "==> restore + build ($CONFIG) multi-TFM Core + Generator"
  (
    cd "$SRC"
    dotnet restore Nino.Generator/Nino.Generator.csproj
    dotnet restore Nino.Core/Nino.Core.csproj
    dotnet build Nino.Core/Nino.Core.csproj -c "$CONFIG" --no-incremental -v q
    dotnet build Nino.Generator/Nino.Generator.csproj -c "$CONFIG" --no-incremental -v q
  )
  for f in "$core_ns" "$core_net8" "$gen_out"; do
    [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
  done
  echo "Built:"
  ls -la "$core_ns" "$core_net8" "$gen_out"
  if command -v md5 >/dev/null 2>&1; then
    echo -n "  ns2.1 Core "; md5 -q "$core_ns"
    echo -n "  net8  Core "; md5 -q "$core_net8"
    echo -n "  Gen        "; md5 -q "$gen_out"
  fi
}

install_one() {
  local tree="$1"
  local pkg="$ETMMO_ROOT/$tree/Packages/cn.etetet.yiuinino"
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
    echo "  would install Runtime Core+Gen + DotNet~/Nino.Core.dll (net8)"
    if command -v md5 >/dev/null 2>&1; then
      [[ -f "$dest/Nino.Core.dll" ]] && { echo -n "  cur Runtime Core "; md5 -q "$dest/Nino.Core.dll"; }
      echo -n "  new Runtime Core "; md5 -q "$core_ns"
      [[ -f "$dotnet_dest/Nino.Core.dll" ]] && { echo -n "  cur DotNet Core  "; md5 -q "$dotnet_dest/Nino.Core.dll"; }
      echo -n "  new DotNet Core  "; md5 -q "$core_net8"
    fi
    return 0
  fi

  mkdir -p "$dotnet_dest"
  cp -f "$core_ns" "$dest/Nino.Core.dll"
  cp -f "$gen_out" "$dest/Nino.Generator.dll"
  cp -f "$core_net8" "$dotnet_dest/Nino.Core.dll"

  cat > "$dotnet_dest/README.txt" <<'README'
Nino.Core.dll here is net8.0, built from the same /Nino fork commit as Runtime/Nino.Core.dll (netstandard2.1).
Server/ClientServer DotNet ET.Model must Reference this path, NOT Runtime/Nino.Core.dll (net10 OverflowException).
Unity ignores folders ending with ~.
README

  local rpkg="$dest/package.json"
  if [[ -f "$rpkg" ]]; then
    python3 - <<PY
import json, pathlib, hashlib, subprocess, os
p = pathlib.Path("$rpkg")
data = json.loads(p.read_text())
base = "4.0.0-beta.47"
suf = "$VERSION_SUFFIX"
ver = f"{base}+{suf}"
data["version"] = ver
data["description"] = data.get("description") or "Ultimate high-performance binary serialization library for C#."

def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

data["_etmmo"] = {
    "note": "Homologous fork install: Unity ns2.1 Core + Server net8 Core + shared Generator. Not NuGet dual-track.",
    "unity_core": "Runtime/Nino.Core.dll netstandard2.1",
    "server_core": "DotNet~/Nino.Core.dll net8.0",
    "generator": "Runtime/Nino.Generator.dll netstandard2.0",
    "config": "$CONFIG",
    "md5": {
        "unity_core": md5("$dest/Nino.Core.dll"),
        "server_core": md5("$dotnet_dest/Nino.Core.dll"),
        "generator": md5("$dest/Nino.Generator.dll"),
    },
}
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"  package.json version -> {ver}")
PY
  fi
  echo "  installed."
}

build

if [[ "$INSTALL" -eq 1 ]]; then
  echo "==> install into ETMMO yiuinino (svn commit NOT performed)"
  for t in "${TREES[@]}"; do
    install_one "$t"
  done
  echo "Done. Wire Server/CS ET.Model to DotNet~/Nino.Core.dll; build --no-incremental + polymorphic test; svn commit from Client WC."
else
  echo "Build-only done. Re-run with --install to copy into yiuinino."
fi
