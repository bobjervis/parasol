/*
   Copyright 2015 Rovert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */


boolean abstractCallHit;

class Abstracted {
	public abstract void f(int x, int y, byte... z);
	
	void funcx() {
		// This should compile just fine.
		f(1, 2);
	}
}

class Concrete extends Abstracted {
	private int _local;
	
	public Concrete() {
		_local = 4;
	}
	
	public void f(int x, int y, byte... z) {
		if (_local == 4)
			abstractCallHit = true;
	}
	
}

Concrete concrete;

func(&concrete);

assert(abstractCallHit);

void func(ref<Abstracted> a) {
	a.f(1, 2, 'a');
}

