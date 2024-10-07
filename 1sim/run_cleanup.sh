#!/bin/sh

rm -rf output
rm *.pdb
rm *.mdp
rm *.png
rm *.yml
rm *.itp
rm *.top

RESULTS_DIR=results
if [ -d "$RESULTS_DIR" ]; then
    rm -rf $RESULTS_DIR
else
    echo "Results Directory does not exist. No need for deleting"
fi