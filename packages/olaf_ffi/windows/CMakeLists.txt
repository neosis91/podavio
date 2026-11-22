cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "olaf_ffi")
project(${PROJECT_NAME} LANGUAGES C)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(olaf_ffi_bundled_libraries
  $<TARGET_FILE:olaf_ffi>
  PARENT_SCOPE
)
