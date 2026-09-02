#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PHOTOPEA_SRC="${ROOT}/.."
SPK_SRC="${ROOT}/spk-src"
FPK_SRC="${ROOT}/fpk-src"
OUT="${ROOT}/dist"
STAGE="${ROOT}/.build"
ICON_SRC="${PHOTOPEA_SRC}/www.photopea.com/promo/icon512.png"
FNPACK_VERSION="1.2.3"
FNPACK_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/photopea-package"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
arm64|aarch64) FNPACK_ARCH="arm64" ;;
x86_64|amd64) FNPACK_ARCH="amd64" ;;
*) echo "不支持的架构: ${ARCH}" >&2; exit 1 ;;
esac
FNPACK_BIN="${FNPACK_CACHE}/fnpack-${FNPACK_VERSION}-${OS}-${FNPACK_ARCH}"

VERSION="$(tr -d '[:space:]' < "${ROOT}/VERSION")"
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

log() { printf '==> %s\n' "$*"; }

resolve_fnpack() {
	if command -v fnpack >/dev/null 2>&1; then
		command -v fnpack
		return
	fi
	mkdir -p "${FNPACK_CACHE}"
	if [ ! -x "${FNPACK_BIN}" ]; then
		echo "==> 下载 fnpack ${FNPACK_VERSION} (${OS}-${FNPACK_ARCH})" >&2
		curl -fsSL "https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VERSION}-${OS}-${FNPACK_ARCH}" -o "${FNPACK_BIN}"
		chmod 0755 "${FNPACK_BIN}"
	fi
	printf '%s\n' "${FNPACK_BIN}"
}

prepare_icons() {
	local icon_dir="$1"
	local prefix="$2"
	mkdir -p "${icon_dir}"
	for size in 16 24 32 48 64 72 256 512; do
		sips -z "${size}" "${size}" "${ICON_SRC}" --out "${icon_dir}/${prefix}_${size}.png" >/dev/null
	done
	sips -z 64 64 "${ICON_SRC}" --out "${icon_dir}/icon_64.png" >/dev/null
	sips -z 256 256 "${ICON_SRC}" --out "${icon_dir}/icon_256.png" >/dev/null
}

stage_static() {
	local dest="$1"
	rm -rf "${dest}/www.photopea.com"
	mkdir -p "${dest}"
	cp -R "${PHOTOPEA_SRC}/www.photopea.com" "${dest}/"
	find "${dest}" \( -name '.DS_Store' -o -name '._*' \) -delete 2>/dev/null || true
}

build_spk() {
	log "构建群晖 SPK"
	rm -rf "${STAGE}/spk"
	mkdir -p "${STAGE}/spk" "${OUT}"

	stage_static "${SPK_SRC}/target"
	prepare_icons "${SPK_SRC}/target/ui/images" "photopea"
	sips -z 64 64 "${ICON_SRC}" --out "${SPK_SRC}/PACKAGE_ICON.PNG" >/dev/null
	sips -z 256 256 "${ICON_SRC}" --out "${SPK_SRC}/PACKAGE_ICON_256.PNG" >/dev/null

	chmod +x "${SPK_SRC}"/scripts/* 2>/dev/null || true
	find "${SPK_SRC}/target" \( -name '__pycache__' -o -name '*.pyc' -o -name '.DS_Store' -o -name '._*' \) -delete 2>/dev/null || true

	tar --format=ustar --no-xattrs -C "${SPK_SRC}/target" -czf "${STAGE}/package.tgz" .
	cp "${SPK_SRC}/INFO" "${SPK_SRC}/PACKAGE_ICON.PNG" "${SPK_SRC}/PACKAGE_ICON_256.PNG" "${STAGE}/spk/"
	cp -R "${SPK_SRC}/scripts" "${SPK_SRC}/conf" "${SPK_SRC}/WIZARD_UIFILES" "${STAGE}/spk/"
	cp "${STAGE}/package.tgz" "${STAGE}/spk/"

	(
		cd "${STAGE}/spk"
		sha256sum package.tgz | awk '{print $1}' > PACKAGE_SHA256
	)

	SPK_OUT="${OUT}/photopea-${VERSION}-noarch.spk"
	tar --format=ustar --no-xattrs -C "${STAGE}/spk" -cf "${SPK_OUT}" \
		INFO PACKAGE_SHA256 package.tgz scripts conf WIZARD_UIFILES \
		PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG

	if command -v xattr >/dev/null 2>&1; then
		xattr -cr "${SPK_OUT}" 2>/dev/null || true
	fi

	FIRST="$(tar -tf "${SPK_OUT}" | head -1)"
	if [ "${FIRST}" != "INFO" ]; then
		echo "SPK 首条目应为 INFO，实际为 ${FIRST}" >&2
		exit 1
	fi
	log "SPK: ${SPK_OUT} ($(du -h "${SPK_OUT}" | awk '{print $1}'))"
}

build_fpk() {
	log "构建飞牛 FPK"
	local fnpack
	fnpack="$(resolve_fnpack)"

	stage_static "${FPK_SRC}/app"
	prepare_icons "${FPK_SRC}/app/ui/images" "icon"
	sips -z 64 64 "${ICON_SRC}" --out "${FPK_SRC}/ICON.PNG" >/dev/null
	sips -z 256 256 "${ICON_SRC}" --out "${FPK_SRC}/ICON_256.PNG" >/dev/null
	chmod +x "${FPK_SRC}"/cmd/* 2>/dev/null || true
	find "${FPK_SRC}" \( -name '.DS_Store' -o -name '._*' \) -delete 2>/dev/null || true

	(
		cd "${FPK_SRC}"
		"${fnpack}" build
	)

	FPK_OUT="${OUT}/photopea-${VERSION}.fpk"
	mkdir -p "${OUT}"
	cp "${FPK_SRC}/photopea.fpk" "${FPK_OUT}"
	log "FPK: ${FPK_OUT} ($(du -h "${FPK_OUT}" | awk '{print $1}'))"
}

main() {
	if [ ! -d "${PHOTOPEA_SRC}/www.photopea.com" ]; then
		echo "缺少静态资源: ${PHOTOPEA_SRC}/www.photopea.com" >&2
		exit 1
	fi
	if [ ! -f "${ICON_SRC}" ]; then
		echo "缺少图标: ${ICON_SRC}" >&2
		exit 1
	fi

	mkdir -p "${OUT}"
	build_spk
	build_fpk
	log "完成"
	ls -lh "${OUT}/"
}

main "$@"
