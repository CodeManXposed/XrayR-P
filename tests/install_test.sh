#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${repo_dir}/install.sh"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/xrayr-install-test.XXXXXX")
trap 'rm -rf -- "${test_dir}"' EXIT

payload="${test_dir}/XrayR-linux.zip"
digest="${payload}.dgst"
printf 'xrayr-test-payload\n' >"${payload}"

if command -v sha256sum >/dev/null 2>&1; then
    expected=$(sha256sum "${payload}" | awk '{print $1}')
else
    expected=$(shasum -a 256 "${payload}" | awk '{print $1}')
fi

printf 'SHA2-256= %s\n' "${expected}" >"${digest}"
verify_checksum "${payload}" "${digest}"

printf 'SHA256= %s\n' "${expected}" >"${digest}"
verify_checksum "${payload}" "${digest}"

printf 'SHA2-256= %064d\n' 0 >"${digest}"
if verify_checksum "${payload}" "${digest}"; then
    echo "verify_checksum accepted a mismatched digest" >&2
    exit 1
fi

printf 'MD5= ignored\n' >"${digest}"
if verify_checksum "${payload}" "${digest}"; then
    echo "verify_checksum accepted a digest without SHA-256" >&2
    exit 1
fi

[[ "$(normalize_version "")" == "" ]]
[[ "$(normalize_version "0.9.8")" == "v0.9.8" ]]
[[ "$(normalize_version "v0.9.8")" == "v0.9.8" ]]

echo "install.sh tests passed"
