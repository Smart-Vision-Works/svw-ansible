#!/bin/sh

if [ "$(date +%u)" -eq 2 -a "$(date +%d)" -le 7 ]
then
    apt-get -s dist-upgrade | \
        grep "^Inst" | \
        grep -i securi | \
        awk -F" " '//{print $2}' | \
        xargs apt-get install -y && \
        shutdown -r now
fi