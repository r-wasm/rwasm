# Configure your local environment in this file.  In particular,
# `R_SOURCE` must be set to the directory where R was build with
# Emscripten.
-include ~/.webr-vars.mk

CXX98 = em++
CXX11 = em++
CXX14 = em++
CXX17 = em++
CXX20 = em++
CC = emcc
CXX = em++
CFLAGS = -std=gnu11 -I$(R_SOURCE)/build/include
CXXFLAGS = -std=gnu++11 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
CXX98FLAGS = -std=gnu++98 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
CXX11FLAGS = -std=gnu++11 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
CXX14FLAGS = -std=gnu++14 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
CXX17FLAGS = -std=gnu++17 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
CXX20FLAGS = -std=gnu++20 -D__STRICT_ANSI__ -I$(R_SOURCE)/include
LDFLAGS = -s SIDE_MODULE=1 -s WASM_BIGINT -s ASSERTIONS=1
FC = emfc
FLIBS =
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
