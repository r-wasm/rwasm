PKG_CPPFLAGS=-I$(WASM)/include -I$(WASM)/include/proj -DHAVE_PROJ_H -DPROJ_RENAME_SYMBOLS
PKG_LIBS=-L$(WASM)/lib -lgeos -lgeos_c -ljpeg -ltiff -lsqlite3 -lproj -lgdal -lxml2
