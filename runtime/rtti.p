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
namespace parasol:runtime;

public enum TypeFamily {
	// BuiltInType - all of the following can appear as the family of a built-in
	// type. Each of them is a singleton type.

	// numeric types
	
	SIGNED_8("rpc.marshalSigned8", "rpc.unmarshalSigned8"),
	SIGNED_16("rpc.marshalShort", "rpc.unmarshalShort"),				// class short
	SIGNED_32("rpc.marshalInt", "rpc.unmarshalInt"),				// class int
	SIGNED_64("rpc.marshalLong", "rpc.unmarshalLong"),				// class long
	UNSIGNED_8("rpc.marshalByte", "rpc.unmarshalByte"),				// class byte
	UNSIGNED_16("rpc.marshalChar", "rpc.unmarshalChar"),				// class char
	UNSIGNED_32("rpc.marshalUnsigned", "rpc.unmarshalUnsigned"),			// class unsigned
	UNSIGNED_64("rpc.marshalUnsigned64", "rpc.unmarshalUnsigned64"),
	FLOAT_32("rpc.marshalFloat", "rpc.unmarshalFloat"),				// class float
	FLOAT_64("rpc.marshalDouble", "rpc.unmarshalDouble"),				// class double

	// various formats of string

	STRING("rpc.marshalString", "rpc.unmarshalString"),
	STRING16("rpc.marshalString16", "rpc.unmarshalString16"),
	SUBSTRING("rpc.marshalSubstring", "rpc.unmarshalSubstring"),
	SUBSTRING16("rpc.marshalSubstring16", "rpc.unmarshalSubstring16"),

	// Other kinds of runtime object.
	
	BOOLEAN("rpc.marshalBoolean", "rpc.unmarshalBoolean"),
	VAR,
	ADDRESS,
	EXCEPTION,
	CLASS_VARIABLE,			// An object of type 'class'. It should be a synonym for ref<runtime.Class>

	// pseudo-types - these things are not classes. There can be no instances of them.

	NAMESPACE,				// A namespace reference has this type no object can have this type.
	ARRAY_AGGREGATE,		// only occurs on an array aggregate during type analysis.
	OBJECT_AGGREGATE,		// only occurs on an object aggregate during type analysis.
	VOID,					// only occurs on a function return type during the initial phase of type analysis.
	ERROR,					// marks a node that is in error.
	CLASS_DEFERRED,			// only occurs within a template definition.

	BUILTIN_TYPES,			// spacer to mark the extent of 'built-in' types. No Type object will have this family
	
	CLASS,					// Each class declaration creates a ClassType with this family.
	INTERFACE,				// Each interface declaration creates an InterfaceType with this family.
	ENUM,					// The type of an enum instance. The enum class (if any) is actually given CLASS family.
	FLAGS,					// The type of a flags instance. The flags type is given TYPEDEF family.
	FUNCTION,				// Any function.

	// class synonyms - each of these sub-families are understood to be some kind of class.

	SHAPE,					// Any instance of a vector<E, K> or map<E, K>. This will appear as the family of a
							// template instance class of a template declared with @Shape annotation.
	REF,					// Any instance of ref<T>. This will appear as the family of such an instance.
	POINTER,				// Any instance of pointer<T>. This will appear as the family of such an instance.
	TEMPLATE_INSTANCE,		// Any instance class of an ordinary template.

	// pseudo-types 

	TEMPLATE,				// A template definition. No object will have this Type.
	TYPEDEF,				// This is a marker for a compile-time class expression  and
							// contains a reference to the underlying class type (or to CLASS_DEFERRED
							// within a template definition.

	MAX_TYPES				// marker for the end of types. No Type object will have this family.
	;

	private string _marshaller;
	private string _unmarshaller;

	TypeFamily() { }

	TypeFamily(string marshaller, string unmarshaller) {
		_marshaller = marshaller;
		_unmarshaller = unmarshaller;
	}

	public boolean hasMarshaller() {
		return _marshaller != null;
	}

	public string marshaller() {
		return _marshaller;
	}

	public string unmarshaller() {
		return _unmarshaller;
	}
}


/**
 * All objects thata can exist at runtime have a corresponding runtime.Class object
 * stored in the image.
 */
public class Class extends CommonFields {
	private ref<Class> _base;				// If the class has a base class, this is it.
	private ref<Interface>[] _interfaces;	// A possibly empty array of interfaces.
	private boolean _monitor;				// true if this is a montor class.
	private TypeFamily _family;				// The 'family' of types this class belongs to.

