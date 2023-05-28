#!/bin/bash

BIN=$(dirname "`readlink -f \"$0\"`")

VERSION=0.3.0

INSTALL=/usr/parasol/v$VERSION

if [ "x--reinstanll" == "x$1" ] || [ "x-r" == "x$1" ]; then
	echo Removing existing version $VERSION installed image.
	sudo rm -rf $INSTALL
	echo Version $VERSION removed
fi

if [ -d /usr/parasol/v$VERSION ]; then
	echo Version $VERSION is already installed. If you want to
	echo re-install, re-run this command with --reinstall or -r option.
	exit 1
fi

echo Building install package
set -e
sudo mkdir -p $INSTALL
sudo cp -r $BIN/install-linux/* $INSTALL
sudo rm /usr/parasol/latest
sudo ln -s $INSTALL /usr/parasol/latest

if [ -d /usr/local/bin ]; then
    sudo ln -s /usr/parasol/latest/bin/pbuild /usr/local/bin/pbuild
    sudo ln -s /usr/parasol/latest/bin/pc /usr/local/bin/pc
    sudo ln -s /usr/parasol/latest/bin/pcontext /usr/local/bin/pcontext
    sudo ln -s /usr/parasol/latest/bin/paradoc /usr/local/bin/paradoc
fi

echo Version $VERSION installed as latest
echo SUCCESS
exit 0

