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
namespace parasol:context;

import parasol:compiler;
import parasol:pbuild;
import parasol:thread;
import parasol:time;

public class PseudoContext extends Context {
	ref<Context> _base;
	ref<Package>[string] _packages;

	public PseudoContext(ref<Context> base) {
		_base = base;
	}

	public boolean definePackage(ref<Package> p) {
		if (_packages.contains(p.name()))
			return false;
		_packages[p.name()] = p;
		return true;
	}

	public ref<Package> getPackage(string name) {
//		printf("pseudo getting %s\n", name);
		ref<Package> p = _packages[name];
		if (p != null) {
//			printf("Found it !\n");
			return p;
		} else
			return _base.getPackage(name);
	}
}

public class PseudoPackage extends Package {
	private boolean _open;
	private ref<pbuild.Package> _buildPackage;

	public PseudoPackage(ref<Context> owner, ref<pbuild.Package> buildPackage) {
		super(owner, buildPackage.name(), null);
		_buildPackage = buildPackage;
	}

	public boolean open() {
		if (!_open) {
			boolean success = _buildPackage.future().get();
			if (!success)
				return false;
			setDirectory(_buildPackage.packageDir());
			assert(loadManifest());
			_open = true;
		}
		return true;
	}
	/**
	 * Retrieve a list of units that are members of the namespace referenced by the 
	 * function argument.
	 *
	 * @param namespaceNode A compiler namespace parse tree node containing the namespace
	 * that must be fetched.
	 *
	 * @return A list of zero of more filenames where the units assigned to that namespace
	 * can be found. If the length of the array is zero, this package does not contain
	 * any units in that namespace.
	 */
	public string[] getNamespaceUnits(string domain, string... namespaces) {
		string[] a;

		if (!_open) {
			boolean success = _buildPackage.future().get();
			if (!success)
				return a;
			setDirectory(_buildPackage.packageDir());
			assert(loadManifest());
			_open = true;
		}

		assert(namespaces.length() > 0);
//		printf("PseudoContext.getnamespaceUnits %s:%s...(%d)\n", domain, namespaces[0], namespaces.length());
		return super.getNamespaceUnits(domain, namespaces);
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		return _buildPackage.inputsNewer(timeStamp);
	}

	public string directory() {
		return _buildPackage.path();
	}

	public ref<pbuild.Package> buildPackage() {
		return _buildPackage;
	}
}

