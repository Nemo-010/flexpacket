#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm --needed \
	bluez-libs      \
	lazarus         \
	qt6pas          \
	qt6ct           \
	kvantum         \
	lxqt-qtplugin   \
	libcups         \
	sqlite

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Fetching FlexPacket source..."
echo "---------------------------------------------------------------"
git clone "https://github.com/${GITHUB_REPOSITORY}.git" ./source
cd ./source

if [ "${DEVEL_RELEASE-}" = 1 ]; then
	# nightly builds track the default branch, which is what clone checks out
	echo "Building the default branch..."
	git rev-parse --short HEAD > /tmp/version
else
	# regular builds always use the newest release tag
	TAG=$(git tag --sort=-v:refname | grep -viE 'rc|alpha|beta' | head -1)
	echo "Building the release tag $TAG..."
	git checkout "$TAG"
	echo "${TAG#v}" > /tmp/version
fi

git submodule update --init --recursive --force

echo "Building FlexPacket from source..."
echo "---------------------------------------------------------------"
export LAZARUS_DIR=/usr/lib/lazarus

# packages.lazarus-ide.org ships a BGRAControls snapshot taken from an unmerged
# development branch: its bgraimagemanipulation.pas wants TPhysicalRect, which
# the BGRABitmap it ships with no longer defines. Build the released pair from
# git instead. The components loop below skips directories that already exist.
git clone --depth=1 --branch v11.6.6 https://github.com/bgrabitmap/bgrabitmap ./use/BGRABitmap
git clone --depth=1 --branch v9.0.2 https://github.com/bgrabitmap/bgracontrols ./use/BGRAControls

# Lazarus packages the project needs, as listed in use/components.txt
while IFS= read -r pkg; do
	[ -n "$pkg" ] || continue
	[ -d "use/$pkg" ] && continue
	curl -fL --retry 3 -o "/tmp/$pkg.zip" "https://packages.lazarus-ide.org/$pkg.zip"
	unzip -q -o "/tmp/$pkg.zip" -d "use/$pkg"
done < use/components.txt

# register every package we just fetched with lazbuild
find use -type f -name '*.lpk' -exec lazbuild --lazarusdir="$LAZARUS_DIR" --add-package-link {} +

lazbuild --lazarusdir="$LAZARUS_DIR" --build-all --recursive --no-write-project \
	--build-mode=Release --widgetset=qt6 src/flexpacket.lpi

install -Dm755 src/flexpacket /usr/bin/flexpacket
