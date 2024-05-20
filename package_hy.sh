#!/bin/sh
# As an argument, this script should be given the path to a parent
# directory of some local clones of Hy and Hyrule.

tar --create --auto-compress \
    --exclude __pycache__ \
    --file site/try-hy/hy-for-pyodide.tar.gz \
    -C "$1/hy" \
    hy setup.py \
    -C "$1/hyrule" \
    hyrule
