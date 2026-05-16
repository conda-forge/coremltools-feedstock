#!/bin/bash
# Install the standalone libcoremltools shared library and headers that the
# top-level build.sh staged under $SRC_DIR/libcoremltools_stage.

set -e
set -x

export PREFIX=${PREFIX:-${CONDA_PREFIX}}

cp -R "${SRC_DIR}/libcoremltools_stage/." "${PREFIX}/"
