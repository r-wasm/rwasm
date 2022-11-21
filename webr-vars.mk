# Configure your local environment in this file. Make sure to set:
#
# - `R_SOURCE` to the directory where R was build with Emscripten
#
# - `LLVM_BUILD_DIR` to the directory where LLVM was built with
#   Flang's dev-ir branch
#
# - `WEBR_LOCAL` to the installation directory of webR
#
# - `R_HOST` to the installation directory of a host R build
-include ~/.webr-vars.mk

R_INCLUDES = -I$(R_SOURCE)/build/include -I$(R_SOURCE)/src/include
EM_LIBS = -s USE_LIBPNG=1
EM_CXX_FIXES = -DRCPP_DEMANGLER_ENABLED=0 -D__STRICT_ANSI__

# Needed because Emscripten's `dlopen()` calls seem to ignore the
# `local` flag?
C_VISIBILITY = -fvisibility=hidden
CXX_VISIBILITY = -fvisibility=hidden

CXX98 = em++
CXX11 = em++
CXX14 = em++
CXX17 = em++
CXX20 = em++
CC = emcc
CXX = em++
CFLAGS = -std=gnu11 $(EM_LIBS) $(R_INCLUDES)
CXXFLAGS = -std=gnu++11 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)
CXX98FLAGS = -std=gnu++98 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)
CXX11FLAGS = -std=gnu++11 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)
CXX14FLAGS = -std=gnu++14 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)
CXX17FLAGS = -std=gnu++17 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)
CXX20FLAGS = -std=gnu++20 $(EM_CXX_FIXES) $(EM_LIBS) $(R_INCLUDES)

LDFLAGS = -s SIDE_MODULE=1 -s WASM_BIGINT -s ASSERTIONS=1
FC = $(LLVM_BUILD_DIR)/../emfc
FLIBS = -L$(WEBR_LOCAL)/../lib -lFortranRuntime
AR = emar
ALL_CPPFLAGS = -DNDEBUG $(PKG_CPPFLAGS) $(CLINK_CPPFLAGS) $(CPPFLAGS)
ALL_FFLAGS =
ALL_FCFLAGS =

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

override BLAS_LIBS = -L$(WEBR_LOCAL)/lib/R/lib -lRblas
override LAPACK_LIBS = -L$(WEBR_LOCAL)/lib/R/lib -lRlapack
