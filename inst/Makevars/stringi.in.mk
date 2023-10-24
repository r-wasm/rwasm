## `stringi` Makevars
## Copyright (c) 2013-2021, Marek Gagolewski <https://www.gagolewski.com>


@STRINGI_CXXSTD@

PKG_CPPFLAGS=@STRINGI_CPPFLAGS@
PKG_CXXFLAGS=@STRINGI_CXXFLAGS@ -DU_HAVE_MMAP=0
PKG_CFLAGS=@STRINGI_CFLAGS@ -DU_HAVE_MMAP=0
PKG_LIBS=@STRINGI_LDFLAGS@ @STRINGI_LIBS@

STRI_SOURCES_CPP=@STRINGI_SOURCES_CPP@
STRI_OBJECTS=$(STRI_SOURCES_CPP:.cpp=.o)

ICU_COMMON_SOURCES_CPP=@STRINGI_ICU_COMMON_SOURCES_CPP@
ICU_COMMON_SOURCES_C=@STRINGI_ICU_COMMON_SOURCES_C@
ICU_COMMON_OBJECTS=$(ICU_COMMON_SOURCES_CPP:.cpp=.o) $(ICU_COMMON_SOURCES_C:.c=.o)

ICU_I18N_SOURCES_CPP=@STRINGI_ICU_I18N_SOURCES_CPP@
ICU_I18N_SOURCES_C=@STRINGI_ICU_I18N_SOURCES_C@
ICU_I18N_OBJECTS=$(ICU_I18N_SOURCES_CPP:.cpp=.o) $(ICU_I18N_SOURCES_C:.c=.o)

ICU_STUBDATA_SOURCES_CPP=@STRINGI_ICU_STUBDATA_SOURCES_CPP@
ICU_STUBDATA_SOURCES_C=@STRINGI_ICU_STUBDATA_SOURCES_C@
ICU_STUBDATA_OBJECTS=$(ICU_STUBDATA_SOURCES_CPP:.cpp=.o) $(ICU_STUBDATA_SOURCES_C:.c=.o)

OBJECTS=@STRINGI_OBJECTS@