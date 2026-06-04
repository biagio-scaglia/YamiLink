cmake_minimum_required(VERSION 3.4.1)

project(yamilink_core)

add_library(
    yamilink_core
    SHARED
    ../../native_core/yamilink_core.c
)

target_link_libraries(
    yamilink_core
    log
)
