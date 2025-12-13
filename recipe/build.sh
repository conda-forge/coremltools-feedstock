#!/bin/bash

set -e
set -x

export PREFIX=${PREFIX:-${CONDA_PREFIX}}

# Make sure these dependencies don't get pulled in
rm -rf deps/protobuf
rm -rf deps/kmeans1d

if [[ ${CONDA_BUILD_CROSS_COMPILATION:-0} == "1" ]]; then
    Protobuf_PROTOC_EXECUTABLE=${BUILD_PREFIX}/bin/protoc
else
    Protobuf_PROTOC_EXECUTABLE=${PREFIX}/bin/protoc
fi

# Their CMake script isn't the best, they expect these
# protobuf files to have been pregenerated
# So we remove them, and explicitely rebuild them below
# Remove the pregenerated protobuf files
rm -rf mlmodel/build
# Make the folder structure they expect
mkdir -p mlmodel/build/format

mkdir -p build
cd build

cmake ${CMAKE_ARGS} \
    -DOVERWRITE_PB_SOURCE=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DProtobuf_PROTOC_EXECUTABLE=${Protobuf_PROTOC_EXECUTABLE} \
    -DPython_FIND_STRATEGY:STRING=LOCATION \
    -DPython_ROOT_DIR:FILEPATH="${PREFIX}" \
    ..

# Build the protobuf source files first
cmake --build . --target protosrc

# Build the rest of the project
make -j ${CPU_COUNT}

${PYTHON:-python} -m pip install --no-deps --ignore-installed ../
