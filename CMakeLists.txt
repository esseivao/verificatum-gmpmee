cmake_minimum_required(VERSION 3.22)

project(GMPMEECanary
    VERSION 0.0.0
    LANGUAGES C
)

include(CTest)

add_custom_target(gmpmee_canary ALL
    COMMAND ${CMAKE_COMMAND} -E echo "GMPMEE canary build target"
)

add_test(NAME gmpmee_canary_configured
    COMMAND ${CMAKE_COMMAND} -E echo "GMPMEE canary CMake project configured"
)
