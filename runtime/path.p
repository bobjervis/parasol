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
namespace parasol:storage;

import parasol:math;
import parasol:process;
import parasol:runtime;
import native:C;
import native:linux;
import native:windows.GetFullPathName;
/**
 * Construct an absoluute path to the file system entity described by the argument.
 *
 * If the argument names an existing file system entity, then native operating system 
 * facilities are used to construct an absolute path. Thus, under Linux, for example,
 * symbolic links are followed so that the resulting path may have no common elements
 * with the original file path.
 *
 * If the argument does not name an existing file system entity, then a general algorithm
 * will be used that will not recognize things like symbolic links. The general algorithm 
 * will:
 * <ol>
 *   <li> convert any relative path to a fully qualified path by taking the current working
 *        directory and combining that with the function argument.
 *   <li> the resulting fully qualified path has any empty path elements removed.
 *   <li> the resulting fully qualified path has any path elements in it that are '.'
 *        removed.
 *   <li> any path elelments that are '..' are removed as well as the prior path component as well.
 *        If there are unmatched '..' path elements, they are discarded. For example, the path 
 *        {@code /aa/../../bb} will return {@code /bb}.
 *
 * @param filepath The filename path convert to an absolute path.
 *
 * @return The constructed absolute path, or null if no meaningful absolute path could be constructed.
 */
public string absolutePath(string filepath) {
	string buffer;
	buffer.resize(256);
	
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		unsigned len = GetFullPathName(filepath.c_str(), unsigned(buffer.length()), buffer.c_str(), null);
		if (len == 0)
			return string();
		if (len >= unsigned(buffer.length())) {
			buffer.resize(int(len));
			GetFullPathName(filepath.c_str(), unsigned(len + 1), buffer.c_str(), null);
		} else
			buffer.resize(int(len));
		return buffer.toLowerCase();
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		pointer<byte> f = linux.realpath(filepath.c_str(), null);
		if (f != null) {
			string result(f);
			C.free(f);
			return result;
		}
	}
	if (isRelativePath(filepath)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return null;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			pointer<byte> cwdbuf = linux.getcwd(null, 0);
			string cwd(cwdbuf);
			C.free(cwdbuf);
			string[] components;
			string p = path(cwd, filepath);
			components = p.split('/');
			return composeAbsolutePath(components);
		} else
			return null;
	} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return filepath;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			string[] components;
			components = filepath.split('/');
			return composeAbsolutePath(components);
	} else
			return filepath;
}

private string composeAbsolutePath(string[] components) {
	string[] results;

	for (i in components) {
		if (components[i].length() == 0)
			continue;
		if (components[i] == ".")
			continue;
		if (components[i] == "..") {
			if (results.length() > 0)
				results.resize(results.length() - 1);
			continue;
		}
		results.append(components[i]);
	}
	string path;
	for (i in results)
		path += "/" + results[i];
	return path;
}
/**
 * Returns the last component (the filename part) of a path string.
 *
 * @param filename Absolute or relative path for a file.
 *
 * @return The substring following the last path separator character recognized by the host operating system.
 * If the string contains no such separator, the function returns the filename parameter.
 */
public string filename(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		for (int x = filename.length() - 1; x >= 0; x--)
			if (filename[x] == '\\' || filename[x] == '/')
				return filename.substr(x + 1);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		int idx = filename.lastIndexOf('/');
		if (idx >= 0)
			return filename.substr(idx + 1);
	}
	return filename;
}
/**
 * Construct a path from a directory and a file name.
 *
 * The resulting path is created by combining the directory and filename portions
 * with a path separator. If the directory portion ends with such a separator, the
 * filename is simply appended to the directory and the resulting string is returned.
 *
 * @param directory The directory portion of the path. This string may end with a path
 * separator character.
 *
 * @param filename The filename portion of the path.
 *
 * @return The resulting file path. 
 */
