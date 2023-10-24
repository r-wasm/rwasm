PKG_CPPFLAGS=-I$(WASM)/include
PKG_LIBS=-L$(WASM)/lib

pkg = maps
CP = cp
ECHO = echo
RM = rm -f
MKDIR = mkdir
AWK = awk

.PHONY: all shlib mapdata gdata ldata ndata clean objects world2
all: shlib mapdata

mapdir = ../inst/mapdata
mapdata: gdata ldata ndata

GDATA = county.G state.G usa.G nz.G world.G world2.G italy.G france.G state.vbm.G \
        state.carto.G lakes.G
LDATA = county.L state.L usa.L nz.L world.L world2.L italy.L france.L state.vbm.L \
        state.carto.L lakes.L
NDATA = county.N state.N usa.N nz.N world.N world2.N italy.N france.N state.vbm.N \
        state.carto.N lakes.N

%.L: %.line
	@$(MKDIR) -p $(mapdir)
	./Lmake 0 s b ${*}.line ${*}.linestats $(mapdir)/${*}.L

%.G: %.gon
	./Gmake b ${*}.gon ${*}.gonstats $(mapdir)/${*}.G $(mapdir)/${*}.L

%.N: %.name
	@$(MKDIR) -p $(mapdir)
	@$(CP) ${*}.name $(mapdir)/${*}.N

state.carto.L: state.carto.line state.carto.linestats Lmake
	@$(MKDIR) -p $(mapdir)
	./Lmake 0 p b state.carto.line state.carto.linestats $(mapdir)/state.carto.L

state.vbm.L: state.vbm.line state.vbm.linestats Lmake
	@$(MKDIR) -p $(mapdir)
	./Lmake 0 p b state.vbm.line state.vbm.linestats $(mapdir)/state.vbm.L

gdata: Gmake Lmake world2.line $(LDATA) $(GDATA)

ndata: world2.line $(NDATA)

Lmake Gmake: Lmake.c Gmake.c
	cc Gmake.c -o Gmake
	cc Lmake.c -o Lmake

world2.line: world.line
	@$(ECHO) "Converting world to world2"
	$(AWK) -f ./convert.awk < world.line > world2.line
	@$(CP) world.linestats world2.linestats

# the shared library
SHLIB = $(pkg)$(SHLIB_EXT)
OBJECTS = init.o mapclip.o mapget.o smooth.o thin.o 
libdir = ../libs
