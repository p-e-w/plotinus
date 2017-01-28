project(plotinus C)

cmake_minimum_required(VERSION 2.8)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set(LIB_NAME ${CMAKE_PROJECT_NAME})

find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED
  gtk+-3.0
)
add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES} m)
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.26" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C ${LIB_NAME}
  src/Command.vala
  src/CommandExtractor.vala
  src/CommandList.vala
  src/Keybinder.vala
  src/Module.vala
  src/PopupWindow.vala
  src/Utilities.vala
PACKAGES
  gtk+-3.0>=3.16
)

add_library(${LIB_NAME} SHARED ${VALA_C})
