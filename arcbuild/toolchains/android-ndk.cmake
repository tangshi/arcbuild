# The MIT License (MIT)
# Copyright © 2016 Naiyang Lin <maxint@foxmail.com>
#
# Android NDK toolchain file.
#
# Note: required NDK version: >=r11b
#
#   SDK_ROOT (REQUIRED) - NDK root directory
#
#   SDK_API_VERSION - Android API version
#
#     Default: 21
#     Posible values are independent on NDK version
#
#   SDK_ARCH - architecture
#
#     Default: armv7-a
#     Posible values are:
#       arm
#       armv6
#       armv7-a
#       armv8-a (or arm64)
#       x86 (or i686)
#       x86_64 (or x64)
#       mips
#       mips64
#
#   SDK_TOOLCHAIN - toolchain name
#
#     Default: clang
#     Posible values are:
#       gcc       Use the latest gcc
#       clang
#
#   SDK_STL - specify the runtime to use
#
#     Default: gnustl_static if SDK_TOOLCHAIN gcc, otherwise c++_static (NDK_VERSION>=17)
#     Posible values are:
#       system                      Minimal system C++ runtime
#       gabi++_{static|shared}      GAbi++ runtime
#       gnustl_{static|shared}      GNU STL
#       stlport_{static|shared}     STLport runtime
#       c++_{static|shared}         LLVM libc++ runtime
#

cmake_minimum_required(VERSION 3.4.0)

# CMake invokes the toolchain file twice during the first build, but only once
# during subsequent rebuilds. This was causing the various flags to be added
# twice on the first build, and on a rebuild ninja would see only one set of the
# flags and rebuild the world.
# https://github.com/android-ndk/ndk/issues/323
if(ARCBUILD_TOOLCHAIN_INCLUDED)
  return()
endif(ARCBUILD_TOOLCHAIN_INCLUDED)
set(ARCBUILD_TOOLCHAIN_INCLUDED 1)

# Touch toolchain variable to suppress "unused variable" warning.
# This happens if CMake is invoked with the same command line the second time.
if(CMAKE_TOOLCHAIN_FILE)
endif()

# Inhibit all of CMake's own NDK handling code.
set(CMAKE_SYSTEM_VERSION 1)

# Export configurable variables for the try_compile() command.
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES SDK_ROOT SDK_API_VERSION SDK_ARCH SDK_TOOLCHAIN SDK_STL NDK_VERSION)

# SDK_ROOT
if(NOT SDK_ROOT)
  set(SDK_ROOT "$ENV{ANDROID_NDK_ROOT}")
endif()
if(NOT SDK_ROOT)
  message(FATAL_ERROR "Please set SDK_ROOT variable or ANDROID_NDK_ROOT environment variable to Android NDK root directory")
endif()

# Initialize compiler and linker flags
set(SDK_C_FLAGS)
set(SDK_CXX_FLAGS)
set(SDK_LINKER_FLAGS)
set(SDK_LINKER_FLAGS_EXE)

# Get NDK version
set(NDK_SOURCE_PROPERTIES_PATH "${SDK_ROOT}/source.properties")
if(EXISTS ${NDK_SOURCE_PROPERTIES_PATH} AND NOT NDK_VERSION)
  file(READ "${SDK_ROOT}/source.properties" NDK_VERSION)
  string(REGEX MATCH "Pkg.Revision = ([0-9]+)" NDK_VERSION "${NDK_VERSION}")
  string(REGEX MATCH "([0-9]+)" NDK_VERSION "${NDK_VERSION}")
endif()
message(STATUS "NDK_VERSION: ${NDK_VERSION}")

# SDK_ARCH
if(NOT SDK_ARCH)
  set(SDK_ARCH "armv7-a")
elseif(SDK_ARCH STREQUAL "arm64")
  set(SDK_ARCH "armv8-a")
elseif(SDK_ARCH STREQUAL "i686")
  set(SDK_ARCH "x86")
elseif(SDK_ARCH STREQUAL "x64")
  set(SDK_ARCH "x86_64")
endif()

