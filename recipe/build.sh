#!/bin/bash
# Top-level build script. It is run once, for the main `coremltools`
# (Python) output. It also builds, on macOS, the standalone libcoremltools
# shared library and stages it under $SRC_DIR/libcoremltools_stage; the
# `libcoremltools` output then installs that staged tree via
# install-libcoremltools.sh.

set -e
set -x

export PREFIX=${PREFIX:-${CONDA_PREFIX}}

# Make sure these vendored dependencies don't get pulled in
rm -rf deps/protobuf
rm -rf deps/kmeans1d

if [[ ${CONDA_BUILD_CROSS_COMPILATION:-0} == "1" ]]; then
    Protobuf_PROTOC_EXECUTABLE=${BUILD_PREFIX}/bin/protoc
else
    Protobuf_PROTOC_EXECUTABLE=${PREFIX}/bin/protoc
fi

# Arguments shared by both the shared-library and the Python builds.
COMMON_CMAKE_ARGS=(
    ${CMAKE_ARGS}
    -DOVERWRITE_PB_SOURCE=ON
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DProtobuf_PROTOC_EXECUTABLE="${Protobuf_PROTOC_EXECUTABLE}"
    -DPython_FIND_STRATEGY:STRING=LOCATION
    -DPython_ROOT_DIR:FILEPATH="${PREFIX}"
)

# ---------------------------------------------------------------------------
# libcoremltools: the mlmodel C++ core built as a standalone shared library
# plus development headers. Only useful on macOS, where CoreML is available.
# The result is staged for the `libcoremltools` output to package.
# ---------------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    stage="${SRC_DIR}/libcoremltools_stage"
    inc="${stage}/include/coremltools"
    rm -rf "${stage}"
    mkdir -p "${stage}/lib" "${inc}/mlmodel/src" "${inc}/mlmodel/build/format" \
             "${inc}/mlmodel/format" "${inc}/modelpackage/src"

    # Their CMake script expects these protobuf files to be pregenerated,
    # so we recreate the folder structure and regenerate them below.
    rm -rf mlmodel/build
    mkdir -p mlmodel/build/format

    mkdir -p build-shared
    pushd build-shared
    cmake "${COMMON_CMAKE_ARGS[@]}" -DCOREMLTOOLS_BUILD_SHARED=ON ..
    # Generate the protobuf sources, then build only the shared C++ library.
    cmake --build . --target protosrc
    cmake --build . --target mlmodel --parallel "${CPU_COUNT}"

    cp "mlmodel/libcoremltools${SHLIB_EXT}" "${stage}/lib/"
    install_name_tool -id "@rpath/libcoremltools${SHLIB_EXT}" \
        "${stage}/lib/libcoremltools${SHLIB_EXT}"
    popd

    # Stage the development headers, mirroring the source tree layout so
    # that the relative #includes inside the headers keep resolving.
    ( cd mlmodel/src && find . \( -name '*.hpp' -o -name '*.h' \) \
        | tar -cf - -T - ) | tar -xf - -C "${inc}/mlmodel/src"
    ( cd modelpackage/src && find . \( -name '*.hpp' -o -name '*.h' \) \
        | tar -cf - -T - ) | tar -xf - -C "${inc}/modelpackage/src"
    # Protobuf-generated headers (referenced by the mlmodel headers as
    # ../build/format/*.pb.h) and the .proto sources themselves.
    cp mlmodel/build/format/*.h "${inc}/mlmodel/build/format/"
    cp mlmodel/format/*.proto "${inc}/mlmodel/format/"
fi

# ---------------------------------------------------------------------------
# coremltools: the Python package. mlmodel stays a static library that is
# embedded into the Python extension modules, so the Python package is
# self-contained and does not depend on libcoremltools.
# ---------------------------------------------------------------------------
rm -rf mlmodel/build
mkdir -p mlmodel/build/format

mkdir -p build
pushd build
cmake "${COMMON_CMAKE_ARGS[@]}" ..
# Build the protobuf source files first
cmake --build . --target protosrc
# Build the rest of the project
make -j "${CPU_COUNT}"
popd

${PYTHON:-python} -m pip install --no-deps --ignore-installed ./
