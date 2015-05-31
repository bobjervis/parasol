namespace parasol:compiler;

enum TypeFamily {
	SIGNED_8,
	SIGNED_16,
	SIGNED_32,
	SIGNED_64,
	UNSIGNED_8,
	UNSIGNED_16,
	UNSIGNED_32,
	UNSIGNED_64,
	FLOAT_32,
	FLOAT_64,
	BOOLEAN,
	STRING,
	VAR,
	ADDRESS,
	VOID,
	ERROR,
	CLASS_VARIABLE,
	CLASS_DEFERRED,
	NAMESPACE,
	BUILTIN_TYPES,
	CLASS,
	ENUM,
	TYPEDEF,
	FUNCTION,
	VECTOR,
	TEMPLATE,
	TEMPLATE_INSTANCE,
	MAX_TYPES
//	MIN_TYPE = SIGNED_8
}

class CompileString {
	pointer<byte> data;
	int length;

	CompileString() {
	}

	CompileString(ref<byte[]> value) {
		length = value.length();
		data = &(*value)[0];
	}
	
	CompileString(pointer<byte> value) {
		length = strlen(value);
		data = value;
	}
	
	CompileString(string s) {
		length = s.length();
		data = &s[0];
	}

	boolean equals(CompileString other) {
		if (length != other.length)
			return false;
		for (int i = 0; i < length; i++)
			if (data[i] != other.data[i])
				return false;
		return true;
	}

	boolean equals(pointer<byte> other) {
		if (length != strlen(other))
			return false;
		for (int i = 0; i < length; i++)
			if (data[i] != other[i])
				return false;
		return true;
	}
	
	string asString() {
		return string(data, length);
	}
}

class Location {
	public static Location OUT_OF_FILE(-1);

	public int		offset;
	
	public Location(int v) {
		offset = v;
	}
/*
	bool operator==(Location &loc) const {
		return offset == loc.offset;
	}

	bool operator>(Location &loc) const {
		return offset > loc.offset;
	}

	bool operator<(Location &loc) const {
		return offset < loc.offset;
	}
*/
	int compare(Location loc) {
		return offset - loc.offset;
	}

	boolean isInFile() {
		return offset != OUT_OF_FILE.offset;
	}
}
