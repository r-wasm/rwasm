PKG_CPPFLAGS=-I$(WASM)/include -I../inst/include -I$(WASM)/include/proj -DPROJ_H_API
PKG_LIBS=-L$(WASM)/lib -lgdal -lssl -lcrypto -llzma -ljpeg -lpng -lz -lpcre2-8 -lxml2 -ltiff -lsqlite3 -lproj
CXX_STD=CXX17
