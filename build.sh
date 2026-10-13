#!/usr/bin/env bash
# Build multi-arch (amd64 + arm64)
#
# Usage :
#   ./build.sh          build only
#   ./build.sh --push   build and push
set -euo pipefail

IMAGE="australproject/php"
TAG="8.2"
PLATFORMS="linux/amd64,linux/arm64"
BUILDER="multi"

cd "$(dirname "${BASH_SOURCE[0]}")"

PUSH_FLAG=""
[ "${1:-}" = "--push" ] && PUSH_FLAG="--push"

echo "==> $IMAGE:$TAG ($PLATFORMS) ${PUSH_FLAG:+[push]}"
docker buildx build --builder "$BUILDER" --platform "$PLATFORMS" \
  -t "$IMAGE:$TAG" $PUSH_FLAG .