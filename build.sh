#!/usr/bin/env bash
# Build the Vulkan-enabled @node-llama-cpp/linux-arm64 package with podman and extract the
# tarball to ./dist, ready to publish as a GitHub release.
#
#   ./build.sh
#   NLC_VERSION=3.18.2 OUT_DIR=dist ./build.sh
#
# Run on an Apple M2 or later (native arm64): the Dockerfile builds with -mcpu=native and
# refuses to build on any other CPU.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

NLC_VERSION="${NLC_VERSION:-3.18.1}" # pin to 3.18.1 unless overridden 
OUT_DIR="${OUT_DIR:-dist}"
IMAGE="nlc-vulkan-build:${NLC_VERSION}"
REPO="stewartjeacocke/node-llama-cpp-m2"
TAG="node-llama-cpp-vulkan-${NLC_VERSION}"
NAME="node-llama-cpp-linux-arm64-vulkan-${NLC_VERSION}.tgz"

command -v podman >/dev/null || { echo "ERROR: podman not found" >&2; exit 1; }

podman build --platform linux/arm64 --network=host \
  --build-arg "NLC_VERSION=${NLC_VERSION}" \
  -t "$IMAGE" .

# Extract /out from the image. The container is only created, never started.
cid="$(podman create "$IMAGE")"
trap 'podman rm -f "$cid" >/dev/null' EXIT

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$NAME" "$OUT_DIR/$NAME.sha256"
podman cp "$cid:/out/." "$OUT_DIR/"

[[ -f "$OUT_DIR/$NAME" && -f "$OUT_DIR/$NAME.sha256" ]] \
  || { echo "ERROR: $NAME or its .sha256 missing from $OUT_DIR" >&2; ls -l "$OUT_DIR" >&2; exit 1; }

# Check the extracted copy against the checksum computed inside the image.
if command -v sha256sum >/dev/null; then
  (cd "$OUT_DIR" && sha256sum -c "$NAME.sha256")
else
  (cd "$OUT_DIR" && shasum -a 256 -c "$NAME.sha256")
fi

sha="$(cut -d' ' -f1 "$OUT_DIR/$NAME.sha256")"

cat <<EOF

Built: $OUT_DIR/$NAME ($(du -h "$OUT_DIR/$NAME" | cut -f1))

EOF
