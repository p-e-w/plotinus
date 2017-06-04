project(plotinus C)

cmake_minimum_required(VERSION 2.8)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

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
vala_precompile(VALA_C ${CMAKE_PROJECT_NAME}
  src/Command.vala
  src/CommandExtractor.vala
  src/CommandList.vala
  src/InstanceSettings.vala
  src/Keybinder.vala
  src/Module.vala
  src/PopupWindow.vala
  src/Service.vala
  src/Utilities.vala
PACKAGES
  gtk+-3.0>=3.16
  posix
)

include(GSettings)
add_schema(data/com.worldwidemann.plotinus.gschema.xml)

add_executable(dbus_service ${VALA_C})
add_library(gtk_module SHARED ${VALA_C})

set_target_properties(dbus_service gtk_module PROPERTIES OUTPUT_NAME ${CMAKE_PROJECT_NAME})

install(TARGETS dbus_service gtk_module
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib)
