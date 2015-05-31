/*
   Copyright 2015 Rovert Jervis

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
#pragma once
#include "dictionary.h"
#include "scanner.h"
#include "string.h"
#include "vector.h"

namespace display {

class TextBuffer;

};

namespace script {

class Atom;
class MessageLog;
class Object;
class Scanner;
class String;

void objectFactory(const string& tag, Object* (*factory)());

class ContextBase {
public:
	ContextBase() {}

	void objectFactory(const string& tag, Object* (*factory)());

private:
	dictionary<Object* (*)()>			_factories;
};

template<class T>
class Context : public ContextBase {
public:
	Context(T* context) {
		_context = context;
	}

	T* context() const { return _context; }

private:
	T*									_context;
};

class Parser {
public:
	Parser(const string& source);

	Parser(display::TextBuffer* buffer);

	~Parser();

	static Parser* load(const string& filename);

	void content(vector<Atom*>* output);

	bool parse();

	string filename() const { return _filename; }

private:
	void parseGroup(Object* parent, Token terminator);

	void parseObject(Object* parent, const char* tag, int tagLength);

	bool resync(Token t);

	String* stringToken();

	Scanner								_scanner;
	MessageLog*							_log;
	vector<Atom*>*						_atoms;
	bool								_errorsFound;
	string								_filename;
};

void init();

}  // namespace script