# SDK_API_VERSION
file(GLOB SDK_API_VERSION_SUPPORTED RELATIVE ${SDK_ROOT}/platforms "${SDK_ROOT}/platforms/android-*")
message(STATUS "Available SDK_API_VERSION: ${SDK_API_VERSION_SUPPORTED}")
if(NOT DEFINED SDK_API_VERSION)
  set(SDK_API_VERSION "21")
  message(STATUS "No SDK_API_VERSION is set, default is ${SDK_API_VERSION}")
  list(FIND SDK_API_VERSION_SUPPORTED "android-${SDK_API_VERSION}" SDK_API_FOUND)
  if(SDK_API_FOUND EQUAL -1)
    unset(SDK_API_VERSION)
  endif()
  if(NOT DEFINED SDK_API_VERSION)
    list(GET SDK_API_VERSION_SUPPORTED -1 SDK_API_SELECTED)
    message(STATUS "SDK_API_VERSION (${SDK_API_VERSION}) is not supported (${SDK_API_VERSION_SUPPORTED}). Use (${SDK_API_SELECTED}) instead")
    string(SUBSTRING ${SDK_API_SELECTED} 8 -1 SDK_API_VERSION)
  endif()
endif()
set(SDK_API_ROOT ${SDK_ROOT}/platforms/android-${SDK_API_VERSION})
message(STATUS "SDK_API_VERSION: ${SDK_API_VERSION}")

