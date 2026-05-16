cmake_minimum_required(VERSION 3.22)

project(GMPMEE
    VERSION 3.0.0
    DESCRIPTION "GMP extension for fast fixed-base and simultaneous modular exponentiation plus safe-prime generation"
    LANGUAGES C
)

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Keep multi-config generators such as Visual Studio from scattering
# related runtime, library, and import-library artifacts unpredictably.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>")

# Options
option(BUILD_SHARED_LIBS "Build shared library" ON)
option(BUILD_TESTING "Build test/benchmark executable" ON)
option(ENABLE_SANITIZERS "Enable sanitizers for Debug builds" OFF)
option(ENABLE_COVERAGE "Enable code coverage" OFF)

# Dependencies
find_package(GMP REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(GMPMEE_TRIALDIV_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c"
    "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c"
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_32.c
            -DWORD_SIZE=32
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_64.c
            -DWORD_SIZE=64
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_32.c
            -DSAFE_TRIALDIV=ON
            -DWORD_SIZE=32
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c"
    COMMAND "${CMAKE_COMMAND}"
            -DPYTHON_EXECUTABLE=${Python3_EXECUTABLE}
            -DGEN_TRIALDIV=${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py
            -DOUTPUT_FILE=${CMAKE_CURRENT_BINARY_DIR}/trialdiv_safe_64.c
            -DSAFE_TRIALDIV=ON
            -DWORD_SIZE=64
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateTrialdiv.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_trialdiv.py"
    VERBATIM
)

add_custom_target(gmpmee_trialdiv_sources DEPENDS ${GMPMEE_TRIALDIV_SOURCES})

# Main library
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
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)

target_compile_options(gmpmee PRIVATE
    $<$<C_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -fstack-protector-strong>
    $<$<C_COMPILER_ID:MSVC>:/W4>
    $<$<AND:$<CONFIG:Release>,$<C_COMPILER_ID:GNU,Clang,AppleClang>>:-O3>
    $<$<AND:$<CONFIG:Release>,$<C_COMPILER_ID:MSVC>>:/O2>
)

# Test/benchmark executable
if(BUILD_TESTING)
    add_executable(gmpmee_bin gmpmee.c)
    target_link_libraries(gmpmee_bin PRIVATE gmpmee)
    set_target_properties(gmpmee_bin PROPERTIES
        OUTPUT_NAME "gmpmee"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>"
    )
    add_dependencies(gmpmee_bin gmpmee)
endif()

# Sanitizers
if(ENABLE_SANITIZERS AND CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        target_compile_options(gmpmee PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_link_options(gmpmee PRIVATE -fsanitize=address,undefined)
        if(BUILD_TESTING)
            target_compile_options(gmpmee_bin PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer)
            target_link_options(gmpmee_bin PRIVATE -fsanitize=address,undefined)
        endif()
    endif()
endif()

# Coverage
if(ENABLE_COVERAGE)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        target_compile_options(gmpmee PRIVATE --coverage)
        target_link_options(gmpmee PRIVATE --coverage)
        if(BUILD_TESTING)
            target_compile_options(gmpmee_bin PRIVATE --coverage)
            target_link_options(gmpmee_bin PRIVATE --coverage)
        endif()
    endif()
endif()

# Installation and export
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS gmpmee
    EXPORT GMPMEETargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(EXPORT GMPMEETargets
    FILE GMPMEETargets.cmake
    NAMESPACE GMPMEE::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/GMPMEE
)

configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/GMPMEEConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/GMPMEEConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/GMPMEE
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/GMPMEEConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/GMPMEEConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/GMPMEEConfigVersion.cmake
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindGMP.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/GMPMEE
)

# pkg-config
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/gmpmee.pc.in
               ${CMAKE_CURRENT_BINARY_DIR}/gmpmee.pc @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/gmpmee.pc
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

# Testing
if(BUILD_TESTING)
    enable_testing()
    add_test(NAME gmpmee_basic COMMAND gmpmee_bin 800)
endif()

message(STATUS "GMPMEE ${PROJECT_VERSION} configured")
