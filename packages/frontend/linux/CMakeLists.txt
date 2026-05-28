cmake_minimum_required(VERSION 3.13)
project(biolab_labsync LANGUAGES CXX)

set(BINARY_NAME "BioLab LABSYNC")
set(PROJECT_NAME "biolab_labsync")

set(FLUTTER_MANAGED_DIR "flutter")

add_subdirectory(${FLUTTER_MANAGED_DIR})
add_subdirectory(runner)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
