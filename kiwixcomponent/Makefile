all: build
CXX    = c++
CPPFLAGS += -fno-rtti -fno-exceptions -shared -D_POSIX_ -O3
TEST_DEFINES = -D_POSIX_
GECKO_SDK_PATH = ../gecko-sdk
GECKO_DEFINES   = -DXPCOM_GLUE -DMOZILLA_STRICT_API
GECKO_IDL_INCLUDES = -I $(GECKO_SDK_PATH)/idl
GECKO_INCLUDES = -I  $(GECKO_SDK_PATH)/include
GECKO_LDFLAGS =   -L $(GECKO_SDK_PATH)/lib -lxpcomglue -lnspr4 -lplds4 -lembed_base_s

IWikiComponent.h: IWikiComponent.idl
	$(GECKO_SDK_PATH)/bin/xpidl -m header $(GECKO_IDL_INCLUDES) IWikiComponent.idl

IWikiComponent.xpt: IWikiComponent.idl
	$(GECKO_SDK_PATH)/bin/xpidl -m typelib $(GECKO_IDL_INCLUDES) IWikiComponent.idl
	
IWikiComponent.so: wikicomponent.cpp IWikiComponent.h xengine.o xlist.o xindex.o
	$(CXX) -o IWikiComponent.so -DXPCOM_BUILD $(GECKO_DEFINES) $(GECKO_INCLUDES) $(GECKO_LDFLAGS) $(CPPFLAGS) $(CXXFLAGS) wikicomponent.cpp xengine.o xlist.o xindex.o
	chmod +x IWikiComponent.so

build: IWikiComponent.so IWikiComponent.xpt
	
clean:
	rm IWikiComponent.so IWikiComponent.xpt xlist.o xindex.o xengine.o

install: IWikiComponent.so IWikiComponent.xpt
	cp IWikiComponent.so ../../kiwix-cd/components
	cp IWikiComponent.xpt ../../kiwix-cd/components
	
xindex.o: index.cpp index.h list.h common.h
	$(CXX) index.cpp -c -o xindex.o -DXPCOM_BUILD $(GECKO_INCLUDES) $(CPPFLAGS)

xlist.o:	list.cpp list.h common.h
	$(CXX) list.cpp -c -o xlist.o -DXPCOM_BUILD $(GECKO_INCLUDES)  $(CPPFLAGS)

xengine.o: engine.cpp list.h index.h common.h
	$(CXX) engine.cpp -c -o xengine.o -DXPCOM_BUILD $(GECKO_INCLUDES)  $(CPPFLAGS)

index.o: index.cpp index.h list.h common.h
	$(CXX) index.cpp -c -o index.o $(TEST_DEFINES)

list.o:	list.cpp list.h common.h
	$(CXX) list.cpp -c -o list.o $(TEST_DEFINES)

engine.o: engine.cpp list.h index.h common.h
	$(CXX) engine.cpp -c -o engine.o $(TEST_DEFINES)

test:	main.cpp index.o list.o engine.o
	$(CXX) main.cpp index.o list.o engine.o -o test $(TEST_DEFINES)

cleantest:
	rm index.o list.o engine.o test
