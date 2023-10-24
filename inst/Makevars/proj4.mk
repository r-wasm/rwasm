PKG_CPPFLAGS=-I$(WASM)/include -I$(WASM)/include/proj -DUSE_PROJ6_API
PKG_LIBS=-L$(WASM)/lib -ljpeg -ltiff -lsqlite3 -lproj
