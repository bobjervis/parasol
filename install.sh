#!/bin/bash

BIN=$(dirname "`readlink -f \"$0\"`")

VERSION=`$BIN/bin/pc --version`

INSTALL=/usr/parasol/v$VERSION

echo installing $BIN to $INSTALL

if [ "x--reinstall" == "x$1" ] || [ "x-r" == "x$1" ]; then
	echo Removing existing version $VERSION installed image.
	sudo rm -rf $INSTALL
	echo Version $VERSION removed
fi

if [ -d /usr/parasol/v$VERSION ]; then
	echo Version $VERSION is already installed. If you want to
	echo re-install, re-run this command with --reinstall or -r option.
	exit 1
fi

echo Extracting install package
set -e
sudo mkdir -p $INSTALL
sudo bash -c "( cd $INSTALL; tar xf $BIN/install-lnx-64.tar.gz )"
sudo rm /usr/parasol/latest
sudo ln -s $INSTALL /usr/parasol/latest

if [ -d /usr/local/bin ]; then
	echo Defining common commands in /usr/local/bin '(if needed)'
	if [ ! -e /usr/local/bin/pbuild ]; then
	    sudo ln -s /usr/parasol/latest/bin/pbuild /usr/local/bin/pbuild
	fi
	if [ ! -e /usr/local/bin/pbuild ]; then
	    sudo ln -s /usr/parasol/latest/bin/pc /usr/local/bin/pc
	fi
	if [ ! -e /usr/local/bin/pbuild ]; then
	    sudo ln -s /usr/parasol/latest/bin/pcontext /usr/local/bin/pcontext
	fi
	if [ ! -e /usr/local/bin/pbuild ]; then
	    sudo ln -s /usr/parasol/latest/bin/paradoc /usr/local/bin/paradoc
	fi
fi

echo Version $VERSION installed as latest
echo SUCCESS
exit 0

