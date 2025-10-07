
cmake_minimum_required(VERSION 3.10)
project(whisper)

# Set a default build type if none is specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Option to build shared libraries
option(BUILD_SHARED_LIBS "Build shared libraries" ON)

set(WHISPER_SRC
    src/whisper.cpp/ggml.c
    src/whisper.cpp/whisper.cpp
)

set(WHISPER_INCLUDE_DIRS
    src/whisper.cpp
    src/json
)

include_directories(${WHISPER_INCLUDE_DIRS})

add_library(whisper ${WHISPER_SRC})

target_include_directories(whisper PUBLIC ${WHISPER_INCLUDE_DIRS})

# Add platform-specific flags
if(MSVC)
    # Windows-specific settings
elseif(CMAKE_SYSTEM_NAME MATCHES "Darwin")
    # macOS/iOS specific settings
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG -pthread")
elseif(CMAKE_SYSTEM_NAME MATCHES "Linux" OR CMAKE_SYSTEM_NAME MATCHES "Android")
    # Linux/Android specific settings
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG -pthread")
    
    # Android-specific: Add 16KB page alignment for compatibility
    if(CMAKE_SYSTEM_NAME MATCHES "Android")
        set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
    endif()
endif()

# Installation
install(TARGETS whisper
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)

install(
    DIRECTORY src/whisper.cpp/
    DESTINATION include/whisper
    FILES_MATCHING PATTERN "*.h"
)
