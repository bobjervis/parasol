#!/bin/bash

BIN=$(dirname "`readlink -f \"$0\"`")

ls $BIN

mkdir -p /usr/parasol/v0.1.0
ln -s /usr/parasol/v0.1.0 /usr/parasol/latest
cp -r $BIN/bin $BIN/src $BIN/lib $BIN/compiler $BIN/template /usr/parasol/latest

if [ -d /usr/local/bin ]; then
    ln -s /usr/parasol/latest/bin/pc /usr/local/bin/pc
    ln -s /usr/parasol/latest/bin/paradoc /usr/local/bin/paradoc
fi

