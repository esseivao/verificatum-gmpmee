if(NOT DEFINED PYTHON_EXECUTABLE)
    message(FATAL_ERROR "PYTHON_EXECUTABLE is required")
endif()

if(NOT DEFINED GEN_TRIALDIV)
    message(FATAL_ERROR "GEN_TRIALDIV is required")
endif()

if(NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "OUTPUT_FILE is required")
endif()

if(NOT DEFINED WORD_SIZE)
    message(FATAL_ERROR "WORD_SIZE is required")
endif()

set(_args)
if(SAFE_TRIALDIV)
    list(APPEND _args -safe)
endif()
list(APPEND _args "${WORD_SIZE}")

execute_process(
    COMMAND "${PYTHON_EXECUTABLE}" "${GEN_TRIALDIV}" ${_args}
    OUTPUT_FILE "${OUTPUT_FILE}"
    RESULT_VARIABLE _result
)

if(NOT _result EQUAL 0)
    file(REMOVE "${OUTPUT_FILE}")
    message(FATAL_ERROR "Failed to generate ${OUTPUT_FILE}")
endif()