# SDK_ARCH_ABI
set(SDK_ARCH_ABI ${SDK_ARCH})
if(SDK_ARCH STREQUAL "arm")
  set(SDK_ARCH_ABI "armeabi")
  set(SDK_PROCESSOR "arm")
  # set(SDK_C_FLAGS "-march=armv5te")
  set(SDK_C_FLAGS "-march=armv5te -mtune=xscale -msoft-float")
  set(SDK_LLVM_TRIPLE "armv5te-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "arm-linux-androideabi")
elseif(SDK_ARCH STREQUAL "armv6")
  set(SDK_ARCH_ABI "armeabi-v6")
  set(SDK_PROCESSOR "arm")
  # set(SDK_C_FLAGS "-march=armv6")
  set(SDK_C_FLAGS "-march=armv6 -mfloat-abi=softfp -mfpu=vfp")
  set(SDK_LLVM_TRIPLE "armv6-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "arm-linux-androideabi")
elseif(SDK_ARCH STREQUAL "armv7-a")
  set(SDK_ARCH_ABI "armeabi-v7a")
  set(SDK_PROCESSOR "arm")
  # set(SDK_C_FLAGS "-march=armv7-a")
  set(SDK_C_FLAGS "-march=armv7-a -mfloat-abi=softfp -mfpu=neon -ftree-vectorize -ffast-math")
  set(SDK_LLVM_TRIPLE "armv7-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "arm-linux-androideabi")
elseif(SDK_ARCH STREQUAL "armv8-a")
  set(SDK_ARCH_ABI "arm64-v8a")
  set(SDK_PROCESSOR "arm64")
  set(SDK_C_FLAGS "-march=armv8-a")
  set(SDK_LLVM_TRIPLE "aarch64-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "aarch64-linux-android")
elseif(SDK_ARCH STREQUAL "x86")
  set(SDK_ARCH_ABI ${SDK_ARCH})
  set(SDK_PROCESSOR ${SDK_ARCH})
  set(SDK_C_FLAGS "-m32")
  set(SDK_LLVM_TRIPLE "i686-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "i686-linux-android")
elseif(SDK_ARCH STREQUAL "x86_64")
  set(SDK_ARCH_ABI ${SDK_ARCH})
  set(SDK_PROCESSOR ${SDK_ARCH})
  set(SDK_C_FLAGS "-m64")
  set(SDK_LLVM_TRIPLE "x86_64-none-linux-androideabi")
  set(SDK_HEADER_TRIPLE "x86_64-linux-android")
#elseif(SDK_ARCH STREQUAL "mips")
#elseif(SDK_ARCH STREQUAL "mips64")
else()
  message(FATAL_ERROR "Unsupported ARCH: ${SDK_ARCH}")
endif()
message(STATUS "SDK_ARCH: ${SDK_ARCH}")
message(STATUS "SDK_ARCH_ABI: ${SDK_ARCH_ABI}")
message(STATUS "SDK_PROCESSOR: ${SDK_PROCESSOR}")
set(_lib_root "${SDK_ROOT}/sources/cxx-stl/stlport/libs")
file(GLOB SDK_ARCH_ABI_SUPPORTED RELATIVE "${_lib_root}" "${_lib_root}/*")
list(FIND SDK_ARCH_ABI_SUPPORTED ${SDK_ARCH_ABI} SDK_ARCH_ABI_FOUND)
if(SDK_ARCH_ABI_FOUND EQUAL -1)
  message(WARNING "SDK_ARCH_ABI (${SDK_ARCH_ABI}) is not supported (${SDK_ARCH_ABI_SUPPORTED}). Rollback to 'armeabi'")
  set(SDK_ARCH_ABI "armeabi")
endif()
unset(_lib_root)

# CMAKE_SYSROOT
set(CMAKE_SYSROOT "${SDK_API_ROOT}/arch-${SDK_PROCESSOR}")

# Add __ANDROID_API__
list(APPEND SDK_C_FLAGS -D__ANDROID_API__=${SDK_API_VERSION})

# system info
# set(CMAKE_SYSTEM_NAME Android) # Not work in CMake 2.8.12
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_VERSION ${SDK_API_VERSION})
set(CMAKE_SYSTEM_PROCESSOR ${SDK_PROCESSOR})

# For convenience
set(UNIX 1)
set(ANDROID 1)
if(SDK_ARCH MATCHES "(arm|ARM)")
  set(ARM 1)
endif()

# SDK_TOOLCHAIN
if(NOT SDK_TOOLCHAIN)
  set(SDK_TOOLCHAIN clang)
  message(STATUS "No TOOLCHAIN is set, default is clang")
endif()
if(SDK_PROCESSOR STREQUAL "arm64")
  set(SDK_TOOLCHAIN_PREFIX "aarch64")
elseif(SDK_PROCESSOR STREQUAL "amd64")
  set(SDK_TOOLCHAIN_PREFIX "x86_64")
elseif(SDK_PROCESSOR MATCHES "mips")
  set(SDK_TOOLCHAIN_PREFIX "${SDK_PROCESSOR}el")
else()
  set(SDK_TOOLCHAIN_PREFIX ${SDK_PROCESSOR})
endif()
file(GLOB SDK_TOOLCHAIN_NAME_SUPPORTED RELATIVE "${SDK_ROOT}/toolchains" "${SDK_ROOT}/toolchains/${SDK_TOOLCHAIN_PREFIX}-*")
message(STATUS "Available SDK_TOOLCHAIN_NAME: ${SDK_TOOLCHAIN_NAME_SUPPORTED}")
list(SORT SDK_TOOLCHAIN_NAME_SUPPORTED)
list(REVERSE SDK_TOOLCHAIN_NAME_SUPPORTED)
foreach(_TC ${SDK_TOOLCHAIN_NAME_SUPPORTED})
  if(NOT _TC MATCHES "(llvm|clang)") # skip the llvm/clang
    set(SDK_TOOLCHAIN_NAME ${_TC})
    break()
  endif()
endforeach()
message(STATUS "Use the latest gcc toolchain '${SDK_TOOLCHAIN_NAME}'")
file(GLOB SDK_TOOLCHAIN_ROOT "${SDK_ROOT}/toolchains/${SDK_TOOLCHAIN_NAME}/prebuilt/*")

# get gcc version
string(REGEX MATCH "([.0-9]+)$" SDK_GCC_VERSION "${SDK_TOOLCHAIN_NAME}")

# find clang
file(GLOB SDK_CLANG_TOOLCHAIN_ROOT "${SDK_ROOT}/toolchains/llvm/prebuilt/*")
# NOTE: clang is slower than gcc in ndk-r11b for OT, DISABLE it
# But, gcc failed for Mat_::Mat_(), prefer clang now.
if(SDK_TOOLCHAIN STREQUAL "gcc")
  unset(SDK_CLANG_TOOLCHAIN_ROOT)
endif()
if(SDK_CLANG_TOOLCHAIN_ROOT)
  message(STATUS "Use clang: ${SDK_CLANG_TOOLCHAIN_ROOT}")
endif()

# STL
set(SDK_STL_SUPPORTED "system;gabi++_static;gabi++_shared;c++_static;c++_shared;gnustl_static;gnustl_shared;stlport_static;stlport_shared")
message(STATUS "Available SDK_STL: ${SDK_STL_SUPPORTED}")
if(NOT SDK_STL)
  if(SDK_TOOLCHAIN STREQUAL "gcc" OR NDK_VERSION VERSION_LESS 17)
    set(SDK_STL "gnustl_static")
  else()
    set(SDK_STL "c++_static")
  endif()
  message(STATUS "No SDK_STL is set, default is '${SDK_STL}'")
else()
  message(STATUS "SDK_STL: ${SDK_STL}")
endif()
set(SDK_STL_ROOT "${SDK_ROOT}/sources/cxx-stl")
if(SDK_STL STREQUAL "system")
  set(SDK_RTTI             OFF)
  set(SDK_EXCEPTIONS       OFF)
  set(SDK_STL_ROOT         "${SDK_STL_ROOT}/system")
  set(SDK_STL_INCLUDE_DIRS "${SDK_STL_ROOT}/include")
elseif(SDK_STL MATCHES "^gabi\\+\\+_(static|shared)$")
  set(SDK_RTTI             ON)
  set(SDK_EXCEPTIONS       ON)
  set(SDK_STL_ROOT         "${SDK_STL_ROOT}/gabi++")
  set(SDK_STL_INCLUDE_DIRS "${SDK_STL_ROOT}/include")
  set(SDK_STL_LDFLAGS      "-L${SDK_STL_ROOT}/libs/${SDK_ARCH_ABI}")
  set(SDK_STL_LIB          "-l${SDK_STL}")
elseif(SDK_STL MATCHES "^stlport_(static|shared)$")
  set(SDK_RTTI             ON)
  set(SDK_EXCEPTIONS       ON)
  set(SDK_STL_ROOT         "${SDK_STL_ROOT}/stlport")
  set(SDK_STL_INCLUDE_DIRS "${SDK_STL_ROOT}/stlport")
  set(SDK_STL_LDFLAGS      "-L${SDK_STL_ROOT}/libs/${SDK_ARCH_ABI}")
  set(SDK_STL_LIB          "-l${SDK_STL}")
elseif(SDK_STL MATCHES "^gnustl_(static|shared)$")
  set(SDK_RTTI             ON)
  set(SDK_EXCEPTIONS       ON)
  set(SDK_STL_ROOT         "${SDK_STL_ROOT}/gnu-libstdc++/${SDK_GCC_VERSION}")
  set(SDK_STL_INCLUDE_DIRS "${SDK_STL_ROOT}/include" "${SDK_STL_ROOT}/libs/${SDK_ARCH_ABI}/include")
  set(SDK_STL_LDFLAGS      "-L${SDK_STL_ROOT}/libs/${SDK_ARCH_ABI}")
  set(SDK_STL_LIB          "-l${SDK_STL} -lsupc++")
elseif(SDK_STL MATCHES "^c\\+\\+_(static|shared)$")
  set(SDK_RTTI             ON)
  set(SDK_EXCEPTIONS       ON)
  set(SDK_STL_ROOT         "${SDK_STL_ROOT}/llvm-libc++")
  set(SDK_STL_INCLUDE_DIRS "${SDK_ROOT}/sources/android/support/include"
                           "${SDK_STL_ROOT}/include" "${SDK_STL_ROOT}/libcxx/include"
                           "${SDK_ROOT}/sources/cxx-stl/llvm-libc++abi/include"
                           "${SDK_ROOT}/sources/cxx-stl/llvm-libc++abi/libcxxabi/include")
  set(SDK_STL_LDFLAGS      "-L${SDK_STL_ROOT}/libs/${SDK_ARCH_ABI}")
  set(SDK_STL_LIB          "-l${SDK_STL} -lc++abi")
else()
  message(FATAL_ERROR "Unknown NDK STL: ${SDK_STL}")
endif()
# NOTE: set -fno-exceptions -fno-rtti when use system
if(NOT SDK_RTTI)
  list(APPEND SDK_CXX_FLAGS -fno-rtti)
endif()
if(NOT SDK_EXCEPTIONS)
  list(APPEND SDK_CXX_FLAGS -fno-exceptions)
endif()

# search paths
set(CMAKE_FIND_ROOT_PATH "${SDK_TOOLCHAIN_ROOT}/bin" "${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# compilers (set CMAKE_C_COMPILER_ID and CMAKE_CXX_COMPILER automatically)
find_program(CMAKE_C_COMPILER
  NAMES
  clang
  ${SDK_HEADER_TRIPLE}-gcc
  PATH_SUFFIXES bin
  PATHS ${SDK_CLANG_TOOLCHAIN_ROOT} ${SDK_TOOLCHAIN_ROOT}
  NO_DEFAULT_PATH)
find_program(CMAKE_CXX_COMPILER
  NAMES
  clang++
  ${SDK_HEADER_TRIPLE}-g++
  PATH_SUFFIXES bin
  PATHS ${SDK_CLANG_TOOLCHAIN_ROOT} ${SDK_TOOLCHAIN_ROOT}
  NO_DEFAULT_PATH)
find_program(CMAKE_AR
  NAMES
  ar
  ${SDK_HEADER_TRIPLE}-ar
  PATH_SUFFIXES bin
  PATHS ${SDK_CLANG_TOOLCHAIN_ROOT} ${SDK_TOOLCHAIN_ROOT}
  NO_DEFAULT_PATH)

# NOTE: fix bug of no -D* passed when checking compilers
# include(CMakeForceCompiler)
# cmake_force_c_compiler(${CMAKE_C_COMPILER} GNU)
# cmake_force_cxx_compiler(${CMAKE_CXX_COMPILER} GNU)

# global includes and link directories
include_directories(SYSTEM ${SDK_STL_INCLUDE_DIRS})
if(EXISTS "${SDK_ROOT}/sysroot/usr/include")
  # set(CMAKE_SYSROOT "${SDK_ROOT}/sysroot")
  include_directories(SYSTEM "${SDK_ROOT}/sysroot/usr/include" "${SDK_ROOT}/sysroot/usr/include/${SDK_HEADER_TRIPLE}")
  # list(APPEND CMAKE_SYSTEM_LIBRARY_PATH "${SDK_API_ROOT}/arch-${SDK_PROCESSOR}/usr/lib")
endif()

# cflags, cppflags, ldflags
# NOTE: -nostdlib causes link error when compiling 'viv': hidden symbol `__dso_handle'
if(SDK_CLANG_TOOLCHAIN_ROOT)
  # -Qunused-arguments
  # CMake automatically forwards all compiler flags to the linker,
  # and clang doesn't like having -Wa flags being used for linking.
  # To prevent CMake from doing this would require meddling with
  # the CMAKE_<LANG>_COMPILE_OBJECT rules, which would get quite messy.
  list(APPEND SDK_C_FLAGS -target ${SDK_LLVM_TRIPLE} -Qunused-arguments -gcc-toolchain ${SDK_TOOLCHAIN_ROOT})
endif()
# set sysroot manually for low version cmake
if(CMAKE_VERSION VERSION_LESS "3.0")
  list(APPEND SDK_C_FLAGS --sysroot=${CMAKE_SYSROOT})
endif()
list(APPEND SDK_C_FLAGS -fno-short-enums)

# find path of libgcc.a
find_program(SDK_GCC_COMPILER
  NAMES
  arm-linux-androideabi-gcc aarch64-linux-android-gcc
  mipsel-linux-android-gcc mips64el-linux-android-gcc
  i686-linux-android-gcc x86_64-linux-android-gcc
  PATHS "${SDK_TOOLCHAIN_ROOT}/bin")
execute_process(COMMAND "${SDK_GCC_COMPILER} -print-libgcc-file-name ${CMAKE_C_FLAGS} ${SDK_C_FLAGS}" OUTPUT_VARIABLE SDK_LIBGCC)
# message("SDK_GCC_COMPILER: ${SDK_GCC_COMPILER}")
# message("SDK_LIBGCC: ${SDK_LIBGCC}")

# Linker flags
# set(SDK_LINKER_FLAGS "${SDK_LIBGCC} ${SDK_STL_LDFLAGS} -lc -lm -lstdc++ -ldl -llog")
set(SDK_LIB "${SDK_STL_LIB} -llog -ldl -lc")
list(APPEND SDK_LINKER_FLAGS -Wl,--no-undefined ${SDK_LIBGCC} ${SDK_STL_LDFLAGS}) # maybe linked with libm_hard.a
# Don't re-export libgcc symbols in every binary.
list(APPEND SDK_LINKER_FLAGS -Wl,--exclude-libs,libgcc.a)
list(APPEND SDK_LINKER_FLAGS -Wl,--exclude-libs,libatomic.a)
if(NDK_VERSION STREQUAL 17 AND SDK_TOOLCHAIN STREQUAL clang)
  list(APPEND SDK_LINKER_FLAGS -nostdlib++)
endif()
list(APPEND SDK_LINKER_FLAGSSDK_LINKER_FLAGS
  -Wl,--build-id
  -Wl,--warn-shared-textrel
  -Wl,--fatal-warnings)
list(APPEND SDK_LINKER_FLAGS_EXE
  -Wl,--gc-sections
  -Wl,-z,nocopyreloc)
if(SDK_STL MATCHES "^c\\+\\+_" AND SDK_ARCH_ABI MATCHES "^armeabi")
  list(APPEND SDK_LINKER_FLAGS -Wl,--exclude-libs,libunwind.a)
endif()
list(APPEND SDK_C_FLAGS
  -funwind-tables
  -fstack-protector-strong
  -no-canonical-prefixes
  -Wa,--noexecstack
  -Wformat -Werror=format-security)

# combine
string(REPLACE ";" " " SDK_C_FLAGS          "${SDK_C_FLAGS}")
string(REPLACE ";" " " SDK_CXX_FLAGS        "${SDK_CXX_FLAGS}")
string(REPLACE ";" " " SDK_LINKER_FLAGS     "${SDK_LINKER_FLAGS}")
string(REPLACE ";" " " SDK_LINKER_FLAGS_EXE "${SDK_LINKER_FLAGS_EXE}")

# Set or retrieve the cached flags.
# This is necessary in case the user sets/changes flags in subsequent
# configures. If we included the Android flags in here, they would get
# overwritten.
set(CMAKE_C_FLAGS "" CACHE STRING "Flags used by the compiler during all build types.")
set(CMAKE_CXX_FLAGS "" CACHE STRING "Flags used by the compiler during all build types.")
set(CMAKE_ASM_FLAGS "" CACHE STRING "Flags used by the compiler during all build types.")
set(CMAKE_MODULE_LINKER_FLAGS "" CACHE STRING "Flags used by the linker during the creation of modules.")
set(CMAKE_SHARED_LINKER_FLAGS "" CACHE STRING "Flags used by the linker during the creation of dll's.")
set(CMAKE_EXE_LINKER_FLAGS "" CACHE STRING "Flags used by the linker.")

set(CMAKE_C_FLAGS             "${SDK_C_FLAGS} ${CMAKE_C_FLAGS}")
set(CMAKE_CXX_FLAGS           "${SDK_C_FLAGS} ${SDK_CXX_FLAGS} ${CMAKE_CXX_FLAGS}")
set(CMAKE_ASM_FLAGS           "${SDK_C_FLAGS} ${CMAKE_ASM_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${SDK_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS "${SDK_LINKER_FLAGS} ${CMAKE_MODULE_LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS    "${SDK_LINKER_FLAGS} ${SDK_LINKER_FLAGS_EXE} ${CMAKE_EXE_LINKER_FLAGS}")

# Support automatic link of system libraries
set(CMAKE_CXX_CREATE_SHARED_LIBRARY "<CMAKE_CXX_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>")
set(CMAKE_CXX_CREATE_SHARED_MODULE  "<CMAKE_CXX_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>")
set(CMAKE_CXX_LINK_EXECUTABLE       "<CMAKE_CXX_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} ${SDK_LIB}")
set(CMAKE_CXX_CREATE_SHARED_MODULE  "${CMAKE_CXX_CREATE_SHARED_MODULE} ${SDK_LIB}")
set(CMAKE_CXX_LINK_EXECUTABLE       "${CMAKE_CXX_LINK_EXECUTABLE} ${SDK_LIB}")

# vim:ft=cmake et ts=2 sts=2 sw=2:
