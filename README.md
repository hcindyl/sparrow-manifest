# Project Sparrow

Sparrow is a project to build a low-power secure embeded platform
for Ambient ML applications. The target platform leverages
[RISC-V](https://riscv.org/) and [OpenTitan](https://opentitan.org/).
The Sparrow
software includes a home-grown operating system named CantripOS, that runs
on top of [seL4](https://github.com/seL4) and (ignoring the seL4 kernel)
is written almost entirely in [Rust](https://www.rust-lang.org/).

Sparrow (and CantripOS) are definitely a work in progress. The CantripOS
components are based on an augmented version of seL4's
[CAmkES framework](https://docs.sel4.systems/projects/camkes/).
Critical system services
are CAmkES components that are statically configured. Applications are
developed using an AmbiML-focused SDK and dynamically loaded by the
system services.

## Sparrow software repositories (what's included here).

Sparrow consists of multiple git repositories stitched together with the [repo
tool](https://gerrit.googlesource.com/git-repo/+/refs/heads/master/README.md).
The following git repositories are currently available:

- *camkes-tool*:
    seL4's camkes-tool repository with additions to support CantripOS services
- *capdl*:
    seL4's capdl repository with addition for CantripOS services and the
     CantripOS rootserver (a replacement for capdl-loader-app that is written
     in Rust and supports hand-off of system resources to the CantripOS
     MemoryManager service)
- *kernel*:
    seL4's kernel with drivers for Sparrow's RISC-V platform and support
    for reclaiming the memory used by the CantripOS rootserver
- *cantrip-full*
    frameworks for developing in Rust and the CantripOS system services
- *scripts*:
    support scripts including build-sparrow.sh

[More software will be published as we deem it ready for sharing until eventually
all of Sparrow (software and hardware designs) will be available.]

Most CantripOS Rust crates are in the *cantrip/apps/system/components* directory.
Common/shared code is in *cantrip-os-common*:

- *allocator*: a heap allocator built on the linked-list-allocator crate
- *camkes*: support for writing CAmkES components in Rust
- *capdl*: support for reading the capDL specification generated by capDL-tool
- *copyregion*: a helper for temporarily mapping physical pages into a thread's VSpace
- *cspace-slot*: an RAII helper for the *slot-allocator*
- *logger*: seL4 integration with the Rust logger crate
- *model*: support for processing capDL; used by the cantrip-os-rootserver
- *panic*: an seL4-specific panic handler
- *sel4-config*: build glue for seL4 kernel configuration
- *sel4-sys*: seL4 system interfaces & glue
- *slot-allocator*: an allocator for slots in the top-level CNode

CantripOS system services make up the remaining components:

- *DebugConsole*: a command line interface intended for debug builds
- *MailboxDriver*: a driver for the Mailbox interface used to communicate betwen the security and management cores [sparow-only]
- *MemoryManager*: the memory / object manager service that supports dynamic memory management
- *MlCoordinator*: a service that manages running ML jobs [requires support that is currently on on sparrow]
- *OpenTitanUARTDriver*: a driver for the UART on the management core [sparrow-only]
- *ProcessManager*: the service that creates & manages execution of applications
- *SDKRuntime*: the service that handles application runtime requests
- *SecurityCoordinator*: the service that provides an interface to the security core (using the MailboxDriver)
- *TimerService*: a service built on top of the management core timer hardware [requires hardware timer support]

The components used depends on the target platform. At the moment two platforms
are buildable: sparrow and rpi3 (Raspberry Pi BCM2837 running in 64-bit mode).
The sparrow platform is not useful other than for reference as building it requires
toolchain & simulator support that is not yet released. The rpi3 platform is the
intended target platform for public consumption. Contribution of additional
platform support is welcomed (e.g. a timer driver for the TimerService).

All platform-supported CantripOS services are included in both debug and release builds.
Production builds replace the *DebugConsole* with a more limited interface and drop
the UART driver when there is no serial console. The *SDKRuntime* is more a proof of
concept than anything else. There are test applications written in C and Rust in the
*apps* tree that exercise the experimental api. Production systems may have
their own SDK and associated runtime tailored to their needs.

The other main Rust piece is the rootserver application that is located in
*projects/capdl/cantrip-os-rootserver*. This depends on the *capdl* and *model*
submodules of *cantrip-os-common*. It is possible to select either cantrip-os-rootserver
or the C-based capdl-loader-app with a CMake setting in the CAmkES project's
easy-settings.cmake file; e.g. `projects/cantrip/easy-settings.cmake` has:

```
#set(CAPDL_LOADER_APP "capdl-loader-app" CACHE STRING "")
set(CAPDL_LOADER_APP "cantrip-os-rootserver" CACHE STRING "")
```

using capdl-loader-app is not advised because it lacks important functionality
found only in cantrip-os-rootserver.

## How we do software development for the Sparrow platform.

Our primary development environment uses Renode for simulation of our Sparrow
hardware design. Renode allows us to do rapid software/hardware co-design of
our multi-core RISC-V target platform. The software environment is derived
from those provided by seL4 & OpenTitan. Debugging leverages Renode facilites
and [gdb talking to Renode](https://antmicro.com/blog/2022/06/sel4-userspace-debugging-with-gdb-extensions-in-renode/)
for system software and application developement.

## How to do software development on non-Sparrow platforms.

For public use CantripOS works on the seL4 rpi3 platform with aarch64 (64-bit ARM)
enabled (as opposed to 32-bit aarch32). Instead of Renode, qemu is used to
simulate the hardware platform. In theory the software should run on real hardware
too but it's not been tried. Support for other platforms can be added.

## Getting started with repo & the build system.

This repository includes a multi-platform build framework for use with the
Sparrow software.  This framwork leverages make, cmake, and cargo.
To get started follow these steps:

1. Clone the Sparrow project from GitHub using the
   [repo tool](https://gerrit.googlesource.com/git-repo/+/refs/heads/master/README.md)
   We assume below this lands in a top-level directory named "sparrow".
2. Download, build, and boot the system to the Cantrip shell prompt.
   For now the only target platform that works is "rpi3"
   (for a raspi3b machine running in simulation on qemu).

``` shell
mkdir sparrow
cd sparrow
repo init -u https://github.com/AmbiML/sparrow-manifest -m sparrow-manifest.xml
repo sync -j$(nproc)
export PLATFORM=rpi3
source build/setup.sh
m simulate-debug
```

[Beware that if your repo tool is out of date you may need to supply `-b main`
to the init request as older versions of repo only check for a `master` branch.]

Note the above assumes you have the follow prerequisites installed on your system
and **in your shell's search path**:
1. Gcc (or clang) for the target architecture
2. Rust; at the moment this must be nightly-2021-11-05 (or be prepared to edit at least
   build/setup.sh). Beware that we override the default TLS model to match what CAmkES
   uses and this override is not supported by stable versions of Rust.
3. The python tempita module.
4. Whichever simulator seL4 expects for your target architecture; e.g. for aarch64 this
   is qemu-system-aarch64.

Because Sparrow is a CAmkES project you also need
[CAmkES dependencies](https://docs.sel4.systems/projects/buildsystem/host-dependencies.html#camkes-build-dependencies).

Sparrow uses [repo](https://gerrit.googlesource.com/git-repo/+/refs/heads/master/README.md)
to download and piece together Sparrow git repositories as well as dependent projects /
repositories such as [seL4](https://github.com/seL4).

``` shell
$ repo init -u https://github.com/AmbiML/sparrow-manifest -m sparrow-manifest.xml
Downloading Repo source from https://gerrit.googlesource.com/git-repo

repo has been initialized in <your-directory>/sparrow/
If this is not the directory in which you want to initialize repo, please run:
   rm -r <your-directory>/sparrow//.repo
and try again.
$ repo sync -j12
Fetching: 100% (23/23), done in 9.909s
Garbage collecting: 100% (23/23), done in 0.218s
Checking out: 100% (23/23), done in 0.874s
repo sync has finished successfully.
$ export PLATFORM=rpi3
$ source build/setup.sh
========================================
ROOTDIR=/<your-directory>/sparrow
OUT=/<your-directory>/sparrow/out
PLATFORM=rpi3
========================================

Type 'm [target]' to build.

Targets available are:

...
cantrip cantrip-build-debug-prepare cantrip-build-release-prepare cantrip-builtins
cantrip-builtins-debug cantrip-builtins-release cantrip-bundle-debug cantrip-bundle-release
cantrip-clean cantrip-clean-headers cantrip-clippy cantrip-component-headers
...

To get more information on a target, use 'hmm [target]'

$ m simulate-debug
...
info: component 'rust-std' for target 'aarch64-unknown-none' is up to date
loading initial cache file <your-directory>/sparrow/cantrip/projects/camkes/settings.cmake
-- Set platform details from PLATFORM=rpi3
--   KernelPlatform: bcm2837
--   KernelARMPlatform: rpi3
-- Setting from flags KernelSel4Arch: aarch64
-- Found seL4: <your-directory>/sparrow/kernel
-- The C compiler identification is GNU 11.2.1
...
[291/291] Generating images/capdl-loader-image-arm-bcm2837
...
qemu-system-aarch64 -machine raspi3b -nographic -serial null -serial mon:stdio -m size=1024M -s \
-kernel /<your-directory>/sparrow/out/cantrip/aarch64-unknown-elf/debug/capdl-loader-image \
--mem-path /<your-directory>/sparrow/out/cantrip/aarch64-unknown-elf/debug/cantrip.mem
ELF-loader started on CPU: ARM Ltd. Cortex-A53 r0p4
  paddr=[8bd000..fed0ff]
No DTB passed in from boot loader.
Looking for DTB in CPIO archive...found at 9b3ef8.
Loaded DTB from 9b3ef8.
   paddr=[23c000..23ffff]
ELF-loading image 'kernel' to 0
  paddr=[0..23bfff]
  vaddr=[ffffff8000000000..ffffff800023bfff]
  virt_entry=ffffff8000000000
ELF-loading image 'capdl-loader' to 240000
  paddr=[240000..4c0fff]
  vaddr=[400000..680fff]
  virt_entry=4009e8
Enabling MMU and paging
Jumping to kernel-image entry point...

Warning:  gpt_cntfrq 62500000, expected 19200000
Bootstrapping kernel
Booting all finished, dropped to user space
cantrip_os_rootserver::Bootinfo: (1969, 131072) empty slots 1 nodes (15, 83) untyped 131072 cnode slots
cantrip_os_rootserver::Model: 1821 objects 1 irqs 0 untypeds 2 asids
cantrip_os_rootserver::capDL spec: 0.39 Mbytes
cantrip_os_rootserver::CAmkES components: 5.85 Mbytes
cantrip_os_rootserver::Rootserver executable: 1.07 Mbytes
<<seL4(CPU 0) [decodeARMFrameInvocation/2137 T0xffffff80004c7400 "rootserver" @44373c]: ARMPageMap: Attempting to remap a frame that does not belong to the passed address space>>
...
<<seL4(CPU 0) [decodeCNodeInvocation/107 T0xffffff80009a3400 "rootserver" @4268a0]: CNode Copy/Mint/Move/Mutate: Source slot invalid or empty.>>
...
CANTRIP> cantrip_memory_manager::Global memory: 0 allocated 124501760 free, reserved: 2334720 kernel 7340032 user
...
```

The `m simulate-debug` command can be run repeatedly. If you need to reset
your setup just remove the build tree and re-run `m simulate-debug`; e.g.

``` shell
cd sparrow
m clean
m simulate-debug
```

### Depending on Rust crates

To use crates from Sparrow you can reference them from a local repository or
directly from GitHub using git; e.g. in a Config.toml:
```
cantrip-os-common = { path = "../system/components/cantrip-os-common" }
cantrip-os-common = { git = "https://github.com/AmbiML/sparrow/cantrip-full" }
```
NB: the git usage depends on cargo's support for searching for a crate
named "cantrip-os-common" in the cantrip repo.
When using a git dependency a git tag can be used to lock the crate version.

Note that many Sparrow crates need the seL4 kernel configuration
(e.g. to know whether MCS is configured). This is handled by the
cantrip-os-common/sel4-config crate that is used by a build.rs to import
kernel configuration parameters as Cargo features. In a Cargo.toml create
a features manifest with the kernel parameters you need e.g.

```
[features]
default = []
# Used by sel4-config to extract kernel config
CONFIG_PRINTING = []
```

then specify build-dependencies:

```
[build-dependencies]
# build.rs depends on SEL4_OUT_DIR = "${ROOTDIR}/out/cantrip/kernel"
sel4-config = { path = "../../cantrip/apps/system/components/cantrip-os-common/src/sel4-config" }
```

and use a build.rs that includes at least:

```
extern crate sel4_config;
use std::env;

fn main() {
    // If SEL4_OUT_DIR is not set we expect the kernel build at a fixed
    // location relative to the ROOTDIR env variable.
    println!("SEL4_OUT_DIR {:?}", env::var("SEL4_OUT_DIR"));
    let sel4_out_dir = env::var("SEL4_OUT_DIR")
        .unwrap_or_else(|_| format!("{}/out/cantrip/kernel", env::var("ROOTDIR").unwrap()));
    println!("sel4_out_dir {}", sel4_out_dir);

    // Dredge seL4 kernel config for settings we need as features to generate
    // correct code: e.g. CONFIG_KERNEL_MCS enables MCS support which changes
    // the system call numbering.
    let features = sel4_config::get_sel4_features(&sel4_out_dir);
    println!("features={:?}", features);
    for feature in features {
        println!("cargo:rustc-cfg=feature=\"{}\"", feature);
    }
}
```

Note how build.rs expects an SEL4_OUT_DIR environment variable that has the path to
the top of the kernel build area. The build/cantrip.mk build glue sets this for you but, for
example, if you choose to run ninja directly you will need it set in your environment.

Similar to SEL4_OUT_DIR the cantrip-os-common/src/sel4-sys crate that has the seL4 system
call wrappers for Rust programs requires an SEL4_DIR envronment variable that has the
path to the top of the kernel sources. This also is set by build/cantrip.mk.

## Source Code Headers

Every file containing source code includes copyright and license
information. For dependent / non-Google code these are inherited from
the upstream repositories. If there are Google modifications you may find
the Google Apache license found below.

Apache header:

    Copyright 2022 Google LLC

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
