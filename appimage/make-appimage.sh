#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(cat /tmp/version)
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=./source/assets/images/flexpacket_icon_500.png
export DESKTOP=./appimage/flexpacket.desktop
export DEPLOY_QT=1

# libbluetooth is linked by bluetoothlaz, libcups is dlopen()ed by the
# LCL printers unit and libsqlite3 by the SQLDB SQLite backend
quick-sharun /usr/bin/flexpacket \
	/usr/lib/libbluetooth.so* \
	/usr/lib/libcups.so* \
	/usr/lib/libsqlite3.so*

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
