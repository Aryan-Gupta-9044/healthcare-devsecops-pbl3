#!/usr/bin/env bash
# Usage: build.sh vle7|blue|green|all   (builds, validates and loads/pushes the image)
. "$(dirname "$0")/lib.sh"; need docker
build_one() { # image version color
  log "docker build $1 (version=$2 color=$3)"
  docker build -f "$ROOT/Dockerfile" --build-arg APP_VERSION="$2" --build-arg DEPLOYMENT_COLOR="$3" -t "$1" "$ROOT"
  "$ROOT/scripts/verify.sh" image "$1"
  load_image "$1"
}
case "${1:-vle7}" in
  vle7)  build_one "$(cicd_image)"  "$DOCKER_IMAGE_TAG" standard;;
  blue)  build_one "$(blue_image)"  "$BLUE_VERSION" blue;;
  green) build_one "$(green_image)" "$GREEN_VERSION" green;;
  all)   "$0" vle7; "$0" blue; "$0" green;;
  *) die "usage: build.sh vle7|blue|green|all";;
esac
