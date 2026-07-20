#!/usr/bin/env bash
# Build Nino.Core + Nino.Generator and optionally install into ETMMO yiuinino Runtime.
# This repo is a side-path git tree; it does NOT touch SVN metadata or commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
ETMMO_ROOT="$(cd "$ROOT/.." && pwd)"
CONFIG="${CONFIG:-Release}"
VERSION_SUFFIX="${VERSION_SUFFIX:-etmmo.1}"
BUILD_ONLY=0
INSTALL=0
DRY_RUN=0
TREES=(Server ClientServer Client Client2)

usage() {
  cat <<'EOF'
Usage: etmmo-build-install-dlls.sh [--build-only | --install] [--dry-run] [--config Release|Debug]

  --build-only   Only build DLLs under Nino/src (default if neither flag given: build-only)
  --install      Build then copy into four ETMMO trees' cn.etetet.yiuinino/Runtime
  --dry-run      With --install, print actions and md5 without writing
  --config       Build configuration (default Release)

Never runs svn commit. Never modifies files outside yiuinino/Runtime when installing.
EOF
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

# Safety: Nino must not live inside a SVN WC
if svn info "$ROOT" &>/dev/null; then
  echo "FATAL: $ROOT is unexpectedly a SVN working copy. Abort." >&2
  exit 1
fi
if svn info "$ETMMO_ROOT" &>/dev/null; then
  echo "FATAL: ETMMO root became a SVN WC. Abort." >&2
  exit 1
fi

core_out="$SRC/Nino.Core/bin/$CONFIG/netstandard2.1/Nino.Core.dll"
gen_out="$SRC/Nino.Generator/bin/$CONFIG/netstandard2.0/Nino.Generator.dll"

build() {
  echo "==> restore + build ($CONFIG)"
  (
    cd "$SRC"
    dotnet restore Nino.Generator/Nino.Generator.csproj
    dotnet restore Nino.Core/Nino.Core.csproj
    dotnet build Nino.Core/Nino.Core.csproj -c "$CONFIG" --no-incremental -v q
    dotnet build Nino.Generator/Nino.Generator.csproj -c "$CONFIG" --no-incremental -v q
  )
  [[ -f "$core_out" ]] || { echo "missing $core_out" >&2; exit 1; }
  [[ -f "$gen_out" ]] || { echo "missing $gen_out" >&2; exit 1; }
  echo "Built:"
  ls -la "$core_out" "$gen_out"
  if command -v md5 >/dev/null 2>&1; then
    md5 "$core_out" "$gen_out"
  else
    md5sum "$core_out" "$gen_out"
  fi
}

install_one() {
  local tree="$1"
  local dest="$ETMMO_ROOT/$tree/Packages/cn.etetet.yiuinino/Runtime"
  if [[ ! -d "$dest" ]]; then
    echo "SKIP $tree: no Runtime at $dest"
    return 0
  fi
  # refuse if path is somehow outside expected package
  case "$dest" in
    */Packages/cn.etetet.yiuinino/Runtime) ;;
    *) echo "FATAL: refuse unexpected dest $dest" >&2; exit 1 ;;
  esac

  echo "-- $tree -> $dest"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would cp Nino.Core.dll Nino.Generator.dll"
    if [[ -f "$dest/Nino.Core.dll" ]]; then
      if command -v md5 >/dev/null 2>&1; then
        echo -n "  current Core "; md5 -q "$dest/Nino.Core.dll"
        echo -n "  new     Core "; md5 -q "$core_out"
        echo -n "  current Gen  "; md5 -q "$dest/Nino.Generator.dll"
        echo -n "  new     Gen  "; md5 -q "$gen_out"
      fi
    fi
    return 0
  fi

  cp -f "$core_out" "$dest/Nino.Core.dll"
  cp -f "$gen_out" "$dest/Nino.Generator.dll"

  local pkg="$dest/package.json"
  if [[ -f "$pkg" ]]; then
    # Keep base 4.0.0-beta.47, append etmmo suffix for ops visibility
    python3 - <<PY
import json, pathlib
p = pathlib.Path("$pkg")
data = json.loads(p.read_text())
base = "4.0.0-beta.47"
suf = "$VERSION_SUFFIX"
ver = f"{base}+{suf}"
data["version"] = ver
data["description"] = data.get("description") or "Ultimate high-performance binary serialization library for C#."
data["_etmmo"] = {
    "note": "Built from side-path git /Nino; not dual-tracked with NuGet.",
    "core": "netstandard2.1",
    "generator": "netstandard2.0",
    "config": "$CONFIG",
}
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"  package.json version -> {ver}")
PY
  fi
  echo "  installed."
}

build

if [[ "$INSTALL" -eq 1 ]]; then
  echo "==> install into ETMMO yiuinino Runtime (svn commit NOT performed)"
  for t in "${TREES[@]}"; do
    install_one "$t"
  done
  echo "Done. Next: Server dotnet build --no-incremental + polymorphic test; then svn commit yiuinino from Client WC if accepted."
else
  echo "Build-only done. Re-run with --install to copy into yiuinino."
fi
