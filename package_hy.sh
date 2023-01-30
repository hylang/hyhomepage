#!/bin/sh
# As an argument, this script should be given the path to a local
# clone of the repository for Hy itself. `hy/version.py` should
# already exist.

tar --create --auto-compress \
    --exclude __pycache__ \
    --file site/try-hy/hy-for-pyodide.tar.gz \
    -C "$1" \
    hy setup.py
