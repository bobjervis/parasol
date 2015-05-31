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