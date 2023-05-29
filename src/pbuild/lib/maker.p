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
namespace parasol:pbuild;

import parasol:compiler;
import parasol:compiler.Commentary;
import parasol:compiler.Location;
import parasol:compiler.Node;
import parasol:compiler.Scanner;
import parasol:compiler.Target;
import parasol:context;
import parasol:memory;
import parasol:process;
import parasol:pxi;
import parasol:runtime;
import parasol:script;
import parasol:storage;
import parasol:time;
import parasol:types.Set;

/**
 * All Component objects in a build are either 1) A top-level product (in which case the enclosing Folder is null)
 * or a component to be embedded in a generated folder.
 */
class Component {
	protected ref<Folder> _enclosing;

	Component(ref<Folder> enclosing) {
		_enclosing = enclosing;
	}

	public abstract boolean inputsNewer(time.Instant timeStamp);

	public abstract void print(int indent);

	public abstract boolean getUnitFilenames(ref<string[]> units);

	protected void indent(int amount) {
		if (amount > 0)
			printf("%*c", amount, ' ');
	}		

	boolean copy() {
		printf("Copy %s to %s\n", toString(), _enclosing.path());
		return false;
	}

	abstract string toString();
}

enum Placement {
	FIRST,
	LAST
}

class Folder extends Component {
	protected string _contents;
	protected string _name;
	protected ref<Component>[] _components;

	Folder(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(enclosing);
		ref<script.Atom> a = object.get("name");
		if (a != null)
			_name = a.toString();
		a = object.get("content");
		if (a == null)
			return;
		if (a.class != script.Vector)
			buildFile.collectProducts(this, a);
		else {
			ref<script.Vector> v = ref<script.Vector>(a);
			ref<ref<script.Atom>[]> content = v.value();;
			for (i in *content) {
				ref<script.Atom> a = (*content)[i];
				buildFile.collectProducts(this, a);
			}
		}		
	}

	void add(ref<Component> component) {
		_components.append(component);
	}

	void defineStaticInitializer(Placement placement, ref<BuildFile> buildFile, ref<script.Object> object) {
		buildFile.error(object, "A static initializer list may only appear directly inside a package tag");
	}

	boolean use(ref<BuildFile> buildFile, ref<script.Object> object) {
		buildFile.error(object, "A use reference must be in a package");
		return false;
	}

	ref<Product> include(ref<BuildFile> buildFile, ref<script.Object> object) {
		ref<script.Atom> a = object.get("name");
		string name;
		string src;
		ref<Product> product;
		if (a != null) {
			name = a.toString();
		} else {
			buildFile.error(object, "Must include a name for the object in an include tag");
			return null;
		}
		a = object.get("src");
		if (a != null)
			src = a.toString();
		else {
			buildFile.error(object, "must include a src attribute for the product in an include tag");
			return null;
		}
		a = object.get("type");
		string type;
		if (a != null) {
			type = a.toString();
			switch (type) {
			case	"package":
				if (!context.validatePackageName(src)) {
					buildFile.error(object, "Attribute 'src' must be a valid package name");
					return null;
				}
				product = new IncludePackage(buildFile, this, object, name, src);
				add(product);
				break;

			default:
				buildFile.error(object,"Unknown type: %s", type);
			}
		} else {
			buildFile.error(object,"Must include a product type in an include tag");
		}
		return product;
	}

	void discoverExtraIncludedProducts(ref<Product> includer) {
		for (i in _components) {
			ref<Component> c = _components[i];
			if (c.class == Folder || c.class <= Product)
				ref<Folder>(c).discoverExtraIncludedProducts(includer);
		}
	}

	void findProducts(ref<BuildFile> buildFile, ref<ref<Product>[]> collection) {
		for (i in _components) {
			ref<Component> c = _components[i];
			if (c.class == Folder)
				ref<Folder>(c).findProducts(buildFile, collection);
			else if (c.class <= Product) {
				ref<Product>(c).resolveNames(buildFile);
				collection.append(ref<Product>(c));
			}
		}
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		for (i in _components)
			if (_components[i].inputsNewer(timeStamp))
				return true;
		return false;
	}

