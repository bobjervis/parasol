#!/bin/bash

BIN=$(dirname "`readlink -f \"$0\"`")

VERSION=0.3.0

mkdir -p /usr/parasol/v$VERSION
cp -r $BIN/bin $BIN/src $BIN/template /usr/parasol/v$VERSION
cp $BIN/lib/root.p /usr/parasol/v$VERSION/src/root
rm /usr/parasol/latest
ln -s /usr/parasol/v$VERSION /usr/parasol/latest

if [ -d /usr/local/bin ]; then
    ln -s /usr/parasol/latest/bin/pbuild /usr/local/bin/pbuild
    ln -s /usr/parasol/latest/bin/pc /usr/local/bin/pc
    ln -s /usr/parasol/latest/bin/pcontext /usr/local/bin/pcontext
    ln -s /usr/parasol/latest/bin/paradoc /usr/local/bin/paradoc
fi