public string path(string directory, string filename) {
	return path(directory, filename, null);
}
/**
 * Construct a path from a directory, baseName and extension.
 *
 * If the baseName already has an extension, that extension is replaced with the extension
 * string. Otherwise, the extension is appended to the baseName with a period.
 *
 * If the baseName had an extension that extension is ignored and replaced with the new extension.
 *
 * @param directory The directory portion of the path. This string may end with a path
 * separator character.
 * @param baseName A base file name, which may contian an extension.
 * @param extension The new extension for the resulting filename path.
 *
 * @return The constructed path name. Only one path separator character appears between
 * the directory and baseName parts of the path.
 */
public string path(string directory, string baseName, string extension) {
	string base;
	if (directory.length() > 0) {
		byte c = directory[directory.length() - 1];
		if (c == ':' || c == '\\' || c == '/')
			base = directory + baseName;
		else
			base = directory + "/" + baseName;
	} else
		base = baseName;
	if (extension.length() > 0) {
		string b = filename(base);
		int i = b.lastIndexOf('.');
		if (i != -1) {
			int extSize = b.length() - i;
			base.resize(base.length() - extSize);
		}
		if (extension[0] != '.')
			base = base + ".";
		base = base + extension;
	}
	return base;
}
/**
 * Extract the directory portion of a file path.
 *
 * The portion of the string after the last path separator is returned.
 * If the last path separator character appears as the first character in the
 * string (e.g. '/abc', then the directory "/" is returned. If no path
 * separator at all appears in the filename, the directory "." is returned.
 *
 * @param filename The filename path.
 *
 * @return The directory portion.
 */
public string directory(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substr(0, x);
		}
	}
	return ".";
}
/**
 * This function determines whether, on the host operating system, the given prefix
 * names the initial directory in the path.
 *
 * @return true if the following is true:
 *
 * <ul>
 *   <li>
 *		path.startsWith(prefix) - up to case sensitivity in the host 
 *		  operating system. Note that for some file systems mounted on Linux, the file
 *		  system may not distinguish upper- and lower-case letters even though native
 *		  Linux file systems do. In such a case, this function will not check the
 *		  paths to determine whether they refer to files in such a file system.
 *   <li>
 *		The next character in the path is a directory delimiter character;
 *		  in other words the prefix names a complete directory component in 
 *		  the path.
 * </ul>
 */
public boolean pathStartsWith(string path, string prefix) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		// TODO: cannot modify a string parameter - fix this when this constraint is relaxed.
		string lprefix = prefix.toLowerCase();
		string lpath = path.toLowerCase();
		if (!lpath.startsWith(lprefix))
			return false;
		if (path.length() == prefix.length())
			return true;
		byte b = path[prefix.length()];
		if (b == '\\' || b == '/')
			return true;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		if (!path.startsWith(prefix))
			return false;
		if (path.length() == prefix.length())
			return true;
		if (path[prefix.length()] == '/')
			return true;
	}
	return false;
}
/**
 * Returns the current user's home directory path.
 *
 * @return The path to the user's home directory.
 */
public string homeDirectory() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		// TODO: Implement this
		return null;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return process.environment.get("HOME");
	} else
		return null;
}
/**
 * Expand a wild card path.
 *
 * The native operating system rules for wild card expansion are applied to the pattern
 * to construct a list of matching paths.
 *
 * @param pattern The file path, possibly containing wild card characters.
 *
 * @return An array containing all of the matching file paths for the given pattern.
 * If the pattern was well formed, but did not match any files, the returned array will
 * be empty but the next return expression will be true.
 *
 * @return true if the operation succeeded, false otherwise.
 */