	//@Constant
	public static int BASE_OFFSET = int(&ref<Class>(null)._base);
	public static int MONITOR_OFFSET = int(&ref<Class>(null)._monitor);
	public static int FAMILY_OFFSET = int(&ref<Class>(null)._family);
	/**
	 * Compares two classes and returns an appropriate value:
	 * <ul>
	 *		<li> 0.0 - The two classes are equal
	 *      <li> &lt; 0.0 - This class is a strict sub-type of the other class
	 *      <li> &gt; 0.0 - This class is a struct super-type of the other class
	 *      <li> NaN = The two classes are unrelated.
	 * </ul>
	 * Note that this method allows compariison of types using any of the Parasol
	 * comparison operators.
	 */
	public float compare(ref<Class> other) {
		// This is transtion code. It should be removed when no longer needed.
		if (_magic == MAGIC) {
			assert(other._magic == MAGIC);
		} else {
			assert(other._magic != MAGIC);
			if (this == other)
				return 0.0f;
			ref<compiler.Type> t1 = ref<compiler.Type>(this);
			ref<compiler.Type> t2 = ref<compiler.Type>(other);
			if (t1.isSubtype(t2))
				return -1.0f;
			else if (t2.isSubtype(t1))
				return 1.0f;
			else
				return float.NaN;
		}
		if (this == other)
			return 0.0f;
		else if (this.doesExtend(other))
			return -1.0f;
		else if (other.doesExtend(this))
			return 1.0f;
		else
			return float.NaN;
	}

	private boolean doesExtend(ref<Class> other) {
		if (_base == other)
			return true;
		else if (_base != null)
			return _base.doesExtend(other);
		else
			return false;
	}
	/**
	 * Determines whether this class implements a named interface.
	 *
	 * @param iface The interface to look for.
	 *
	 * @return true if the interface argument is implemented by this class,
	 * false otherwise.
	 */
	public boolean doesImplement(ref<Interface> iface) {
		for (i in _interfaces)
			if (_interfaces[i].moniker == iface.moniker)
				return true;
		return false;
	}
	/**
	 * Return any base class for this class.
	 *
	 * @return Null if this class does not extend any other class,
	 * otherwise return a reference to the base class.
	 */
	public ref<Class> base() {
		return _base;
	}
	/**
	 * Detect whether a class is a monitor class.
	 *
	 * @return true if this is a monitor class, false otherwise.
	 */
	public boolean isMonitorClass() {
		return _monitor;
	}

	public TypeFamily family() {
		// This is transtion code. It should be removed when no longer needed.
		if (_magic != MAGIC)
			return ref<compiler.Type>(this).family();
		return _family;
	}

	public int interfaceCount() {
		return _interfaces.length();
	}

	public ref<Interface> getInterface(int i) {
		return _interfaces[i];
	}
}
/**
 * A descriptor that identifies an interface as implemented for a specific class.
 */
public class Interface extends CommonFields {
	long moniker;						// A unique value 
}

private class CommonFields {
	protected long _magic;					// A magic number identifying the version of generated
											// runtime type info in the image.
	protected string _name;					// The declared name identifier of the class.
	protected string _namespace;			// The namespace, if any, in which the class is defined.
	protected string _prefix;				// The prefix, if any, which fully qualifies the name
											// of the class within it's namespace.
	protected string _suffix;				// The suffix, if any, which qualifies the name.
	protected string _fullSuffix;			// The full suffix, if any, which uniquely identifies the class.
	/**
	 * The simple identifer used to declare the class, plus any template parameters
	 * that are part of this class' name.
	 *
	 * @return A non-null string that will tend to be short, but may not be unique
	 * within the running program.
	 */
	public string name() {
		if (_suffix != null)
			return _name + _suffix;
		else
			return _name;
	}
	/**
	 * The fully qualified name of the class. This string is unique in the running program.
	 *
	 * @return A non-null string that will uniquely identify the class in the running program.
	 */
	public string fullName() {
		string result;

		if (_namespace != null)
			result = _namespace + ".";
		if (_prefix != null)
			result += _prefix + ".";
		result += _name;
		if (_fullSuffix != null)
			result += _fullSuffix;
		return result;
	}
	/**
	 * A magic number stored with each rtti object to identify the version of the stored data.
	 * The process of generating code means that the rtti tables generated by the initial version
	 * of the compiler conforms to the declarations in the old compiler, but it is generating code
	 * that is based on the newest sources. So those sources, if they change the rtti data, must 
	 * check the magic number and change behavior according to what it finds.
	 *
	 * So the development sequence, when making breaking changes to the rtti data is to:
	 * <ol>
	 *     <li>Create an OLD_MAGIC variable and give it the value that has appeared in the rtti 
	 *         in previous builds.
	 *     <li>Change the value of MAGIC to any new value that will be just as unique as the old.
	 *     <li>Add any code to the runtime that is needed to work around the differences that have
	 *         been introduced. How much or how little depends on the nature of the breaking changes.
	 *     <li>When the new code has been put through a full build and 'update_git' tests, the
	 *         compiler is now generating new RTTI data with the new magic number in it.
	 *     <li>The OLD_MAGIC and any other code that was created to manage the bridge between new and
	 *         old can be removed, leaving MAGIC and the new rtti table classes only.
	 *     <li>The compiler is put through another cycle of 'update_git' tests to confirm that all
	 *         is well.
	 *     <li>The compiler can be committed and pushed to github.
	 * </ol>
	 *
	 * Most of the time, nothing special will have to be done here. The old compiler and any new compiler
	 * build and process the same rtti information.
	 *
	 * Obviously, once the compiler has reached public release (runtime version gets set to 2.0.0 or higher),
	 * this procedure can no longer be used.
	 * Parasol can never make deliberate breaking changes to core runtime features like RTTI again.
	 * Once published, users will rely on rtti data and may write utilities that use it.
	 */
	public static long MAGIC = 0x0123456789abcdef;
}
