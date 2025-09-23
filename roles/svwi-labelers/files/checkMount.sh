#!/bin/bash

if [ -z "$(ls -A /auto/shared)" ]; then
    echo "/auto/shared Empty....attempting mount"
    mount -a
else
    echo "/auto/shared Already mounted"
fi
