#!/bin/sh
RESULTS_DIR=results
if [ -d "$RESULTS_DIR" ]; then
    echo "Results Directory already exists."
else
    echo "Results Directory does not exist. Creating now..."
    mkdir -p "$RESULTS_DIR"
    echo "Results Directory created."
fi

mv *.tpr *.trr *.mdp *.gro *.log *.edr *.xvg *.png *.jpg *.jpeg *.cpt $RESULTS_DIR
