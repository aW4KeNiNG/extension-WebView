#!/bin/sh

mkdir -p ndll/IPHONE
haxelib run lime rebuild . ios -clean
haxelib run lime rebuild . ios -debug