	public boolean copyContents() {
		return copy();
	}

	boolean copy() {
		if (!storage.ensure(path())) {
			printf("        FAIL: Could not ensure %s\n", path());
			return false;
		}
		for (int i = 0; i < _components.length(); i++) {
			if (!_components[i].copy())
				return false;
		}
//		printf("Copy %s to %s\n", toString(), _enclosing.path());
		return true;
	}

	public boolean getUnitFilenames(ref<string[]> units) {
		for (i in _components) {
			ref<Component> component = _components[i];

			if (!component.getUnitFilenames(units))
				return false;
		}
		return true;
	}

	public string path() {
		if (_enclosing != null)
			return _enclosing.path() + "/" + _name;
		else
			return _name;
	}

	public string productPath() {
		if (_enclosing != null)
			return _enclosing.productPath() + "/" + _name;
		else
			return _name;
	}

	public ref<Package> package() {
		if (_enclosing != null)
			return _enclosing.package();
		else
			return null;
	}

	string buildDir() {
		if (_enclosing != null)
			return _enclosing.buildDir();
		else
			return null;
	}

	ref<Coordinator> coordinator() {
		if (_enclosing != null)
			return _enclosing.coordinator();
		else
			return null;
	}

	public string toString() {
		string s;
		s.printf("folder %s", _name);
		return s;
	}

	public string name() {
		return _name;
	}

	public void print(int indentAmount) {
		indent(indentAmount);
		printf("%s\n", toString());
		for (i in _components)
			_components[i].print(indentAmount + 4);
	}
}

enum Contents {
	STATIC,
	IMPORT
}

class File extends Component {
	private Monitor _checkLock;
	private string[] _names;
	private time.Instant[] _modified;
	private boolean _srcChecked;
	private boolean _srcCheckSucceeded;
	private string _src;
	private string _name;
	private Contents _contents;

	File(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(enclosing);
		ref<script.Atom> a = object.get("name");
		if (a != null)
			_name = a.toString();
		else
			buildFile.error(object, "'name' attribute required for file tag");
		a = object.get("src");
		if (a != null)
			_src = a.toString();
		else
			buildFile.error(object, "'src' attribute required for file tag");
		a = object.get("contents");
		if (a != null) {
			switch (a.toString()) {
			case "import":
				_contents = Contents.IMPORT;
				break;

			case "static":
				_contents = Contents.STATIC;
				break;

			default:
				buildFile.error(a, "Unexpected element '%s'", a.toString());
			}
		} else
			_contents = Contents.STATIC;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		string src = storage.constructPath(_enclosing.buildDir(), _src);
		boolean success = checkSrc(src, false);
//		time.Date d(timeStamp, &time.UTC);
//		string dt = d.format("MM/dd/yyyy HH:mm:ss.SSS");
		if (!success)
			return true;

//		time.Date d(timeStamp);
//		printf("\n%s/%s newer than %s?", src, _name, d.format("yyyy/MM/dd HH:mm:ss.SSSSSSSSS"));


		for (i in _modified) {
			if (_modified[i].compare(&timeStamp) > 0) {
				if (_enclosing.coordinator().reportOutOfDate()) {
					string srcFile = storage.constructPath(src, _names[i]);
					printf("            %s out of date, building\n", srcFile);
				}
				return true;
			}
		}
		return false;
	}

	public boolean copy() {
		string src = storage.constructPath(_enclosing.buildDir(), _src);
		if (!checkSrc(src, true))
			return false;
		string packageDir = _enclosing.path();
//		printf("Copy %s/%s -> %s\n", src, _name, packageDir);
		for (int i = 0; i < _names.length(); i++) {
			string srcFile = storage.constructPath(src, _names[i]);
			string dstFile = storage.constructPath(packageDir, _names[i]);
			if (!storage.copyFile(srcFile, dstFile)) {
				printf("        FAIL: Copy %s to %s\n", srcFile, dstFile);
				return false;
			}
//			 else
//				printf("  %s -> %s\n", srcFile, dstFile);
		}
		return true;
	}

