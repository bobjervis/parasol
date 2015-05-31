class A {
	int b, c;
}

A[][] a;

a.resize(2);
int j;
a[j].resize(10);
j++;
a[j].resize(20);
assert(a.length() == 2);
assert(a[0].length() == 10);
assert(a[1].length() == 20);
j = 0;
for (int i = 0; i < a[j].length(); i++)
	a[j][i].b = i * 3 + 7;
int k = 1;
for (int i = 0; i < a[j].length(); i++) {
	a[k][i * 2].c = a[j][i].b - 4;
	a[k][i * 2 + 1].c = a[j][i].b * 17 + 6;
}

for (int i = 0; i < a[j].length(); i++)
	printf("a[0][%d] = %d\n", i, a[j][i].b);

for (int i = 0; i < a[k].length(); i++)
	printf("a[1][%d] = %d\n", i, a[k][i].c);
