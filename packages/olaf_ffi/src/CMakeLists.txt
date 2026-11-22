cmake_minimum_required(VERSION 3.10)

project(olaf_ffi_library VERSION 0.0.1 LANGUAGES C)

set(OLAF_SOURCES
  "olaf_podavio.c"
  "third_party/olaf/pffft.c"
  "third_party/olaf/olaf_config.c"
  "third_party/olaf/olaf_fft.c"
  "third_party/olaf/olaf_ep_extractor.c"
  "third_party/olaf/olaf_fp_extractor.c"
  "third_party/olaf/olaf_max_filter_perceptual_van_herk.c"
)

add_library(olaf_ffi SHARED ${OLAF_SOURCES})

target_include_directories(olaf_ffi PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/third_party/olaf"
)

target_compile_definitions(olaf_ffi PRIVATE
  DART_SHARED_LIB
  _GNU_SOURCE
  NDEBUG
)

set_target_properties(olaf_ffi PROPERTIES
  PUBLIC_HEADER olaf_podavio.h
  OUTPUT_NAME "olaf_ffi"
  C_VISIBILITY_PRESET hidden
)

if(MSVC)
  target_compile_definitions(olaf_ffi PRIVATE
    _CRT_SECURE_NO_WARNINGS
    _CRT_NONSTDC_NO_DEPRECATE
    _USE_MATH_DEFINES
    strdup=_strdup
  )
  target_compile_options(olaf_ffi PRIVATE /W3 /O2)
else()
  target_compile_options(olaf_ffi PRIVATE -O3 -std=gnu11 -Wall -Wno-unused-function -Wno-unused-parameter)
  if(NOT APPLE)
    target_link_libraries(olaf_ffi PRIVATE m)
  endif()
endif()

if(ANDROID)
  target_link_options(olaf_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
