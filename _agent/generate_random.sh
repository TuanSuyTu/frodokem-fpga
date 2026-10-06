#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ref="${1:?Provide the official reference checkout}"
sha="$(git -C "$ref" rev-parse HEAD)"
[[ "$sha" == e1edeb3af1fae0d5727683bd2f5465280ec2437a ]]
git -C "$ref" diff --exit-code
out="$(mktemp -d "$root/random-build.XXXXXX")"
gcc -std=gnu11 -O3 -Wall -Wextra -DNIX -D_AMD64_ -D_REFERENCE_ \
  -D_SHAKE128_FOR_A_ -DNO_OPENSSL \
  -I"$root/sw" -I"$ref/FrodoKEM/src" -I"$ref/common/sha3" \
  "$root/_agent/generate_random.c" "$ref/FrodoKEM/src/frodo640.c" \
  "$ref/FrodoKEM/src/util.c" "$ref/common/sha3/fips202.c" -o "$out/generate_random"
timeout 1200s "$out/generate_random" "$out/random_1000.bin" 1000 "$sha"
sha256sum "$out/random_1000.bin"
printf 'GOLDEN_OUTPUT=%s\n' "$out"
