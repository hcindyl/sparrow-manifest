#!/bin/bash
#
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build and run sparrow e2e cantripOS simulation on RPI3 platform, assuming
# within the prepared sparrow-rpi3-public docker image.

set -x

WORKDIR=${1:-"${HOME}/sparrow"}
MANIFEST_FILE="sparrow-manifest.xml"

if [[ ! -z ${MANIFEST_DIR} ]]; then
  MANIFEST_FILE="${MANIFEST_DIR}/${MANIFEST_FILE}"
fi

# Download and build cantripOS artifacts.
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"
repo init -u https://github.com/ambiml/sparrow-manifest -m "${MANIFEST_FILE}"
repo sync -j $(nproc)

source build/setup.sh
m ${OUT}/cantrip/aarch64-unknown-elf/release/capdl-loader-image \
  ${OUT}/cantrip/aarch64-unknown-elf/release/cantrip.mem

# Run the test runner installed in the docker image.
sparrow_qemu_runner \
  --kernel_image ${OUT}/cantrip/aarch64-unknown-elf/release/capdl-loader-image \
  --mem_image ${OUT}/cantrip/aarch64-unknown-elf/release/cantrip.mem
