#!/bin/bash

DYNDOCKER_ROOT="$HOME/.dyndocker"

prevdir="$(pwd)"

echo "Check if atom in PATH"
if [ "$(which atom)" = "" ]; then
	echo "atom is needed to complete the installation!" 
 	exit
else
	echo ok
fi

echo "check apm in PATH"
if [ "$(which apm)" = "" ]; then
	echo "apm is needed to complete the installation!" 
 	exit
else
	echo ok
fi

read -p "Do you want to install (dyndocker) atom packages [Y/N]" -n 1 -r
echo
echo "install atom packages "
if echo "$REPLY" | egrep -q '^[Yy]$'; then
	if echo $MSYSTEM | egrep -q  '^MSYS'; then
		echo "Open this script inside a MINGW console!"
		exit
	fi
	mkdir -p $DYNDOCKER_ROOT/install/share
	cd $DYNDOCKER_ROOT/install/share
	git clone https://github.com/rcqls/dyndoc-syntax.git
	git clone https://github.com/rcqls/atom-dyndocker.git
	apm link dyndoc-syntax/atom/language-dyndoc
	apm link atom-dyndocker
	cd atom-dyndocker
	apm install;apm rebuild
	apm install language-r
	echo " -> done!"
else
	echo " -> skipped!"
fi
