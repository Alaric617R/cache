#! /bin/bash

# load the module every 20 second
while true; do
    module load vcs;
    # check if vcs has been loaded
    if [ $? -eq 0 ]; then
        break;
    fi
    sleep 20;
done