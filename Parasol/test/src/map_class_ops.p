map<string, string> testMap;

printf("%d\n", long.MIN_VALUE);

assert(testMap.size() == 0);

print("Before\n");
*testMap.createEmpty("abc") = "xyz";
print("After\n");
*testMap.createEmpty("def") = "mno";
print("After 2\n");
assert(testMap.get("abc") == "xyz");
print("Done!\n");

map<string, int> intMap;

intMap.set("abc", 1);

*intMap.createEmpty("def") = 34;

assert(intMap.get("abc") == 1);