public string[], boolean expandWildCard(string pattern) { 
	string[] results;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return results, false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.glob_t gl;

		int result = linux.glob(pattern.c_str(), 0, null, &gl);
		if (result == linux.GLOB_NOMATCH)
			return results, true;
		if (result != 0)
			return results, false;
		for (int i = 0; i < gl.gl_pathc; i++)
			results.append(string(gl.gl_pathv[i]));
		linux.globfree(&gl);
		return results, true;
	} else
		return results, false;
}
/**
 * Resolve a path relative to the directory of a base file name.
 *
 * For example, if you have a relative path in an HTML link, it is found relative to
 * the directory containing the HTML file that contains the link.
 *
 * @param filename The (possibly relative) path to a file.
 * @param baseFilename The path to a file.
 *
 * @return If the filename argument contains a relative path, the result is found by combining the 
 * directory portion of the baseFilename with the contents of filename. If filename contains an
 * absolute path, then the function returns filename.
 */
public string pathRelativeTo(string filename, string baseFilename) {
	if (isRelativePath(filename))
		return path(directory(baseFilename), filename);
	else
		return filename;
}
/**
 * Determine whether a path string is a relative path. 
 *
 * The path is not checked to see if it names an actual file.
 *
 * @param filename The path to be checked.
 *
 * @return true if the path is relative, false if it is absolute or empty or null.
 */
public boolean isRelativePath(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		if (filename.length() == 0 || filename[0] == '\\' || filename[0] == '/' || filename.indexOf(':') >= 0)
			return false;
		else
			return true;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		if (filename.length() == 0 || filename[0] == '/')
			return false;
		else
			return true;
	} else
			return false;
}
/**
 * Construct a relative file path.
 *
 * Numerous applications read files containing paths to other files. In many
 * cases these embedded file names are determined relative to the directory
 * containing the application's file. For example, include statements in C source
 * files are calculated in this way.
 *
 * Given two file paths, return a file path that would identify the file
 * of filename, but be relative to the directory containing baseFilename.
 *
 * If filename or baseFilename are themselves relative, they are assumed to be
 * relative to the current working directory.
 *
 * For example:
 *
 *{@code
 *    "../bb/cc.x" = makeCompactPath("aa/bb/cc.x", "aa/dd/ee.y");
 *}
 *
 * In this case, the common prefix directory {@code aa} is shared. in order to navigate
 * from the {@code dd} directory containing the base file to the common directory, one
 * {@code ..} directory must be used.
 *
 * @param filename The path to a file.
 * If the path named by filename does not exist, then the path must be absolute.
 * A relative path to a non-existent file will cause unpredictable results.
 *
 * @param baseFilename The path to another file that will serve as the base
 * for the returned relative path.
 *
 * @return A path, possibly containing leading '..' directories, that identifies
 * filename relative to baseFilename.
 * If there is no common directory in the paths, the filename string is returned.
 */
public string makeCompactPath(string filename, string baseFilename) {
//	if (isRelativePath(filename))
//		return filename;
	string a1 = absolutePath(filename);
	string a2 = absolutePath(baseFilename);

	int span = math.min(a1.length(), a2.length());
//		printf("span %d a1 = '%s' a2 = '%s'\n", span, a1, a2);
	int i;
	int firstSlash = -1;
	int lastSlash = -1;
	for (i = 0; i < span; i++) {
		if (a1[i] != a2[i])
			break;
		if (a1[i] == '/') {
			lastSlash = i;
			if (firstSlash < 0)
				firstSlash = i;
		}
	}
	if (firstSlash == lastSlash)
		return a1;

		// There is a common directory prefix! - count how many components match

	int slashCount = 0;
	for (int j = i; j < a2.length(); j++)
		if (a2[j] == '/')
			slashCount++;

		// If there are no differing directory components, just retain the final component
		
	if (slashCount == 0)
		return a1.substr(lastSlash + 1);

	string result;
	while (slashCount > 0) {
		result.append("../");
		slashCount--;
	}

		// If the first path is a subset that happens to be a full directory name, we're done

	if (a2.length() > a1.length() && a2[i] == '/')
		return result;

		// Nope there's a partial component before the unequal byte, so take the filename.

	return result + a1.substr(lastSlash + 1);
}

