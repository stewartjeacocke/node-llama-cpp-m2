# Build a drop-in replacement for @node-llama-cpp/linux-arm64 that also contains a Vulkan
# build of llama.cpp (bins/linux-arm64-vulkan), packaged as a tarball in /out.
#
# Needs native arm64 on an Apple M2 or later: it builds with -mcpu=native, and the result
# must only be installed on M2 or later. See the commands in README.md.
ARG NLC_VERSION=3.18.1

FROM node:26
ARG NLC_VERSION

# Fail fast. -mcpu=native bakes in this CPU's features (i8mm, bf16), so the build CPU must
# be M2 or later. Also rejects qemu emulation and x86_64.
RUN set -eu; \
  test "$(uname -m)" = aarch64 || { echo "ERROR: not arm64: $(uname -m)" >&2; exit 1; }; \
  feats="$(grep -m1 '^Features' /proc/cpuinfo || true)"; \
  for f in i8mm bf16; do \
    echo "$feats" | grep -qw "$f" || { \
      echo "ERROR: build CPU lacks $f; build on an Apple M2 or later." >&2; \
      exit 1; }; \
  done

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  cmake \
  ninja-build \
  git \
  ca-certificates \
  libvulkan-dev \
  glslang-tools \
  glslc \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# 1. Build llama.cpp (Vulkan, native CPU) with node-llama-cpp's own tooling.
#
# --ignore-scripts stops node-llama-cpp's postinstall from starting a source build of its
# own. No --release and no NODE_LLAMA_CPP_CMAKE_OPTION_* variables: either would change the
# output folder name from linux-arm64-vulkan, and the loader would not find it.
WORKDIR /build/nlc
RUN npm init -y >/dev/null \
  && npm install --ignore-scripts --no-audit --no-fund "node-llama-cpp@${NLC_VERSION}"
WORKDIR /build/nlc/node_modules/node-llama-cpp
RUN node dist/cli/cli.js source download --gpu vulkan --noUsageExample

# 2. Start from the stock arm64 package and add the Vulkan variant.
WORKDIR /build
RUN set -eux; \
  npm pack --silent "@node-llama-cpp/linux-arm64@${NLC_VERSION}"; \
  mkdir pkg; \
  tar -xzf "node-llama-cpp-linux-arm64-${NLC_VERSION}.tgz" -C pkg --strip-components=1; \
  built=/build/nlc/node_modules/node-llama-cpp/llama/localBuilds/linux-arm64-vulkan/Release; \
  test -d "$built"; \
  mkdir -p pkg/bins/linux-arm64-vulkan; \
  cp -a "$built/." pkg/bins/linux-arm64-vulkan/

# 3. Sanity checks. Written as a script because the Dockerfile parser folds a '#' inside a
# continued RUN into the rest of the line.
COPY verify.sh /build/verify.sh
RUN bash /build/verify.sh /build/pkg/bins/linux-arm64-vulkan

# 4. Package. npm tarballs use a top-level "package/" directory.
RUN set -eux; \
  mkdir /out; \
  name="node-llama-cpp-linux-arm64-vulkan-${NLC_VERSION}.tgz"; \
  tar -czf "/out/$name" --owner=0 --group=0 --numeric-owner \
    --transform 's,^pkg,package,' -C /build pkg; \
  cd /out && sha256sum "$name" | tee "$name.sha256"
