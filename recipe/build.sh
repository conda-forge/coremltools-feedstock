#!/bin/bash

set -e
set -x
mkdir build
cd build

cmake ${CMAKE_ARGS} \
    -DPython_FIND_STRATEGY:STRING=LOCATION \
    -DPython_ROOT_DIR:FILEPATH="${PREFIX}" \
    ..
make -j ${CPU_COUNT}

${PYTHON} -m pip install --no-deps --ignore-installed ../
