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
int[] a;

int b;

a.append(23);
a.append(17);
a.append(-4);

b = +=a;

assert(b == 36);

float[] indep, dep;

indep.append(1.0f);
indep.append(2.0f);
indep.append(3.0f);

dep.append(0.5f);
dep.append(0.7f);
dep.append(0.9f);

float sum = +=(indep * dep);

printf("sum = %g\n", sum);

assert(sum == (1.0f*0.5f)+(2.0f*0.7f)+(3.0f*0.9f));
