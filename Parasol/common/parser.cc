#include "../common/platform.h"
#include "parser.h"

#include <stdlib.h>
#include "atom.h"
#include "file_system.h"
#include "internal.h"
#include "process.h"
#include "script.h"

namespace script {

static dictionary<Object* (*)()>	factories;

class ScannerMessageLog : public MessageLog {
public:
	ScannerMessageLog(Parser* parser, Scanner* scanner) {
		_parser = parser;
		_scanner = scanner;
	}

	virtual void error(fileOffset_t offset, const string& msg) {
		printf("%s %d : %s\n", _parser->filename().c_str(), _scanner->lineNumber(offset), msg.c_str());
	}

private:
	Parser*			_parser;
	Scanner*		_scanner;
};

void objectFactory(const string &tag, Object *(*factory)()) {
	factories.put(tag, factory);
}

void ContextBase::objectFactory(const string &tag, Object *(*factory)()) {
	_factories.put(tag, factory);
}

Parser* Parser::load(const string& filename) {
	FILE* f = fileSystem::openTextFile(filename);
	if (f == null)
		return null;
	string s;
	if (!fileSystem::readAll(f, &s)) {
		fclose(f);
		return null;
	}
	fclose(f);
	Parser* p = new Parser(s);
	p->_filename = fileSystem::absolutePath(filename);
	return p;
}

Parser::Parser(const string& source) : _scanner(source) {
	_atoms = null;
	_log = null;
}

Parser::~Parser() {
	delete _log;
}

void Parser::content(vector<Atom*> *output) {
	_atoms = output;
}

bool Parser::parse() {
	if (_log == null)
		_log = new ScannerMessageLog(this, &_scanner);
	_errorsFound = false;
	parseGroup(null, END_OF_INPUT);
	return !_errorsFound;
}

void Parser::parseGroup(Object* parent, Token terminator) {
	const char* run = null;
	const char* endOfRun;
	for (;;) {
		Token t = _scanner.next();
		switch (t) {
		case END_OF_INPUT:
			if (terminator != END_OF_INPUT) {
				_errorsFound = true;
				if (_log)
					_log->error(_scanner.location(), "Unexpected end of file");
			}
			if (run)
				_atoms->push_back(new TextRun(run, endOfRun - run));
			return;

		case IDENTIFIER:
			{
				const char* start = _scanner.tokenText();
				int length = _scanner.tokenSize();

				t = _scanner.next();
				if (t == LEFT_PARENTHESIS) {
					// We have an object constructor, so flush any prior run
					if (run) {
						_atoms->push_back(new TextRun(run, endOfRun - run));
						run = null;
					}
					parseObject(parent, start, length);
				} else {
					_scanner.backup();
					if (run == null)
						run = start;
					endOfRun = start + length;
				}
			}
			break;

		case STRING_LITERAL:
			if (run) {
				_atoms->push_back(new TextRun(run, endOfRun - run));
				run = null;
			}
			_atoms->push_back(stringToken());
			break;

		case	RIGHT_PARENTHESIS:
			if (terminator == RIGHT_PARENTHESIS ||
				terminator == COMMA) {
				_scanner.backup();
				if (run)
					_atoms->push_back(new TextRun(run, endOfRun - run));
				return;
			}
			if (_log)
				_log->error(_scanner.location(), "Unexpected right parenthesis");
			_errorsFound = true;
			break;

		case	RIGHT_CURLY:
			if (t != terminator) {
				if (_log)
					_log->error(_scanner.location(), "Unexpected right curly brace");
				_errorsFound = true;
				_scanner.backup();
			}
			if (run)
				_atoms->push_back(new TextRun(run, endOfRun - run));
			return;

		case	COMMA:
			if (terminator == COMMA) {
				_scanner.backup();
				if (run)
					_atoms->push_back(new TextRun(run, endOfRun - run));
				return;
			}

		default:
			if (run == null)
				run = _scanner.tokenText();
			endOfRun = _scanner.tokenText() + _scanner.tokenSize();
		}
	}
}

void Parser::parseObject(Object* parent, const char* tagStart, int tagLength) {
	Object* object;
	string tag(tagStart, tagLength);
	Object* (*const*factory)();// = _factories.get(tag);
//	if (*factory == null)
		factory = factories.get(tag);
	if (*factory == null)
		object = new Object();
	else
		object = (*factory)();
	object->put("tag", new String(tag));
	if (parent)
		object->put("parent", parent);
	int location = _scanner.location();
	for (;;) {
		Token t = _scanner.next();
		if (t == RIGHT_PARENTHESIS)
			break;
		if (t == RIGHT_CURLY) {
			if (_log)
				_log->error(_scanner.location(), "Unexpected right curly brace");
			_errorsFound = true;
			_scanner.backup();
			return;
		}
		if (t != IDENTIFIER) {
			if (!resync(RIGHT_PARENTHESIS))
				return;
			continue;
		}
		string attribute = string(_scanner.tokenText(), _scanner.tokenSize());
		if (_scanner.next() == COLON) {
			vector<Atom*> value;
			vector<Atom*>* outer = _atoms;
			_atoms = &value;
			parseGroup(null, COMMA);
			_atoms = outer;
			if (value.size() == 0)
				object->put(attribute, new Null());
			else if (value.size() == 1)
				object->put(attribute, value[0]);
			else
				object->put(attribute, new Vector(&value));
		} else if (!resync(COMMA))
				return;
		t = _scanner.next();
		if (t == RIGHT_PARENTHESIS)
			break;
		if (t != COMMA) {
			if (!resync(COMMA))
				return;
			t = _scanner.next();
			if (t != COMMA)
				_scanner.backup();
			continue;
		}
	}
	Token t = _scanner.next();
	if (t == LEFT_CURLY) {
		vector<Atom*>* save = _atoms;
		_atoms = new vector<Atom*>;
		parseGroup(object, RIGHT_CURLY);
		object->put("content", new Vector(_atoms));
		delete _atoms;
		_atoms = save;
	} else
		_scanner.backup();
	if (object->validate(this))
		_atoms->push_back(object);
	else {
		if (_log)
			_log->error(location, "Object is not valid");
		_errorsFound = true;
	}
}

bool Parser::resync(Token sync) {
	if (_log)
		_log->error(_scanner.location(), "Syntax error");
	_errorsFound = true;
	for (;;) {
		Token t = _scanner.next();
		if (t == END_OF_INPUT)
			return false;
		if (t == sync) {
			_scanner.backup();
			return true;
		}
		if (t == LEFT_CURLY) {
			if (!resync(RIGHT_CURLY))
				return false;
			_scanner.next();
		}
		if (t == LEFT_PARENTHESIS) {
			if (!resync(RIGHT_PARENTHESIS))
				return false;
			t = _scanner.next();
			if (t == RIGHT_PARENTHESIS)
				continue;

				// Can only be RIGHT_CURLY.  If this is the
				// sync or not, we are done here.

			_scanner.backup();
			return true;
		}
		if (t == RIGHT_PARENTHESIS || 
			t == RIGHT_CURLY) {
			_scanner.backup();
			return true;
		}
	}
}

String* Parser::stringToken() {
	string s(_scanner.tokenText() + 1, _scanner.tokenSize() - 2);
	string content;
	s.unescapeC(&content);
	return new String(content);
}

class ScriptObject : script::Object {
public:
	static script::Object* factory() {
		return new ScriptObject();
	}

	ScriptObject() {}

	virtual bool validate(Parser* parser) {
		Atom* a = get("name");
		if (a == null)
			return false;
		_path = fileSystem::pathRelativeTo(a->toString(), parser->filename());
		return true;
	}

	virtual bool run() {
		string command = commandPrefix;
		command.push_back(' ');
		command.append(_path);
		string captureData;
		process::exception_t exception;
		int exitCode = process::debugSpawn(command, &captureData, &exception, 60);
		string sExitCode(exitCode);
		put("exit", new String(sExitCode));
		put("output", new String(captureData));
		int expectedExitCode = 0;
		Atom* expect = get("expect");
		if (expect != null)
			expectedExitCode = expect->toString().toInt();
		return exitCode == expectedExitCode;
	}

private:
	string				_path;
};

void init() {
	script::objectFactory("script", ScriptObject::factory);
}

}  // namespace script
