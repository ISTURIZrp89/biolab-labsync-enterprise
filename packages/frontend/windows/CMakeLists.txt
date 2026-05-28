cmake_minimum_required(VERSION 3.14)
project(biolab_labsync LANGUAGES CXX)

set(BINARY_NAME "BioLab LABSYNC")
set(PROJECT_NAME "biolab_labsync")

set(FLUTTER_MANAGED_DIR "flutter")

add_subdirectory(${FLUTTER_MANAGED_DIR})
add_subdirectory(runner)

target_compile_definitions(runner PRIVATE "FLUTTER_TARGET=lib\\main.dart")

install(TARGETS runner RUNTIME DESTINATION .)
