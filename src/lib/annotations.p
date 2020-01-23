/*
   Copyright 2015 Robert Jervis

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
namespace parasol:compiler;

import parasol:text;
/**
 * Eventually, there should be some mechanism for extending annotations, but for now
 * here is the master list of annotations.
 */
public enum Annotations {
	ERROR,
	COMPILE_TARGET("CompileTarget"),
	CONSTANT("Constant"),
	HEADER("Header"),
	LAYOUT("Layout"),
	LINUX("Linux"),
	POINTER("Pointer"),
	REF("Ref"),
	SHAPE("Shape"),
	WINDOWS("Windows"),
	MAX_ANNOTATION
;
	private static Annotations[string] _byName;
	private static int index;

	Annotations() {
		if (index == 0) {
			pointer<long> lp = pointer<long>(&_byName);
			*lp = 0;
			lp[1] = 0;
		}
		index++;
	}

	Annotations(string name) {
//		text.memDump(&_byName, _byName.bytes);
		_byName[name] = Annotations(index++);
	}

	public static Annotations byName(string name) {
		if (_byName.contains(name))
			return _byName[name];
		else
			return Annotations.ERROR;
	}
}