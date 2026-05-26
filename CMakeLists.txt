# SPDX-License-Identifier: MPL-2.0

cmake_minimum_required(VERSION 3.24)
project(OpenXROSX LANGUAGES C CXX OBJCXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
enable_testing()

execute_process(
    COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${CMAKE_SOURCE_DIR}/compile_commands.json
    RESULT_VARIABLE openxr_osx_compile_commands_symlink_result
)

if(NOT openxr_osx_compile_commands_symlink_result EQUAL 0)
    message(STATUS "Failed to create compile_commands.json symlink during configure. The build sync step will retry.")
endif()

# --- FetchContent dependencies ---
include(FetchContent)

# Build a universal (arm64 + x86_64) dylib so x64 apps can load the runtime
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)

# spdlog
FetchContent_Declare(
    spdlog
    GIT_REPOSITORY https://github.com/gabime/spdlog.git
    GIT_TAG v1.15.3
    GIT_SHALLOW ON
)

# glm
FetchContent_Declare(
    glm
    GIT_REPOSITORY https://github.com/g-truc/glm.git
    GIT_TAG 1.0.1
    GIT_SHALLOW ON
)

FetchContent_MakeAvailable(spdlog glm)

# Catch2 for tests
FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.7.1
    GIT_SHALLOW ON
)
FetchContent_MakeAvailable(Catch2)

# OpenXR SDK (loader + headers)
FetchContent_Declare(
    OpenXR
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenXR-SDK.git
    GIT_TAG release-1.1.57
    GIT_SHALLOW ON
)
FetchContent_MakeAvailable(OpenXR)

# --- Our runtime ---
add_subdirectory(runtime)

add_custom_target(openxr_osx_sync_compile_commands ALL
    COMMAND ${CMAKE_COMMAND}
        -DINPUT_FILE=${CMAKE_BINARY_DIR}/compile_commands.json
        -DOUTPUT_FILE=${CMAKE_SOURCE_DIR}/compile_commands.json
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/SyncCompileCommands.cmake
    COMMENT "Syncing compile_commands.json to the project root"
)

# --- Tests ---
add_executable(openxr_osx_tests
    tests/TestConfig.cpp
    tests/TestInputManager.cpp
    tests/TestProtocolLayout.cpp
    runtime/src/InputManager.cpp
    runtime/src/TrackingReceiver.cpp
    runtime/src/Config.cpp
)
target_include_directories(openxr_osx_tests PRIVATE
    runtime/src
    clients/common/src
    ${openxr_SOURCE_DIR}/include
)
target_link_libraries(openxr_osx_tests PRIVATE
    Catch2::Catch2WithMain
    glm::glm
    spdlog::spdlog
)
target_compile_definitions(openxr_osx_tests PRIVATE
    XR_USE_GRAPHICS_API_METAL
)
add_test(NAME openxr_osx_tests COMMAND openxr_osx_tests)

add_executable(openxr_osx_status_tests
    tests/TestRuntimeStatus.cpp
    runtime/src/RuntimeStatus.cpp
    runtime/src/Config.cpp
)
target_include_directories(openxr_osx_status_tests PRIVATE
    runtime/src
)
target_link_libraries(openxr_osx_status_tests PRIVATE
    Catch2::Catch2WithMain
    spdlog::spdlog
)
add_test(NAME openxr_osx_status_tests COMMAND openxr_osx_status_tests)

add_executable(openxr_osx_runtime_tests
    tests/TestRuntimeApi.cpp
)
target_include_directories(openxr_osx_runtime_tests PRIVATE
    runtime/src
    ${openxr_SOURCE_DIR}/include
)
target_link_libraries(openxr_osx_runtime_tests PRIVATE
    Catch2::Catch2WithMain
    OpenXR::openxr_loader
)
target_compile_definitions(openxr_osx_runtime_tests PRIVATE
    XR_USE_GRAPHICS_API_METAL
)
add_dependencies(openxr_osx_runtime_tests openxr_osx)
add_test(NAME openxr_osx_runtime_tests COMMAND openxr_osx_runtime_tests)
set_tests_properties(openxr_osx_runtime_tests PROPERTIES
    ENVIRONMENT "XR_RUNTIME_JSON=$<TARGET_FILE_DIR:openxr_osx>/openxr_osx.json"
)

