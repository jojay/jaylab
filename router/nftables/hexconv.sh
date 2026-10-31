#!/bin/bash

printf $1 | hexdump -e '14/1 "%02x " "\n"' | sed 's/ /:/g'
