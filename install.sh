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
sudo chmod +r -R $INSTALL
sudo chmod +rx -R $INSTALL/bin
sudo chmod +rx -R $INSTALL/template
sudo chmod +rx -R $INSTALL/src
sudo chmod +rx -R $INSTALL/runtime
sudo chmod +rx -R $INSTALL/test
sudo chmod +rx -R $INSTALL/test/certificates

sudo rm /usr/parasol/latest
sudo ln -s $INSTALL /usr/parasol/latest

$INSTALL/bin/pbuild -f $BIN/installer.pbld -o $BIN/inst_build --official
sudo cp $BIN/inst_build/installer_parasollanguage.org/*.pxi $INSTALL/bin
rm -rf $BIN/inst_build

if [ -d /usr/local/bin ]; then
	echo Defining common commands in /usr/local/bin '(if needed)'
	if [ ! -e /usr/local/bin/pbuild ]; then
	    sudo ln -s /usr/parasol/latest/bin/pbuild /usr/local/bin/pbuild
	fi
	if [ ! -e /usr/local/bin/pc ]; then
	    sudo ln -s /usr/parasol/latest/bin/pc /usr/local/bin/pc
	fi
	if [ ! -e /usr/local/bin/pcontext ]; then
	    sudo ln -s /usr/parasol/latest/bin/pcontext /usr/local/bin/pcontext
	fi
	if [ ! -e /usr/local/bin/paradoc ]; then
	    sudo ln -s /usr/parasol/latest/bin/paradoc /usr/local/bin/paradoc
	fi
	if [ ! -e /usr/local/bin/pbug ]; then
	    sudo ln -s /usr/parasol/latest/bin/pbug /usr/local/bin/pbug
	fi
fi

echo Version $VERSION installed as latest
echo SUCCESS
exit 0

