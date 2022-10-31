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

RUNTIME_OBJECTS = build/o/executionContext.o build/o/pxi.o
MAIN_OBJECT = build/o/main.o

CFLAGS = -std=c++11 -O3 -I src/C++ -fPIC

all: build/libparasol.so.1 build/parasolrt 

build/parasolrt: build/prep $(MAIN_OBJECT)
	$(CXX) $(CFLAGS) -Lbuild -o build/parasolrt $(MAIN_OBJECT) -lpthread -ldl -lparasol

build/libparasol.so.1: build/prep $(RUNTIME_OBJECTS)
	$(CXX) $(CFLAGS) -shared -o $@ $(RUNTIME_OBJECTS) -lpthread -ldl
	ln -sfT libparasol.so.1 build/libparasol.so

$(RUNTIME_OBJECTS) $(MAIN_OBJECT): build/o/%.o : src/C++/%.cc
	$(CXX) $(CFLAGS) -c $< $(LIB_PATH) $(LIBS) -o $@

build/prep:
	mkdir -p build/o
	touch build/prep 

clean:
	- rm build/o/*.o
	- rm build/parasolrt

