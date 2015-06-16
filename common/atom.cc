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
#include "../common/platform.h"
#include "atom.h"

#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif

namespace script {

Atom::~Atom() {
}

bool Atom::validate(Parser* parser) {
	return true;
}

bool Atom::isRunnable() const {
	return false;
}

bool Atom::run() {
	return false;
}

Atom* Atom::get(const string& name) const {
	return null;
}

Atom* Atom::getIndexed(int i) const {
	return null;
}

bool Atom::put(const string& name, Atom* value) {
	return false;
}

Atom* Atom::operator[] (int i) const {
	return getIndexed(i);
}

int Atom::size() const {
	return -1;
}

Object::~Object() {
	dictionary<Atom*>::iterator i = _properties.begin();

	while (i.hasNext()) {
		string s = i.key();
		if (s != "parent")
			delete *i;
		i.next();
	}
}

bool Object::isRunnable() const {
	return true;
}

string Object::toSource() {
	string s;
	dictionary<Atom*>::iterator i = _properties.begin();

	bool firstTime = true;
	script::Atom* a = get("tag");
	if (a != null)
		s.append(a->toString());
	s.push_back('(');
	while (i.hasNext()) {
		if (i.key() != "tag" &&
			i.key() != "content" &&
			i.key() != "parent") {
			script::Atom* a = *i;
			if (firstTime)
				firstTime = false;
			else
				s.push_back(',');
			s.append(i.key());
			s.push_back(':');
			s.append(a->toSource());
		}
		i.next();
	}
	s.push_back(')');
	a = get("content");
	if (a != null) {
		s.push_back('{');
		s.append(a->toSource());
		s.push_back('}');
	}
	return s;
}

string Object::toString() {
	Atom* content = get("content");
	if (content)
		return content->toString();
	else
		return "";
}

Atom* Object::get(const string& name) const {
	return *_properties.get(name);
}

bool Object::put(const string& name, Atom* value) {
	Atom* a = _properties.replace(name, value);
	if (a) {
		delete a;
		return false;
	} else
		return true;
}

bool Object::runAnyContent() {
	script::Atom* c = get("content");
	if (c != null) {
		if (typeid(*c) == typeid (script::Vector)) {
			const vector<Atom*>& v = ((script::Vector*)c)->value();

			for (int i = 0; i < v.size(); i++)
				if (v[i]->isRunnable() && !v[i]->run())
					return false;
		} else if (c->isRunnable())
			return c->run();
	}
	return true;
}

bool Object::runAllContent() {
	bool result = true;
	script::Atom* c = get("content");
	if (c != null) {
		if (typeid(*c) == typeid (script::Vector)) {
			const vector<Atom*>& v = ((script::Vector*)c)->value();

			for (int i = 0; i < v.size(); i++)
				if (v[i]->isRunnable() && !v[i]->run())
					result = false;
		} else if (c->isRunnable())
			result = c->run();
	}
	return result;
}


TextRun::TextRun(const char *text, int length) : _content(text, length) {
}

string TextRun::toSource() {
	return _content;
}

string TextRun::toString() {
	return _content;
}

String::String(const string& s) {
	_content = s;
}

string String::toSource() {
	string s;
	s.push_back('"');
	s = s + _content.escapeC();
	s.push_back('"');
	return s;
}

string String::toString() {
	return _content;
}

string Null::toSource() {
	return string();
}

string Null::toString() {
	return string();
}

Vector::Vector(vector<Atom*>* value) {
	if (value == null)
		return;
	for (int i = 0; i < value->size(); i++)
		_value.push_back((*value)[i]);
	value->clear();
}

Vector::~Vector() {
	_value.deleteAll();
}

string Vector::toSource() {
	string s;

	for (int i = 0; i < _value.size(); i++)
		s.append(_value[i]->toSource());
	return s;
}

Atom* Vector::getIndexed(int i) const {
	if (i < 0 || i >= _value.size())
		return null;
	return _value[i];
}

int Vector::size() const {
	return _value.size();
}

string Vector::toString() {
	string s;

	for (int i = 0; i < _value.size(); i++)
		s.append(_value[i]->toString());
	return s;
}

}  // namespace script
