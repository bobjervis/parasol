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
GUARD_OBJECT = build/o/main_guard.o
LEAKS_OBJECT = build/o/main_leaks.o

CFLAGS = -std=c++11 -O3 -I src/C++ -fPIC

all: build/parasolrt 

build/parasolrt: build/prep $(MAIN_OBJECT) build/libparasol.so.1
	$(CXX) $(CFLAGS) -Lbuild -o $@ $(MAIN_OBJECT) -lpthread -ldl -lparasol

build/parasolrt_guard: build/prep $(GUARD_OBJECT) build/libparasol.so.1
	$(CXX) $(CFLAGS) -Lbuild -o $@ $(GUARD_OBJECT) -lpthread -ldl -lparasol

build/parasolrt_leaks: build/prep $(LEAKS_OBJECT) build/libparasol.so.1
	$(CXX) $(CFLAGS) -Lbuild -o $@ $(LEAKS_OBJECT) -lpthread -ldl -lparasol

build/libparasol.so.1: build/prep $(RUNTIME_OBJECTS)
	$(CXX) $(CFLAGS) -shared -o $@ $(RUNTIME_OBJECTS) -lpthread -ldl
	ln -sfT libparasol.so.1 build/libparasol.so

$(RUNTIME_OBJECTS) $(MAIN_OBJECT): build/o/%.o : src/C++/%.cc src/C++/executionContext.h
	$(CXX) $(CFLAGS) -c $< $(LIB_PATH) $(LIBS) -o $@

build/prep:
	mkdir -p build/o
	touch build/prep 

$(GUARD_OBJECT): src/C++/main.cc
	$(CXX) $(CFLAGS) -o $@ -DPARASOLRT_HEAP=2 -c $<

$(LEAKS_OBJECT): src/C++/main.cc
	$(CXX) $(CFLAGS) -o $@ -DPARASOLRT_HEAP=1 -c $<

clean:
	- rm build/o/*.o
	- rm build/parasolrt

