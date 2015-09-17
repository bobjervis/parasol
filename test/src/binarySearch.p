string[] stuff;


stuff.append("abc");
stuff.append("def");
stuff.append("ghi");

int match = stuff.binarySearchClosestGreater("ers");

printf("match = %d\n", match);

assert(match == 2);
