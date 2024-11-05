#!/bin/bash

set -e
set -x

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  pushd deps/protobuf
  (
    export CC=$CC_FOR_BUILD
    export CXX=$CXX_FOR_BUILD
    unset CFLAGS
    unset CXXFLAGS
    export HOST=${BUILD}
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    aclocal
    libtoolize
    autoconf
    autoreconf -i
    automake --add-missing
    ./configure --prefix="${BUILD_PREFIX}" \
            --build=${BUILD}         \
            --host=${BUILD} || (cat config.log; exit 1)
    make -j${CPU_COUNT}
    make install
    cp src/js_embed ${BUILD_PREFIX}/bin/js_embed
  )
  popd
fi

mkdir build
cd build

cmake ${CMAKE_ARGS} \
    -DPython_FIND_STRATEGY:STRING=LOCATION \
    -DPython_ROOT_DIR:FILEPATH="${PREFIX}" \
    ..
make -j ${CPU_COUNT}

${PYTHON} -m pip install --no-deps --ignore-installed ../
