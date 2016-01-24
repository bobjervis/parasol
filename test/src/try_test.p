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
import parasol:exception.DivideByZeroException;

printf("Groundhog day!\n");

try {
	f();
	printf("How did I get here?\n");
	assert(false);
} catch (Exception e) {
	printf("Caught it!\n");
}

try {
	int y = 0;
	int x = 10 / y;
} catch (Exception e) {
	printf("Not expected - should have been a DivideByZeroException\n");
	assert(false);
} catch (DivideByZeroException e) {
	printf("Caught this one too!");
	assert(e.class == DivideByZeroException);
}

printf("Sunset!\n");

void f() {
	printf("Jump!\n");
	throw Exception("Test");
}