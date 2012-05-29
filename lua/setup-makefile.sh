#!/bin/sh

if ! pkg-config --exists lua; then
	echo "Lua libraries not found, please install"
	exit 1
fi

CFLAGS=$(pkg-config --cflags lua)
LDFLAGS=$(pkg-config --libs lua)

:>Makefile.inc

echo "LUA_CFLAGS=$CFLAGS" > Makefile.inc
echo "LUA_LDFLAGS=$LDFLAGS" >> Makefile.inc


