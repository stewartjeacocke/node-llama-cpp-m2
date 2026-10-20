# node-llama-cpp-m2

A build of `@node-llama-cpp/linux-arm64` that also contains a Vulkan build of llama.cpp
(`bins/linux-arm64-vulkan`). node-llama-cpp publishes no Vulkan binary for linux-arm64.

The binary is built with `-mcpu=native`, so it **only runs on Apple M2 or later** (it needs
`i8mm` and `bf16`). Both the build here and the consuming devcontainer fail on any other CPU.

The tarball is a drop-in replacement for `node_modules/@node-llama-cpp/linux-arm64`

## Build and extract (podman, on an M2 or later Mac)

```sh
./build.sh                    # or: NLC_VERSION=x.y.z ./build.sh
```

This builds the image, copies the tarball and its `.sha256` into `dist/`, checks the
checksum, and prints the `gh release create` command and the `NLC_VULKAN_SHA256` value.
It publishes nothing. The manual equivalent:

```sh
podman build --platform linux/arm64 --network=host -t nlc-vulkan-build .
podman create --name nlc-vulkan-out nlc-vulkan-build
mkdir -p dist
podman cp nlc-vulkan-out:/out/. dist/
podman rm nlc-vulkan-out
cat dist/*.sha256        # value for NLC_VULKAN_SHA256 in the devcontainer Dockerfile
```

Use `--build-arg NLC_VERSION=x.y.z` for another node-llama-cpp version (default 3.18.1).

## Publish

```sh
gh release create node-llama-cpp-vulkan-3.18.1 \
  dist/node-llama-cpp-linux-arm64-vulkan-3.18.1.tgz dist/*.sha256 \
  --repo stewartjeacocke/node-llama-cpp-m2 --title "node-llama-cpp 3.18.1 linux-arm64 + Vulkan"
```
