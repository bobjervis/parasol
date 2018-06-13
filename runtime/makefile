#   Copyright 2015 Robert Jervis
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

COMMON_FILES = $(wildcard runtime/common/*.cc)
RUNTIME_FILES = $(wildcard runtime/Parasol/*.cc)
LIB_FILES = $(wildcard runtime/library/*.cc)

COMMON_OBJECTS = $(COMMON_FILES:runtime/common/%.cc=build/o/%.o)
RUNTIME_OBJECTS = $(RUNTIME_FILES:runtime/Parasol/%.cc=build/o/%.o)
LIB_OBJECTS = $(LIB_FILES:runtime/library/%.cc=build/o/%.o)

CFLAGS = -std=c++11 -O3 -I runtime -fPIC

all: build/libparasol.so.1 build/parasolrt 

build/parasolrt: build/prep $(RUNTIME_OBJECTS)
	$(CXX) $(CFLAGS) -Lbuild -o build/parasolrt $(RUNTIME_OBJECTS) -lpthread -ldl -lparasol

build/libparasol.so.1: build/prep $(COMMON_OBJECTS) $(LIB_OBJECTS)
	$(CXX) $(CFLAGS) -fPIC -shared -o $@ $(COMMON_OBJECTS) $(LIB_OBJECTS) -lpthread -ldl
	ln -sfT libparasol.so.1 build/libparasol.so

$(COMMON_OBJECTS): build/o/%.o : runtime/common/%.cc
	$(CXX) $(CFLAGS) -c $< $(LIB_PATH) $(LIBS) -o $@

$(RUNTIME_OBJECTS): build/o/%.o : runtime/Parasol/%.cc
	$(CXX) $(CFLAGS) -c $< $(LIB_PATH) $(LIBS) -o $@

$(LIB_OBJECTS): build/o/%.o : runtime/library/%.cc
	$(CXX) $(CFLAGS) -fPIC -c $< $(LIB_PATH) $(LIBS) -o $@

build/prep:
	mkdir -p build/o
	touch build/prep 

clean:
	- rm build/o/*.o
	- rm build/parasolrt

