# SPDX-License-Identifier: MPL-2.0

if(NOT DEFINED CTS_BINARY_DIR)
    message(FATAL_ERROR "CTS_BINARY_DIR is required")
endif()

if(NOT DEFINED REPORT_DIR)
    message(FATAL_ERROR "REPORT_DIR is required")
endif()

if(NOT DEFINED RUNTIME_JSON)
    message(FATAL_ERROR "RUNTIME_JSON is required")
endif()

if(NOT DEFINED CTS_GRAPHICS_PLUGIN)
    set(CTS_GRAPHICS_PLUGIN "metal")
endif()

if(NOT DEFINED CTS_FILTER)
    set(CTS_FILTER "exclude:[interactive]")
endif()

set(CTS_CLI_DIR "${CTS_BINARY_DIR}/src/conformance/conformance_cli")
set(CTS_CLI "${CTS_CLI_DIR}/conformance_cli")
set(CTS_XML_NAME "automated_${CTS_GRAPHICS_PLUGIN}.xml")

if(NOT EXISTS "${CTS_CLI}")
    message(FATAL_ERROR "CTS CLI not found at ${CTS_CLI}")
endif()

file(MAKE_DIRECTORY "${REPORT_DIR}")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            "XR_RUNTIME_JSON=${RUNTIME_JSON}"
            "${CTS_CLI}"
            "${CTS_FILTER}"
            -G "${CTS_GRAPHICS_PLUGIN}"
            --reporter "ctsxml::out=${CTS_XML_NAME}"
            --reporter console
    WORKING_DIRECTORY "${CTS_CLI_DIR}"
    OUTPUT_VARIABLE CTS_STDOUT
    ERROR_VARIABLE CTS_STDERR
    RESULT_VARIABLE CTS_RESULT
)

file(WRITE "${REPORT_DIR}/baseline.txt" "${CTS_STDOUT}")
if(NOT "${CTS_STDERR}" STREQUAL "")
    file(APPEND "${REPORT_DIR}/baseline.txt" "\n--- stderr ---\n${CTS_STDERR}")
endif()
if(EXISTS "${CTS_CLI_DIR}/${CTS_XML_NAME}")
    file(COPY_FILE "${CTS_CLI_DIR}/${CTS_XML_NAME}" "${REPORT_DIR}/${CTS_XML_NAME}")
endif()

message("${CTS_STDOUT}")
if(NOT "${CTS_STDERR}" STREQUAL "")
    message("${CTS_STDERR}")
endif()

if(NOT CTS_RESULT EQUAL 0)
    message(FATAL_ERROR "OpenXR CTS CLI failed with exit code ${CTS_RESULT}")
endif()
