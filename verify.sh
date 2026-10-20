#!/usr/bin/env bash
# Checks the packaged Vulkan variant directory ($1) before it is tarred up.
set -euo pipefail
vk="$1"

[[ -f "$vk/llama-addon.node" && -f "$vk/_nlcBuildMetadata.json" ]] \
  || { echo "missing addon or build metadata" >&2; exit 1; }

node -e '
  const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).buildOptions;
  if (m.gpu !== "vulkan" || m.arch !== "arm64" || m.platform !== "linux")
    { console.error("unexpected build metadata", m); process.exit(1); }
  console.log("metadata ok:", m.gpu, m.arch, m.llamaCpp.release);
' "$vk/_nlcBuildMetadata.json"

# Vulkan really is compiled in: the backend library must exist and link libvulkan. Capture
# the output first and grep the variable, because `readelf | grep -q` under pipefail fails
# with SIGPIPE (141) on a match.
[[ -f "$vk/libggml-vulkan.so" ]] \
  || { echo "libggml-vulkan.so missing; Vulkan was not compiled in" >&2; exit 1; }
needed="$(readelf -d "$vk/libggml-vulkan.so")"
grep -q 'NEEDED.*libvulkan\.so\.1' <<<"$needed" || {
  echo "libggml-vulkan.so does not link libvulkan.so.1" >&2
  grep NEEDED <<<"$needed" >&2 || true
  exit 1
}

glibc="$(objdump -T "$vk"/*.so* "$vk/llama-addon.node" \
  | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1 || true)"
echo "highest glibc symbol: ${glibc:-none found}"

# The addon loads (no GPU is needed just to dlopen it).
node -e 'process.dlopen({ exports: {} }, process.argv[1])' "$vk/llama-addon.node"
echo "addon loads"
ls -l "$vk"
