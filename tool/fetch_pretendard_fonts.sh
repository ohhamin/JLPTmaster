#!/usr/bin/env bash
set -euo pipefail

VERSION="v1.3.9"
ROOT="https://raw.githubusercontent.com/orioncactus/pretendard/${VERSION}/packages"
DEST="assets/fonts"

mkdir -p "${DEST}"

download() {
  local url="$1"
  local output="$2"
  echo "Downloading ${output}"
  curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 \
    "${url}" --output "${DEST}/${output}"
  test -s "${DEST}/${output}"
}

# Static weights are used instead of the variable font so Android renders
# heavy Korean weights consistently across Samsung devices.
download "${ROOT}/pretendard/dist/public/static/Pretendard-Regular.otf" "Pretendard-Regular.otf"
download "${ROOT}/pretendard/dist/public/static/Pretendard-Medium.otf" "Pretendard-Medium.otf"
download "${ROOT}/pretendard/dist/public/static/Pretendard-SemiBold.otf" "Pretendard-SemiBold.otf"
download "${ROOT}/pretendard/dist/public/static/Pretendard-Bold.otf" "Pretendard-Bold.otf"
download "${ROOT}/pretendard/dist/public/static/Pretendard-ExtraBold.otf" "Pretendard-ExtraBold.otf"
download "${ROOT}/pretendard/dist/public/static/Pretendard-Black.otf" "Pretendard-Black.otf"

# Japanese vocabulary gets its own regular-weight Pretendard JP face so kanji
# stays open and legible instead of inheriting the UI's bold weights.
download "${ROOT}/pretendard-jp/dist/public/static/PretendardJP-Regular.otf" "PretendardJP-Regular.otf"

# HS유지체 is used only inside the customizable profile card.
download "https://raw.githubusercontent.com/fonts-archive/HSYuji/main/HSYuji.otf" "HSYuji.otf"

echo "JLPTmaster fonts ready in ${DEST}"
