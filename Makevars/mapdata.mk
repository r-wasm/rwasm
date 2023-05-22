PKG_CPPFLAGS=-I$(WASM)/include
PKG_LIBS=-L$(WASM)/lib

CP = cp
ECHO = echo
RM = rm -f 
MKDIR = mkdir
AWK = awk

.PHONY: all gdata ldata ndata world2 lmake gmake
all: gdata ndata

GDATA = china.G japan.G nzHires.G rivers.G worldHires.G world2Hires.G worldLores.G world2Lores.G
LDATA = china.L japan.L nzHires.L rivers.L worldHires.L world2Hires.L worldLores.L world2Lores.L
NDATA = china.N japan.N nzHires.N rivers.N worldHires.N world2Hires.N worldLores.N world2Lores.N
WORLD2 = world2Lores.line world2Hires.line

mapdir = ../inst/mapdata

%.L: %.line
	@$(MKDIR) -p $(mapdir)
	./Lmake 0 s b ${*}.line ${*}.linestats $(mapdir)/${*}.L

%.G: %.gon
	./Gmake b ${*}.gon ${*}.gonstats $(mapdir)/${*}.G $(mapdir)/${*}.L

%.N: %.name
	@$(MKDIR) -p $(mapdir)
	@$(CP) ${*}.name $(mapdir)/${*}.N

.PHONY: all gdata ldata ndata world2

gdata: Gmake ldata $(GDATA)

ldata: Lmake world2 $(LDATA)

ndata: world2 $(NDATA)

world2: $(WORLD2)

Lmake Gmake: Lmake.c Gmake.c
	cc Gmake.c -o Gmake
	cc Lmake.c -o Lmake

world2Hires.name world2Hires.gon world2Hires.line: worldHires.line
	@$(ECHO) "Converting worldHires to world2Hires"
	$(AWK) -f ./convert.awk < worldHires.line > world2Hires.line
	@$(CP) worldHires.linestats world2Hires.linestats
	@$(CP) worldHires.gon world2Hires.gon
	@$(CP) worldHires.gonstats world2Hires.gonstats
	@$(CP) worldHires.name world2Hires.name

world2Lores.name world2Lores.gon world2Lores.line: worldLores.line
	@$(ECHO) "Converting worldLores to world2Lores"
	$(AWK) -f ./convert.awk < worldLores.line > world2Lores.line
	@$(CP) worldLores.linestats world2Lores.linestats
	@$(CP) worldLores.gon world2Lores.gon
	@$(CP) worldLores.gonstats world2Lores.gonstats
	@$(CP) worldLores.name world2Lores.name

OBJECTS = 
