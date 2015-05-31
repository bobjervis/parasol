class Container {
	ref<Target>[] data;
	
	ref<Target>[] get() {
		return data;
	}
		
}

class Target {
	int targetData;
	int x;
}


Container y;

Target z;

z.targetData = 35;
z.x = 1;

y.data.append(null);
y.data.append(&z);

ref<Target> t =  y.get()[z.x];

assert(t.targetData == 35);

