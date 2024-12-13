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

import parasol:script;
import parasol:storage;

public class MacroSet {
	private string[string] _macros;

	boolean define(string name, string value) {
		if (_macros.contains(name))
			return false;
		_macros[name] = value;
		return true;
	}

	string find(string name) {
		return _macros[name];
	}
}

public class BuildFile {
	public ref<Suite>[] tests;
	public ref<Product>[] products;

	private ref<MacroSet> _macroSet;
	private boolean _macrosAllocated;
	private string _buildFile;
	private string _targetOS;
	private string _targetCPU;
	private void (string, string, var...) _errorMessage;
	private ref<script.Parser> _parser;
	private boolean _detectedErrors;
	private ref<Coordinator> _coordinator;
	private ref<BuildRoot> _buildRoot;

	BuildFile(string buildFile, void (string, string, var...) errorMessage, string targetOS, string targetCPU, 
			  ref<Coordinator> coordinator, ref<MacroSet> macroSet) {
		_buildFile = buildFile;
		_targetOS = targetOS;
		_targetCPU = targetCPU;
		_errorMessage = errorMessage;
		_coordinator = coordinator;
		if (macroSet == null) {
			_macroSet = new MacroSet;
			_macrosAllocated = true;
		} else
			_macroSet = macroSet;
	}

	~BuildFile() {
		tests.deleteAll();
		delete _parser;
//		delete _buildRoot;
		if (_macrosAllocated)
			delete _macroSet;
	}

	public static ref<BuildFile> parse(string buildFile, string content, void (string, string, var...) errorMessage, 
									   string targetOS, string targetCPU, ref<Coordinator> coordinator, string outputDir, 
									   ref<MacroSet> macroSet) {
		if (coordinator.verbose()) {
			if (buildFile != null)
				printf("Parse build file %s", buildFile);
			else
				printf("Parse content '%s'", content);
			if (targetOS != null)
				printf(" os %s", targetOS);
			if (targetCPU != null)
				printf(" cpu %s", targetCPU);
			if (outputDir != null)
				printf(" output %s", outputDir);
			if (macroSet != null)
				printf(" imported");
			else
				printf(" stand-alone");
			printf("\n");
		}
		boolean success = true;
		ref<BuildFile> bf = new BuildFile(buildFile, errorMessage, targetOS, targetCPU, coordinator, macroSet);

		if (content != null)
			bf._parser = script.Parser.loadFromString(buildFile, content);
		else
			bf._parser = script.Parser.load(buildFile);

		ref<script.Atom>[] candidates;
		if (bf._parser != null) {
			bf._parser.content(&candidates);
			bf._parser.log = new BuildFileLog(errorMessage);
			if (!bf._parser.parse()) {
				errorMessage(buildFile, "Parse failed");
				return null;
			}
		} else {
			ref<Reader> r = storage.openTextFile(buildFile);
			if (r != null) {
				errorMessage(buildFile, "Parse failed");
				delete r;
			} else
				errorMessage(buildFile, "Could not open");
			return null;
		}

		bf._buildRoot = new BuildRoot(outputDir);

		for (i in candidates)
			bf.collectProducts(bf._buildRoot, candidates[i]);

		if (bf._detectedErrors)
			success = false;

		if (candidates.length() == 0) {
			errorMessage(buildFile, "No products to build");
			return null;
		}
		if (success)
			return bf;
		else {
			delete bf;
			return null;
		}
	}

