include Makefile.inc

include ../cxx/Makefile

%.so: %.c
	$(LINK.c) $^ $(LOADLIBES) $(LDLIBS) -shared -rdynamic -fPIC -o $@

%.so: %.cc
	$(LINK.cc) $^ $(LOADLIBES) $(LDLIBS) -shared -rdynamic -fPIC -o $@

%.so: %.o
	$(LINK.o) $^ $(LOADLIBES) $(LDLIBS) -shared -rdynamic -fPIC -o $@

