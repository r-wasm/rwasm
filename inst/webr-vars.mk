# Configure your local environment in this file. Make sure to set
# `WEBR_ROOT` to the root directory of the webR repo
-include ~/.webr-vars.mk

WASM = $(WEBR_ROOT)/wasm
HOST = $(WEBR_ROOT)/host
TOOLS = $(WEBR_ROOT)/tools

# Select emfc implementation
-include $(WEBR_ROOT)/tools/fortran.mk

R_VERSION = $(shell cat $(WEBR_ROOT)/R/R-VERSION)
R_SOURCE = $(WEBR_ROOT)/R/build/R-$(R_VERSION)
R_HOME = $(WEBR_ROOT)/wasm/R-$(R_VERSION)/lib/R

EM_LIBS := -s USE_BZIP2=1
EM_LIBS += -s USE_ZLIB=1

WASM_OPT := $(WASM_OPT)
WASM_OPT += -Oz

WASM_COMMON_FLAGS := $(WASM_OPT)
WASM_COMMON_FLAGS += -fPIC
WASM_COMMON_FLAGS += -fwasm-exceptions
WASM_COMMON_FLAGS += -s SUPPORT_LONGJMP=wasm

WASM_CFLAGS := $(WASM_CFLAGS)
WASM_CFLAGS += $(WASM_COMMON_FLAGS)
WASM_CFLAGS += -std=gnu11

WASM_CXXFLAGS := $(WASM_CXXFLAGS)
WASM_CXXFLAGS += $(WASM_COMMON_FLAGS)
WASM_CXXFLAGS += -DRCPP_DEMANGLER_ENABLED=0
WASM_CXXFLAGS += -D__STRICT_ANSI__

WASM_CPPFLAGS := $(WASM_CPPFLAGS)
WASM_CPPFLAGS += -I$(WASM)/include
WASM_CPPFLAGS += -I$(R_SOURCE)/build/include
WASM_CPPFLAGS += -I$(R_SOURCE)/src/include
WASM_CPPFLAGS += $(EM_LIBS)

WASM_FFLAGS := $(WASM_FFLAGS)
WASM_FFLAGS += -O2

WASM_LDFLAGS := $(WASM_LDFLAGS)
WASM_LDFLAGS += -s SIDE_MODULE=1
WASM_LDFLAGS += -s WASM_BIGINT
WASM_LDFLAGS += -s ASSERTIONS=1
WASM_LDFLAGS += -L$(WASM)/lib
WASM_LDFLAGS += -L$(WASM)/R-$(R_VERSION)/lib/R/lib
WASM_LDFLAGS += $(EM_LIBS)
WASM_LDFLAGS += -fwasm-exceptions
WASM_LDFLAGS += -s SUPPORT_LONGJMP=wasm
WASM_LDFLAGS += $(WASM_OPT)

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
CXX = em++ -std=gnu++17
FC = $(EMFC)

CFLAGS = $(WASM_CFLAGS)
CPPFLAGS = $(WASM_CPPFLAGS)
CXXFLAGS = $(WASM_CXXFLAGS)
CXX98FLAGS = -std=gnu++98 $(WASM_CXXFLAGS)
CXX11FLAGS = -std=gnu++11 $(WASM_CXXFLAGS)
CXX14FLAGS = -std=gnu++14 $(WASM_CXXFLAGS)
CXX17FLAGS = -std=gnu++17 $(WASM_CXXFLAGS)
CXX20FLAGS = -std=gnu++20 $(WASM_CXXFLAGS)
LDFLAGS = $(WASM_LDFLAGS)

FFLAGS = $(WASM_FFLAGS)
FPICFLAGS = -fPIC
FLIBS = $(FORTRAN_WASM_LDADD)

AR = emar
RANLIB = emranlib

# Uncomment to show emscripten calls to clang for debugging
# CFLAGS += -v
# LDFLAGS += -v

# Filter out any flags in SHLIB_LIBADD that are already given in PKG_LIBS
SHLIB_LIBADD_FILTER = $(filter-out $(PKG_LIBS),$(SHLIB_LIBADD))

# Clear up flags from $(R_HOME)/etc/Makeconf
override DYLIB_LD = $(CC)
override DYLIB_LDFLAGS = $(CFLAGS)
override DYLIB_LINK = $(DYLIB_LD) $(DYLIB_LDFLAGS) $(LDFLAGS)

override SHLIB_OPENMP_CFLAGS =
override SHLIB_OPENMP_CXXFLAGS =
override SHLIB_OPENMP_FFLAGS =
override SHLIB_LDFLAGS =
override SHLIB_LINK = $(SHLIB_LD) $(SHLIB_LDFLAGS) $(LDFLAGS)

override FOUNDATION_LIBS =
override LIBINTL =

override LIBS =
override LIBR =
override ALL_LIBS = $(PKG_LIBS) $(SHLIB_LIBADD_FILTER) $(LIBR) $(LIBINTL)

override STRIP_STATIC_LIB = touch
override STRIP_SHARED_LIB = touch

override BLAS_LIBS = -L$(WEBR_LOCAL)/lib/R/lib -lRblas
override LAPACK_LIBS = -L$(WEBR_LOCAL)/lib/R/lib -lRlapack

override ALL_CPPFLAGS = -DNDEBUG $(PKG_CPPFLAGS) $(CLINK_CPPFLAGS) $(CPPFLAGS)
override ALL_FFLAGS = $(PKG_FFLAGS) $(FPICFLAGS) $(SHLIB_FFLAGS) $(FFLAGS)
override ALL_FCFLAGS = $(P_FCFLAGS) $(FPICFLAGS) $(SHLIB_FFLAGS) $(FCFLAGS)


# Print Makefile variable
.PHONY: print-%
print-%  : ; @echo $* = $($*)