	void collectProducts(ref<Folder> enclosing, ref<script.Atom> candidate) {
		if (candidate.class == script.Object) {
			ref<script.Object> object = ref<script.Object>(candidate);
			switch (object.get("tag").toString()) {
			case "tests":
				tests.append(new Suite(this, object));
//				tests[tests.length() - 1].print(0);
				break;

			case "target":
				ref<script.Atom> a = object.get("os");
				if (a != null) {
					string os = a.toString();
					switch (os) {
					case "windows":
					case "linux":
						break;
			
					default:
						error(a, "'os' attribute must be 'linux' or 'windows'");
					}
					if (os != _targetOS)
						break;
				}
				a = object.get("cpu");
				if (a != null) {
					string cpu = a.toString();
					switch (cpu) {
					case "x86-64":
						break;
			
					default:
						error(a, "'cpu' attribute must be 'x86-64'");
					}
					if (cpu != _targetCPU)
						break;
				}
				// target tag passed all tested criteria, so include it's contents
				a = object.get("content");
				if (a == null)
					break;
				if (a.class != script.Vector)
					collectProducts(enclosing, a);
				else {
					ref<script.Vector> v = ref<script.Vector>(a);
					ref<ref<script.Atom>[]> content = v.value();;
					for (i in *content) {
						ref<script.Atom> a = (*content)[i];
						collectProducts(enclosing, a);
					}
				}
				break;

			case "package":
				if (enclosing != null && enclosing.class != BuildRoot)
					error(object, "A package cannot be defined inside another component");
				ref<Package> p = new Package(this, enclosing, object);
				products.append(p);
				break;

			case "folder":
				if (enclosing != null) {
					ref<Folder> f = new Folder(this, enclosing, object);
					enclosing.add(f);
				} else
					error(object, "Folder must be part of a package");
				break;

			case "file":
				if (enclosing != null) {
					ref<File> f = new File(this, enclosing, object);
					enclosing.add(f);
				} else
					error(object, "File must be part of a package");
				break;

			case "init":
				if (enclosing != null) {
					a = object.get("placement");
					if (a != null) {
						switch (a.toString()) {
						case "first":
							enclosing.defineStaticInitializer(Placement.FIRST, this, object);
							break;

						case "last":
							enclosing.defineStaticInitializer(Placement.LAST, this, object);
							break;

						default:
							error(a, "Placement attribute must be first or last");
						}
					} else
						error(object, "Static initializer list must have a placement attribute");
				} else
					error(object, "Init must be part of a package");
				break;

			case "command":
				if (enclosing != null && enclosing.class != BuildRoot)
					error(object, "A command cannot be defined inside another component");
				ref<Command> c = new Command(this, enclosing, object);
				products.append(c);
				break;

			case "application":
				if (enclosing != null && enclosing.class != BuildRoot)
					error(object, "An application cannot be defined inside another component");
				ref<Application> b = new Application(this, enclosing, object);
				products.append(b);
				break;

			case "pxi":
				if (enclosing == null)
					error(object, "A pxi must be defined in a package");
				else {
					ref<Pxi> pxi = new Pxi(this, enclosing, object);
					enclosing.add(pxi);
					products.append(pxi);
				}
				break;

			case "elf":
				if (enclosing == null)
					error(object, "An elf must be defined in a package");
				else {
					ref<Elf> e = new Elf(this, enclosing, object);
					enclosing.add(e);
					products.append(e);
				}
				break;

			case "link":
				if (enclosing == null)
					error(object, "A link must be defined in a package");
				else {
					ref<Link> l = new Link(this, enclosing, object);
					enclosing.add(l);
				}
				break;

			case "use":
				if (enclosing == null)
					error(object, "A use reference must be in a package");
				else if (!enclosing.use(this, object))
					_detectedErrors = true;
				break;
	
			case "include":
				if (enclosing == null)
					error(object, "An include reference must be in a package");
				else {
					ref<Product> p = enclosing.include(this, object);
					if (p != null)
						products.append(p);
					else
						_detectedErrors = true;
				}
				break;
			
			case "import":
				if (enclosing != null && enclosing.class != BuildRoot)
					error(object, "An import cannot be declared inside a component");
				_coordinator.parseBuildFile(this, object);
				break;

			case "define":
				props := object.properties();
				for (key in *props) {
					prop := (*props)[key];
					switch (key) {
					case	"tag":
					case	"content":
					case	"parent":
						break;

					default:
						_macroSet.define(key, prop.toString());
					}
				}
				break;

			default:
				error(object, "Unknown tag '%s'", object.get("tag").toString());
			}
		}
	}

	private boolean collectContents(ref<Folder> folder, ref<script.Object> object) {
		boolean success = true;
		return success;
	}

	public string, boolean expandMacros(ref<script.Atom> atom) {
		src := atom.toString();
		string dest;
		boolean success = true;

		for (int i = 0; i < src.length(); i++) {
			c := src[i];
			if (c == '$') {
				n := referenceSpan(&src[i + 1]);
				if (n < 0)
					dest.append(c);
				else {
					nm := src.substr(i + 2, i + n - 1);
					i += n;
					v := _macroSet.find(nm);
					if (v != null)
						dest.append(v);
					else {
						dest += "${" + nm + "}";
						success = false;
					}
				}
			} else
	        	dest.append(c);
		}
		return dest, success;
	}

	private static int referenceSpan(pointer<byte> bp) {
		if (*bp != '{')
			return -1;
		span := 2;
		while (*bp != '}') {
			if (*bp == 0)
				return -1;
			span++;
			bp++;
		}
		return span;
	}

	void error(ref<script.Atom> a, string msg, var... args) {
		_detectedErrors = true;
		_parser.log.error(a != null ? a.offset() : 0, msg, args);
	}

	ref<Coordinator> coordinator() {
		return _coordinator;
	}

	ref<BuildRoot> buildRoot() {
		return _buildRoot;
	}

	ref<MacroSet> macroSet() {
		return _macroSet;
	}

	string path() {
		return _buildFile;
	}
}

class BuildFileLog extends script.MessageLog {
	void (string, string, var...) _errorMessage;

	BuildFileLog(void (string, string, var...) errorMessage) {
		_errorMessage = errorMessage;
	}

	public void error(int offset, string msg, var... args) {
		string prefix;

		prefix.printf("%s %d", filename(), lineNumber(offset));
		_errorMessage(prefix, msg, args);
	}
}
