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

class ManifestFile {
	private string _manifestFile;
	private ref<script.Atom>[] _directives;
	private ref<script.Parser> _parser;
	private boolean _detectedErrors;

	ManifestFile(string manifestFile) {
		_manifestFile = manifestFile;
	}

	boolean parse(void (string, string, var...) errorMessage, ref<Coordinator> coordinator) {
		_parser = script.Parser.load(_manifestFile);
		if (_parser != null) {
			_parser.content(&_directives);
			_parser.log = new BuildFileLog(errorMessage);
			if (!_parser.parse()) {
				errorMessage(_manifestFile, "Parse failed");
				return false;
			}
		} else {
			ref<Reader> r = storage.openTextFile(_manifestFile);
			if (r != null) {
				errorMessage(_manifestFile, "Parse failed");
				delete r;
			} else
				errorMessage(_manifestFile, "Could not open");
			return false;
		}
		return true;
	}

	boolean apply(ref<Coordinator> coordinator) {
		for (i in _directives) {
			d := _directives[i];

			if (d.class == script.Object) {
				object := ref<script.Object>(d);
				a := object.get("name");
				if (a == null) {
					error(object, "Must provide a name attribute");
					break;
				}
				v := object.get("version");
				if (v == null) {
					error(object, "Must provide a version attribute");
					break;
				}
				switch (object.get("tag").toString()) {
				case "package":
					if (!coordinator.setProductVersion(a.toString(), v.toString()))
						_parser.log.error(object.offset(), "Could not set the package version of " + a.toString());
					break;

				case "pxi":
					if (!coordinator.setProductVersion(a.toString(), v.toString()))
						_parser.log.error(object.offset(), "Could not set the pxi version of " + a.toString());
					break;

				case "application":
					if (!coordinator.setProductVersion(a.toString(), v.toString()))
						_parser.log.error(object.offset(), "Could not set the application version of " + a.toString());
					break;

				default:
					error(object, "Unknown tag '%s'", object.get("tag").toString());
				}
			}
		}
		return !_detectedErrors;
	}

	void error(ref<script.Atom> a, string msg, var... args) {
		_detectedErrors = true;
		_parser.log.error(a != null ? a.offset() : 0, msg, args);
	}
}

