#!/bin/bash

# Script to embed dynamic libraries into the app bundle
# This makes the app portable across different machines

set -e

echo "Embedding dynamic libraries into app bundle..."

# Get the app bundle path
APP_BUNDLE="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
DEBUG_DYLIB="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME.debug.dylib"

# Create Frameworks directory if it doesn't exist
mkdir -p "$FRAMEWORKS_DIR"

# Function to copy a library and fix its install name
embed_library() {
    local lib_path="$1"
    local lib_name=$(basename "$lib_path")
    
    if [ ! -f "$lib_path" ]; then
        echo "Warning: Library not found: $lib_path"
        return
    fi
    
    echo "Embedding $lib_name..."
    
    # Copy the library to Frameworks directory
    cp -f "$lib_path" "$FRAMEWORKS_DIR/"
    
    # Change the library's install name to use @rpath
    install_name_tool -id "@rpath/$lib_name" "$FRAMEWORKS_DIR/$lib_name"
    
    # Update the executable and debug dylib to look for this library in @rpath
    install_name_tool -change "$lib_path" "@rpath/$lib_name" "$EXECUTABLE" 2>/dev/null || true
    if [ -f "$DEBUG_DYLIB" ]; then
        install_name_tool -change "$lib_path" "@rpath/$lib_name" "$DEBUG_DYLIB" 2>/dev/null || true
    fi
    
    # Also check for any references using the realpath
    local real_path=$(readlink -f "$lib_path" 2>/dev/null || echo "$lib_path")
    if [ "$real_path" != "$lib_path" ]; then
        install_name_tool -change "$real_path" "@rpath/$lib_name" "$EXECUTABLE" 2>/dev/null || true
        if [ -f "$DEBUG_DYLIB" ]; then
            install_name_tool -change "$real_path" "@rpath/$lib_name" "$DEBUG_DYLIB" 2>/dev/null || true
        fi
    fi
    
    # Re-sign the library
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$FRAMEWORKS_DIR/$lib_name" 2>/dev/null || true
}

# Find all OpenSSL libraries
if [ -d "/opt/homebrew/opt/openssl@3/lib" ]; then
    for lib in /opt/homebrew/opt/openssl@3/lib/libcrypto.*.dylib /opt/homebrew/opt/openssl@3/lib/libssl.*.dylib; do
        if [ -f "$lib" ]; then
            embed_library "$lib"
        fi
    done
fi

# Find all libplist libraries
if [ -d "/opt/homebrew/opt/libplist/lib" ]; then
    for lib in /opt/homebrew/opt/libplist/lib/libplist-*.*.dylib; do
        if [ -f "$lib" ]; then
            embed_library "$lib"
        fi
    done
fi

# Handle inter-library dependencies
echo "Fixing inter-library dependencies..."
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$lib" ]; then
        lib_name=$(basename "$lib")
        
        # Get all dependencies
        dependencies=$(otool -L "$lib" | grep -E '(homebrew|/usr/local)' | awk '{print $1}' || true)
        
        for dep in $dependencies; do
            dep_name=$(basename "$dep")
            if [ -f "$FRAMEWORKS_DIR/$dep_name" ]; then
                echo "  Updating dependency in $lib_name: $dep_name"
                install_name_tool -change "$dep" "@rpath/$dep_name" "$lib" 2>/dev/null || true
            fi
        done
        
        # Re-sign after modifications
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$lib" 2>/dev/null || true
    fi
done

echo "Library embedding complete!"

# List what we embedded
echo "Embedded libraries:"
ls -lh "$FRAMEWORKS_DIR"
