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
import parasol:runtime;

public abstract pointer<byte> builtInFunctionName(int index);
public abstract pointer<byte> builtInFunctionDomain(int index);
public abstract address builtInFunctionAddress(int index);
public abstract int builtInFunctionArguments(int index);
public abstract int builtInFunctionReturns(int index);

printf("%2s %-24s %-10s %16s %8s %8s\n", "#", "  name", "domain", "location", "args", "returns");
for (int i = 0; runtime.builtInFunctionName(i) != null; i++) {
	string name(runtime.builtInFunctionName(i));
	string domain(runtime.builtInFunctionDomain(i));
	
	address location = runtime.builtInFunctionAddress(i);
	int arguments = runtime.builtInFunctionArguments(i);
	int returns = runtime.builtInFunctionReturns(i);
	
	printf("%2d %-24s %-10s %16p %8d %8d\n", i, name, domain, location, arguments, returns);
}