cmake_minimum_required(VERSION 3.10.2)
project("rubik_core")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SOURCE_FILES
    native_cube_pipeline.cpp
)

add_library(rubik_core SHARED ${SOURCE_FILES})

find_library(log-lib log)
target_link_libraries(rubik_core ${log-lib})