add_dependencies(openxr_osx_sync_compile_commands
    openxr_osx
    openxr_osx_tests
    openxr_osx_status_tests
    openxr_osx_runtime_tests
)

option(OPENXR_OSX_ENABLE_CTS "Fetch and wire an opt-in OpenXR CTS lane" OFF)

add_custom_target(openxr_osx_set_default_runtime
    COMMAND /bin/zsh ${CMAKE_CURRENT_SOURCE_DIR}/scripts/openxr_runtime_default.sh set $<TARGET_FILE_DIR:openxr_osx>/openxr_osx.json
    DEPENDS openxr_osx
    USES_TERMINAL
    COMMENT "Registering the generated OpenXR manifest as the default runtime for this user"
)

if(OPENXR_OSX_ENABLE_CTS)
    include(ExternalProject)

    set(OPENXR_OSX_CTS_TAG "openxr-cts-1.1.57.0" CACHE STRING "Pinned OpenXR CTS tag")
    set(OPENXR_OSX_CTS_GRAPHICS_PLUGIN "metal" CACHE STRING "Graphics plugin to use for the CTS baseline")
    set(OPENXR_OSX_CTS_FILTER "exclude:[interactive]" CACHE STRING "Catch2 filter used for the CTS baseline")
    set(OPENXR_OSX_CTS_PREFIX_DIR "${CMAKE_BINARY_DIR}/thirdparty/OpenXR-CTS")
    set(OPENXR_OSX_CTS_SOURCE_DIR "${OPENXR_OSX_CTS_PREFIX_DIR}/source")
    set(OPENXR_OSX_CTS_BINARY_DIR "${OPENXR_OSX_CTS_PREFIX_DIR}/build")
    set(OPENXR_OSX_CTS_REPORT_DIR "${CMAKE_BINARY_DIR}/reports/openxr-cts")

    ExternalProject_Add(openxr_cts
        GIT_REPOSITORY https://github.com/KhronosGroup/OpenXR-CTS.git
        GIT_TAG ${OPENXR_OSX_CTS_TAG}
        GIT_SHALLOW ON
        PREFIX "${OPENXR_OSX_CTS_PREFIX_DIR}"
        SOURCE_DIR "${OPENXR_OSX_CTS_SOURCE_DIR}"
        BINARY_DIR "${OPENXR_OSX_CTS_BINARY_DIR}"
        CMAKE_ARGS
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        UPDATE_DISCONNECTED ON
        INSTALL_COMMAND ""
        EXCLUDE_FROM_ALL ON
    )

    add_custom_target(openxr_cts_run
        COMMAND ${CMAKE_COMMAND} -E make_directory "${OPENXR_OSX_CTS_REPORT_DIR}"
        COMMAND ${CMAKE_COMMAND}
            -DCTS_BINARY_DIR=${OPENXR_OSX_CTS_BINARY_DIR}
            -DREPORT_DIR=${OPENXR_OSX_CTS_REPORT_DIR}
            -DRUNTIME_JSON=$<TARGET_FILE_DIR:openxr_osx>/openxr_osx.json
            -DCTS_GRAPHICS_PLUGIN=${OPENXR_OSX_CTS_GRAPHICS_PLUGIN}
            -DCTS_FILTER=${OPENXR_OSX_CTS_FILTER}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunOpenXRCTS.cmake
        DEPENDS openxr_cts openxr_osx
        USES_TERMINAL
        COMMENT "Running the pinned OpenXR CTS baseline against the OpenXR OSX runtime"
    )
endif()
