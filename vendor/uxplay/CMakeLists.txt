cmake_minimum_required(VERSION 3.20)
project(uxplay_airplay C)

# Build for Apple Silicon only (arm64)
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build for arm64")

# Optimization flags
set(CMAKE_C_FLAGS "-O2 -Wall ${CMAKE_C_FLAGS}")

# Enable NOHOLD feature (allows new connections to replace existing ones)
add_definitions(-DNOHOLD)

# libplist version defines
add_definitions(-DPLIST_210)
add_definitions(-DPLIST_230)

# --- playfair static library ---
add_library(playfair STATIC
    lib/playfair/hand_garble.c
    lib/playfair/modified_md5.c
    lib/playfair/omg_hax.c
    lib/playfair/playfair.c
    lib/playfair/sap_hash.c
)
target_include_directories(playfair PRIVATE lib/playfair)

# --- llhttp static library ---
add_library(llhttp STATIC
    lib/llhttp/api.c
    lib/llhttp/http.c
    lib/llhttp/llhttp.c
)
target_include_directories(llhttp PRIVATE lib/llhttp)

# --- airplay static library (main UxPlay protocol core) ---
file(GLOB AIRPLAY_SOURCES lib/*.c)
add_library(airplay STATIC ${AIRPLAY_SOURCES})

target_include_directories(airplay PRIVATE
    lib
    lib/playfair
    lib/llhttp
)

target_link_libraries(airplay
    pthread
    playfair
    llhttp
)

# OpenSSL (static linking on macOS)
set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/opt/homebrew/opt/openssl@3/lib/pkgconfig")
find_package(PkgConfig REQUIRED)
pkg_check_modules(OPENSSL REQUIRED openssl>=1.1.1)
find_library(LIBCRYPTO libcrypto.a PATHS ${OPENSSL_LIBRARY_DIRS} REQUIRED)
target_link_libraries(airplay ${LIBCRYPTO})
target_include_directories(airplay PRIVATE ${OPENSSL_INCLUDE_DIRS})

# libplist (static linking on macOS)
set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/opt/homebrew/lib/pkgconfig")
pkg_search_module(PLIST REQUIRED libplist-2.0)
find_library(LIBPLIST libplist-2.0.a REQUIRED)
target_link_libraries(airplay ${LIBPLIST})
target_include_directories(airplay PRIVATE ${PLIST_INCLUDE_DIRS})

# dns_sd is native on macOS (provided by mDNSResponder), no extra linking needed
