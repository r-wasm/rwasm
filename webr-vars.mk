# Configure your local environment in this file. Make sure to set:
#
# - `R_SOURCE` to the directory where R was build with Emscripten
#
# - `LLVM_BUILD_DIR` to the directory where LLVM was built with
#   Flang's dev-ir branch
#
# - `WEBR_LOCAL` to the installation directory of webR
-include ~/.webr-vars.mk

R_INCLUDES = -I$(R_SOURCE)/build/include -I$(R_SOURCE)/src/include

# Needed because Emscripten's `dlopen()` calls seem to ignore the
# `local` flag?
C_VISIBILITY = -fvisibility=hidden

CXX98 = em++
CXX11 = em++
CXX14 = em++
CXX17 = em++
CXX20 = em++
CC = emcc
CXX = em++
CFLAGS = -std=gnu11 $(R_INCLUDES)
CXXFLAGS = -std=gnu++11 -D__STRICT_ANSI__ $(R_INCLUDES)
CXX98FLAGS = -std=gnu++98 -D__STRICT_ANSI__ $(R_INCLUDES)
CXX11FLAGS = -std=gnu++11 -D__STRICT_ANSI__ $(R_INCLUDES)
CXX14FLAGS = -std=gnu++14 -D__STRICT_ANSI__ $(R_INCLUDES)
CXX17FLAGS = -std=gnu++17 -D__STRICT_ANSI__ $(R_INCLUDES)
CXX20FLAGS = -std=gnu++20 -D__STRICT_ANSI__ $(R_INCLUDES)
LDFLAGS = -s SIDE_MODULE=1 -s WASM_BIGINT -s ASSERTIONS=1
FC = emfc
FLIBS = -L$(WEBR_LOCAL)/lib -lFortranRuntime
AR = emar
ALL_CPPFLAGS = -DNDEBUG $(PKG_CPPFLAGS) $(CLINK_CPPFLAGS) $(CPPFLAGS)

# Clear up flags from $(R_HOME)/etc/Makeconf
override DYLIB_LD = $(CC)
override DYLIB_LDFLAGS = $(CFLAGS)
override DYLIB_LINK = $(DYLIB_LD) $(DYLIB_LDFLAGS) $(LDFLAGS)

override SHLIB_LDFLAGS =
override SHLIB_LINK = $(SHLIB_LD) $(SHLIB_LDFLAGS) $(LDFLAGS)

override FOUNDATION_LIBS =
override LIBINTL =

override LIBR =
override ALL_LIBS = $(PKG_LIBS) $(SHLIB_LIBADD) $(LIBR) $(LIBINTL)
