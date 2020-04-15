# This module is the main entry point of Gateau's cmake modules distribution.
# It should be include near the top of each project's top level CMakeLists.txt.
include_guard()

# Enforce minimum version
if (CMAKE_MINIMUM_REQUIRED_VERSION VERSION_LESS "3.15")
    cmake_minimum_required(VERSION 3.15)
endif()

# Guard against in-source builds
if (CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)
    message(FATAL_ERROR "In-source builds not allowed. Please make a new directory\n
                         (called a build directory) and run CMake from there.\n
                         You may need to remove CMakeCache.txt.")
endif()

if (NOT DEFINED PROJECT_NAME)
    message(FATAL_ERROR "project() must be call prior to Gateau inclusion")
endif()

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

# Include the other modules
include(GateauHelpers)
include(GateauCompilerOptions)
include(GateauProject)
include(GateauAddTarget)
include(GateauAddTest)
include(GateauQtHelpers)
include(GateauFindPackage)
include(GateauDoxygen)
include(GateauInstallProject)

gateau_init()