	public boolean getUnitFilenames(ref<string[]> unitFilenames) {
		string src = storage.constructPath(_enclosing.buildDir(), _src);
		if (!checkSrc(src, true))
			return false;
//		printf("%s:\n", toString());
		string directory = _enclosing.path();
		for (i in _names) {
//			printf("    [%d] %s/%s\n", i, directory, _names[i]);
			unitFilenames.append(storage.constructPath(directory, _names[i]));
		}
		return true;
	}

	private boolean checkSrc(string src, boolean noisy) {
		lock (_checkLock) {
			if (_srcChecked)
				return _srcCheckSucceeded;
			_srcChecked = true;
			if (!storage.exists(src)) {
				if (noisy)
					printf("        FAIL: Source directory %s does not exist\n", src);
				return _srcCheckSucceeded = false;
			}
			if (!storage.isDirectory(src)) {
				if (noisy)
					printf("        FAIL: Source %s is not a directory\n", src);
				return _srcCheckSucceeded = false;
			}
			string path = storage.constructPath(src, _name);
			string[] matching;
			boolean success;
			(matching, success) = storage.expandWildCard(path);
			if (!success) {
				if (noisy)
					printf("        FAIL: Could not expand wildcard %s\n", path);
				return _srcCheckSucceeded = false;
			}
	
			int prefix = src.length() + 1;
			for (int i = 0; i < matching.length(); i++)
				_names.append(matching[i].substr(prefix));
			for (i in _names) {
				string srcFile = storage.constructPath(src, _names[i]);
				time.Instant accessed, modified, created;
				boolean success;
	
				(accessed, modified, created, success) = storage.fileTimes(srcFile);
	
				if (success)
					_modified.append(modified);
				else
					_modified.append(time.Instant.MAX_VALUE);
			}
			return _srcCheckSucceeded = true;
		}
	}

	public string toString() {
		string s;
		switch (_names.length()) {
		case 0:
			s.printf("File '%s'", _name);
			break;

		case 1:
			s.printf("file %s", _names[0]);
			break;

		default:
			s.printf("file (");
			for (int i = 0; i < _names.length(); i++) {
				if (i > 0)
					s.append(',');
				s.append(_names[i]);
			}
			s.printf(")");
		}
		s.printf(" <- %s %s", _src, string(_contents));
		return s;
	}

	Contents contents() {
		return _contents;
	}

	string src() {
		return _src;
	}

	public void print(int indentAmount) {
		indent(indentAmount);
		printf("%s\n", toString());
	}
}

class Link extends Component {
	private string _target;
	private string _name;
	
	Link(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(enclosing);
		ref<script.Atom> a = object.get("name");
		if (a != null)
			_name = a.toString();
		else
			buildFile.error(object, "'name' attribute is required for a link element");
		a = object.get("target");
		if (a != null)
			_target = a.toString();
		else
			buildFile.error(object, "'target' attribute is required for a link element");
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		string linkFile = storage.constructPath(_enclosing.productPath(), _name);
		return !storage.exists(linkFile);
	}

	public boolean copy() {
		string linkFile = storage.constructPath(_enclosing.path(), _name);
//		printf("Link %s <- %s\n", _target, linkFile);
		if (!storage.createSymLink(_target, linkFile)) {
			printf("        FAIL: Link %s to %s\n", _target, linkFile);
			return false;
		}
		return true;
	}

	public boolean getUnitFilenames(ref<string[]> unitFilenames) {
		return true;
	}

	public string toString() {
		string s;
		s.printf("link %s", _target);
		return s;
	}

	public void print(int indentAmount) {
		indent(indentAmount);
		printf("%s\n", toString());
	}
}

