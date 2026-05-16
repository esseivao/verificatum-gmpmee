cmake_minimum_required(VERSION 3.22)

project(GMPMEE_Canary
    VERSION 3.0.0
    DESCRIPTION "Canary build of GMPMEE"
    LANGUAGES C
)

option(BUILD_SHARED_LIBS "Build shared library" ON)
include(CTest)

# 1. Find GMP. CMake has no built-in FindGMP module on many runners, so keep
# this fallback local to the canary project.
find_package(GMP QUIET)
if(NOT GMP_FOUND)
    find_path(GMP_INCLUDE_DIR NAMES gmp.h)
    find_library(GMP_LIBRARY NAMES gmp libgmp)
    if(NOT GMP_INCLUDE_DIR OR NOT GMP_LIBRARY)
        message(FATAL_ERROR "GMP not found")
    endif()
    add_library(GMP::GMP UNKNOWN IMPORTED)
    set_target_properties(GMP::GMP PROPERTIES
        IMPORTED_LOCATION "${GMP_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${GMP_INCLUDE_DIR}"
    )
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(GMPMEE_TRIALDIV_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c"
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/GenerateTrialdiv.cmake" [=[
execute_process(
    COMMAND "${PYTHON_EXECUTABLE}" "${GEN_TRIALDIV}" ${GEN_TRIALDIV_ARGS}
    OUTPUT_FILE "${OUTPUT_FILE}"
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    file(REMOVE "${OUTPUT_FILE}")
    message(FATAL_ERROR "Failed to generate ${OUTPUT_FILE}")
endif()
]=])

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DGEN_TRIALDIV_ARGS=32
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c
            -P "${CMAKE_CURRENT_BINARY_DIR}/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DGEN_TRIALDIV_ARGS=64
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c
            -P "${CMAKE_CURRENT_BINARY_DIR}/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            "-DGEN_TRIALDIV_ARGS=-safe;32"
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c
            -P "${CMAKE_CURRENT_BINARY_DIR}/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            "-DGEN_TRIALDIV_ARGS=-safe;64"
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c
            -P "${CMAKE_CURRENT_BINARY_DIR}/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_target(gmpmee_trialdiv_sources DEPENDS ${GMPMEE_TRIALDIV_SOURCES})

# 2. Real library sources.
add_library(gmpmee
    spowm.c
    spowm_clear.c
    spowm_precomp.c
    spowm_init.c
    spowm_table.c
    spowm_block_batch.c
    spowm_naive.c

    array_alloc.c
    array_alloc_init.c
    array_clear_dealloc.c
    array_urandomb.c

    fpowm.c
    fpowm_clear.c
    fpowm_init.c
    fpowm_precomp.c
    fpowm_init_precomp.c

    millerrabin_init.c
    millerrabin_next_cand.c
    millerrabin_clear.c
    millerrabin_trial.c
    millerrabin_once.c
    millerrabin_reps_rs.c
    millerrabin_rs.c
    millerrabin_next_rs.c

    millerrabin_safe_init.c
    millerrabin_safe_next_cand.c
    millerrabin_safe_clear.c
    millerrabin_safe_trial.c
    millerrabin_safe_reps_rs.c
    millerrabin_safe_rs.c
    millerrabin_safe_next_rs.c

    probab_prime_p_next.c
    probab_safe_prime_p.c
    probab_safe_prime_p_next.c
)

add_dependencies(gmpmee gmpmee_trialdiv_sources)

target_include_directories(gmpmee PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(gmpmee PUBLIC GMP::GMP)

set_target_properties(gmpmee PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    PUBLIC_HEADER "gmpmee.h"
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS OFF
)

# 3.+4. Test binary + proper linking.
if(BUILD_TESTING)
    add_executable(gmpmee_bin gmpmee.c)
    target_link_libraries(gmpmee_bin PRIVATE gmpmee)

    # Critical for MSVC multi-config builds.
    set_target_properties(gmpmee_bin PROPERTIES
        OUTPUT_NAME "gmpmee"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>"
    )

    add_dependencies(gmpmee_bin gmpmee)
endif()

# 5. Enable CTest.
if(BUILD_TESTING)
    add_test(NAME gmpmee_basic
        COMMAND gmpmee_bin 800
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/$<CONFIG>
    )
endif()

message(STATUS "GMPMEE Canary configured successfully")
