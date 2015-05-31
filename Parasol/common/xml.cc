#include "../common/platform.h"
#include "xml.h"

#include <math.h>
#include "file_system.h"
#include "machine.h"

namespace xml {

saxString saxNull;

Document* load(const string& filename, bool exact) {
	Document* doc = new Document();
	if (!doc->load(filename, exact))
		return null;
	else
		return doc;
}

Document::Document() {
	clear();
}

bool Document::load(const string& filename, bool exact) {
	FILE* fp = fileSystem::openTextFile(filename);
	if (fp == null)
		return false;
	load(fp, exact);
	fclose(fp);
	return !_parseError;
}

void Document::load(FILE* stream, bool exact) {
	DOMParser p(this, null);
	p.parse(stream, exact);
}

void Document::clear() {
	_parseError = false;
	_root = null;
}

Element* Document::getValue(const string &id) {
	return _root->getById(id);
}
/*
	save: (filename: string) boolean
	{
		out := fileSystem.createTextFile(filename)
		if (out == null)
			return false
		dumpTag(out, root)
		out.close()
		return true
	}

	insert: (existing: Element, e: Element)
	{
		existing.insert(e)
	}

	append: (existing: Element, e: Element)
	{
		existing.append(e)
	}

	insertAfter: (existing: Element, e: Element)
	{
		existing.insertAfter(e)
	}

	insertBefore: (existing: Element, e: Element)
	{
		existing.insertBefore(e)
	}

	extract: (e: Element)
	{
		notifyForDelete(e)
		e.extract()
	}

	setTag: (e: Element, tag: string)
	{
		e.tag = tag
		fire changeElement(e)
	}

	setAttribute: (e: Element, attr: string, value: string)
	{
		e.setValue(attr, value, script.FILE_OFFSET_UNDEFINED)
		fire changeElement(e)
	}

	notifyForDelete: (e: Element)
	{
		for (c := e.child; c != null; c = c.sibling)
			notifyForDelete(c)
		fire deleteElement(e)	
	}

	dumpTag: (out: Stream, e: Element)
	{
		switch (e.kind){
		case	ROOT:
			break

		case	TEXT:
			out.write('`')
			out.write(e.tag)
			out.write('`')
			break

		case	COMMENT:
			out.write("<!--")
			out.write(e.tag)
			out.write("-->")
			break

		case	PROCESSING_INSTRUCTION:
			out.write(e.tag)
			break

		case	ELEMENT:
			out.write('<')
			out.write(e.tag)
			for (a := e.attributes; a != null; a = a.next){
				out.write(' ')
				out.write(a.name)
				out.write('=')
				idx := a.value.scan(' ')
				if (idx >= 0)
					out.write('"')
				out.write(a.value)
				if (idx >= 0)
					out.write('"')
			}
			if (e.child == null){
				out.write('/')
				out.write('>')
				break
			}
			out.write('>')
			for (es := e.child; es != null; es = es.sibling)
				dumpTag(out, es)
			out.write('<')
			out.write('/')
			out.write(e.tag)
			out.write('>')
			break

		case	ERROR:
			if (e.tag != null)
				out.write("Error: " + e.tag + ":" + int(e.location))
			else
				out.write("Error Lineno: " + int(e.location))
			break

		case	DECLARATION:
			out.write(e.tag)
			break
		}
	}
}
*/
Element::Element(const string &tag, script::fileOffset_t i) {
	this->tag = tag;
	this->location = i;
	this->kind = ELEMENT;
	init();
}

Element::Element(const string &tag, script::fileOffset_t i, ElementKind kind) {
	this->tag = tag;
	this->location = i;
	this->kind = kind;
	init();
}

void Element::init() {
	parent = null;
	child = null;
	sibling = null;
	attributes = null;
}

Element* Element::getById(const string &id) {
	string* m = getValue("id");
	if (m != null && *m == id)
		return this;
	if (child != null){
		Element* e = child->getById(id);
		if (e != null)
			return e;
	}
	if (sibling != null){
		Element* e = sibling->getById(id);
		if (e != null)
			return e;
	}
	return null;
}

string* Element::getValue(const string& name) {
	for (Attribute* a = attributes; a != null; a = a->next)
		if (strcmp(a->name.c_str(), name.c_str()) == 0)
			return &a->value;
	return null;
}

void Element::setValue(const string& name, const string* value, script::fileOffset_t location) {
	if (attributes == null){
		if (value)
			attributes = new Attribute(name, *value, location);
		return;
	}
	Attribute* aprev = null;
	for (Attribute* a = attributes; ; aprev = a, a = a->next){
		if (strcmp(a->name.c_str(), name.c_str()) == 0){
			if (value){
				a->value = *value;
				a->location = location;
			} else {
				if (aprev == null)
					attributes = a->next;
				else
					aprev->next = a->next;
				delete a;
			}
			return;
		}
		if (a->next == null){
			if (value)
				a->next = new Attribute(name, *value, location);
			return;
		}
	}
}
/*
	getChild: public (tag: string) Element
	{
		for (e := child; e != null; e = e.sibling)
			if (e.kind == ELEMENT && e.tag == tag)
				return e
		return null
	}

	insert: (e: Element)
	{
		e.sibling = child
		child = e
		e.parent = this
	}
*/
void Element::append(Element* e) {
	if (child == null)
		child = e;
	else {
		Element* c;
		for (c = child; c->sibling != null; c = c->sibling)
			;
		c->sibling = e;
	}
	e->sibling = null;
	e->parent = this;
}
/*
	insertAfter: (e: Element)
	{
		e.parent = parent
		e.sibling = sibling
		sibling = e
	}

	insertBefore: (e: Element)
	{
		e.parent = parent
		e.sibling = this
		if (parent != null){
			c := parent.child
			if (c == this){
				parent.child = e
				return
			}
			for (; c != null; c = c.sibling){
				if (c.sibling == this){
					c.sibling = e
					return
				}
			}
		}
	}

	leftSibling: Element
		null =
		{
			if (parent != null){
				c := parent.child
				if (c == this)
					return null
				for (; c != null; c = c.sibling)
					if (c.sibling == this)
						return c
			}
			return null
		}
*/
void Element::extract() {

		// Only do anything if this Element has a parent

	if (parent != null) {
		Element* pc = null;
		for (Element* c = parent->child; c != null; c = c->sibling) {
			if (c == this) {
				if (pc != null)
					pc->sibling = sibling;
				else
					parent->child = sibling;
				parent = null;
				sibling = null;
				return;
			}
			pc = c;
		}

			// if we get here, the Element tree is corrupted

	}
}
/*
	debugPrint: ()
	{
		debugPrintN(0)
	}

	debugPrintN: private (indent: int)
	{
		for (i := 0; i < indent; i++)
			windows.debugPrint("    ")
		switch (kind){
		case	TEXT:
			windows.debugPrint("text: " + tag + "\n")
			break

		case	ROOT:
			windows.debugPrint("root:\n")
			if (child != null)
				child.debugPrintN(indent + 1)
			break

		default:
			windows.debugPrint("kind=" + int(kind) + " ")

		case	ELEMENT:
			windows.debugPrint("<" + tag)
			for (a := attributes; a != null; a = a.next){
				windows.debugPrint(" ")
				a.debugPrint()
			}
			if (child != null){
				windows.debugPrint(">\n")
				if (child != null)
					child.debugPrintN(indent + 1)
				for (i = 0; i < indent; i++)
					windows.debugPrint("    ")
				windows.debugPrint("</>\n")
			} else {
				windows.debugPrint("/>\n")
			}
			break

		case	ERROR:
			windows.debugPrint("error: " + tag + "\n")
			break
		}
		if (sibling != null)
			sibling.debugPrintN(indent)
	}
}


	new: ()
	{
		xmlDoc = new Document()
	}
*/
DOMParser::DOMParser(Document* doc, script::MessageLog* messageLog) : Parser(messageLog) {
	xmlDoc = doc;
	doc->clear();
}
/*
	parse: (s: string, e: boolean) Document
	{
		m := new text.MemoryStream()
		m.encoding = SE_UTF8
		m.write(s)
		d:= parse(m, e)
		m.close()
		return d
	}
*/
Document* DOMParser::parse(FILE* stream, bool e) {
	exact = e;
	string text;
	if (!fileSystem::readAll(stream, &text))
		return false;
	open(text);
	parse();
	close();
	return result();
}

void DOMParser::append(Element* e) {
	if (xmlDoc->root() == null){
		xmlDoc->set_root(e);
		last = e;
		return;
	}
	e->parent = context;
	if (last == null){
		if (context == null){
			xmlDoc->_parseError = true;
			last = xmlDoc->root();
			xmlDoc->set_root(new Element(null, script::FILE_OFFSET_ZERO, ROOT));
			xmlDoc->root()->child = last;
			last->parent = xmlDoc->root();
//			fire xmlDoc.newChild(xmlDoc.root)
			last->sibling = e;
			e->parent = xmlDoc->root();
//			fire xmlDoc.newSibling(last)
			context = xmlDoc->root();
		} else {
			context->child = e;
//			fire xmlDoc.newChild(context)
		}
	} else {
		last->sibling = e;
//		fire xmlDoc.newSibling(last)
	}
	last = e;
}

void DOMParser::push() {
	context = last;
	last = null;
}

bool DOMParser::pop() {
	if (context == null)
		return false;
//	fire xmlDoc.closeTag(context);
	last = context;
	context = context->parent;
	return true;
}

Document* DOMParser::result() {
	if (xmlDoc->root() == null){
		xmlDoc->set_root(new Element("", script::FILE_OFFSET_ZERO, TEXT));
		xmlDoc->_parseError = false;
	} else {
		while (last != xmlDoc->root()){
			if (context == null)
				break;
			if (last != null &&
				last->parent == xmlDoc->root() &&
				xmlDoc->root()->tag == "" && 
				xmlDoc->root()->kind != TEXT)
				break;
			xmlDoc->_parseError = true;
			Element* e = new Element(null, script::FILE_OFFSET_ZERO, ERROR_TEXT);
			append(e);
			if (!pop())
				break;
		}
	}
	return xmlDoc;
}

void DOMParser::inlineText(const saxString& txt, script::fileOffset_t location) {
	int i;
	for (i = 0; i < txt.length; i++)
		if (!isXMLSpace(txt.text[i]))
			break;
	if (!exact){

			// For not exact parsing, discard all white-space nodes

		if (i >= txt.length)
			return;

		// For exact parsing, discard white-space outside the root tag
		// all other text outside the root tag is an error

	} else if (xmlDoc->root() == null ||
			   (last == xmlDoc->root() && context == null)){
		if (i < txt.length)
			errorText(XEC_EXTRA_TEXT, txt, location);
		return;
	}
	Element* e = new Element(string(txt.text, txt.length), location, TEXT);
	append(e);
}

void DOMParser::errorText(ErrorCodes code, const saxString& txt, script::fileOffset_t location) {
	Element* e = new Element(string("") + int(code) + ": " + string(txt.text, txt.length), location, ERROR_TEXT);
	append(e);
}

void DOMParser::commentText(const saxString& txt, script::fileOffset_t location) {
	if (exact){
		Element* e = new Element(string(txt.text, txt.length), location, COMMENT);
		append(e);
	}
}

bool DOMParser::anyTag(const saxString& tag) {
	Element* e = new Element(string(tag.text, tag.length), tagLocation);
	for (XMLParserAttributeList* a = unknownAttributes; a != null; a = a->next) {
		string value = a->value.toString();
		e->setValue(a->name.toString(), &value, a->location);
	}
	append(e);
	push();
	parseContents();
	return true;
}

void DOMParser::anyCloseTag() {
	pop();
}

Parser::Parser(script::MessageLog* messageLog) {
	lineCount = 0;
	_parseError = false;
	tagLocation = script::FILE_OFFSET_ZERO;
	unknownAttributes = null;
	_consumedContents = false;
	_noContents = false;
	_allowContents = false;
	_fillPoint = null;
	_cursor = 0;
	_inlineTextPoint = null;
	_freeAttribs = null;
	_processContent = true;
	_messageLog = messageLog;
}

Parser::~Parser() {
	close();
}

int Parser::matchTag(const saxString& tag) {
	return -1;
}

bool Parser::matchedTag(int index) {
	return false;
}

bool Parser::matchAttribute(int index, 
						    XMLParserAttributeList* attribute) {
	return false;
}

	// Implementation methods below - Modify as much as you like

void Parser::open(const string& text) {
	_parseError = false;
	_buffer = text;
}

void Parser::close() {
	while (_freeAttribs != null){
		XMLParserAttributeList* f = _freeAttribs;
		_freeAttribs = f->next;
		delete f;
	}
}

bool Parser::parse() {
	_cursor = 0;
	_parseError = false;
	_noContents = false;
	_allowContents = true;
	_consumedContents = false;
	lineCount = 1;
	saxString x;
	x.text = null;
	x.length = 0;
	rootTag = true;
	consumeText(x);
	reportInlineText();
	return !_parseError;
}

bool Parser::load(const string& filename) {
	FILE* fp = fileSystem::openTextFile(filename);
	if (fp == null)
		return false;
	string text;
	if (!fileSystem::readAll(fp, &text)) {
		fclose(fp);
		return false;
	}
	open(text);
	fclose(fp);
	parse();
	close();
	return !_parseError;
}

script::fileOffset_t Parser::textLocation(const saxString &s) {
	if (s.text) {
		unsigned x = s.text - _buffer.c_str();
		if (x < (unsigned)_buffer.size())
			return x;
	}
	return script::FILE_OFFSET_UNDEFINED;
}

bool Parser::reportError(const string& message, script::fileOffset_t location) {
	if (_messageLog != null) {
		_messageLog->error(location, message);
		return true;
	} else
		return false;
}

void Parser::disallowContents() {
	_allowContents = false;
}

void Parser::parseContents() {
	rootTag = false;
	if (!_noContents){
		consumeText(tag);
		_consumedContents = true;
	}
}

void Parser::skipContents() {
	rootTag = false;
	if (!_noContents){
		_processContent = false;
		consumeText(tag);
		_processContent = true;
		_consumedContents = true;
	}
}

void Parser::inlineText(const saxString& text, script::fileOffset_t location) {
}

void Parser::errorText(ErrorCodes code, const saxString& text, script::fileOffset_t location) {
}

void Parser::commentText(const saxString& text, script::fileOffset_t location) {
}

bool Parser::anyTag(const saxString& text) {
	errorText(XEC_UNKNOWN_ELEMENT, tag, tagLocation);
	return false;
}

void Parser::anyCloseTag() {
}

void Parser::consumeText(const saxString& enclosingTag) {
	_fillPoint = &_buffer[_cursor];
	_inlineTextPoint = _fillPoint;
	saxString tag = enclosingTag;
	while (collectText('<')) {
		reportInlineText();
		bool b = consumeTag(tag);
		_fillPoint = &_buffer[_cursor];
		_inlineTextPoint = _fillPoint;
		if (!b)
			return;
	}
	reportInlineText();
}

bool Parser::consumeTag(const saxString& enclosingTag) {
	saxString wholeTag;
	wholeTag.text = &_buffer[_cursor];
	int tagStart = _cursor;
	tagLocation = (script::fileOffset_t)_cursor;
	_cursor++;
	skipWhiteSpace();
	if (_cursor >= _buffer.size()) {
		_parseError = true;
		wholeTag.length = &_buffer[_cursor] - wholeTag.text;
		errorText(XEC_UNTERMINATED, wholeTag, tagLocation);
		return true;
	}

		// Special tags, comments and cdata

	if (_buffer[_cursor] == '!'){
		if (_cursor + 2 < _buffer.size() &&
			_buffer[_cursor + 1] == '-' &&
			_buffer[_cursor + 2] == '-'){
			_cursor += 3;
			skipComment();
			return true;
		}
		if (_cursor + 7 < _buffer.size() &&
			_buffer[_cursor + 1] == '[' &&
			(_buffer[_cursor + 2] == 'c' || _buffer[_cursor + 2] == 'C') &&
			(_buffer[_cursor + 3] == 'd' || _buffer[_cursor + 3] == 'D') &&
			(_buffer[_cursor + 4] == 'a' || _buffer[_cursor + 4] == 'A') &&
			(_buffer[_cursor + 5] == 't' || _buffer[_cursor + 5] == 'T') &&
			(_buffer[_cursor + 6] == 'a' || _buffer[_cursor + 6] == 'A') &&
			_buffer[_cursor + 7] == ']'){
			_cursor += 8;
			int cdataStart = _cursor;
			saxString sx;
			sx.text = &_buffer[_cursor];
			while (_cursor + 2 < _buffer.size()){
				if (_buffer[_cursor] == ']' &&
				    _buffer[_cursor + 1] == ']' &&
				    _buffer[_cursor + 2] == '>'){
					sx.length = _cursor - cdataStart;
					if (_processContent)
						inlineText(sx, tagLocation);
					_cursor += 3;
					return true;
				}
				if (_buffer[_cursor] == '\n')
					lineCount++;
				_cursor++;
			}
			_parseError = true;
			wholeTag.length = &_buffer[_cursor] - wholeTag.text;
			errorText(XEC_UNTERMINATED, wholeTag, tagLocation);
			return true;
		}					
	}
	if (_buffer[_cursor] == '/'){
		_cursor++;
		skipWhiteSpace();
		int tagName = _cursor;
		while (_cursor < _buffer.size() && 
			   _buffer[_cursor] != '>' &&
			   !isXMLSpace(_buffer[_cursor]))
			_cursor++;
		if (_cursor >= _buffer.size()){
			_parseError = true;
			wholeTag.length = &_buffer[_cursor] - wholeTag.text;
			errorText(XEC_UNTERMINATED, wholeTag, tagLocation);
			return true;
		}
		if (_cursor != tagName){
			if (_cursor - tagName != enclosingTag.length ||
				memcmp(&_buffer[tagName], enclosingTag.text, enclosingTag.length) != 0){
				_parseError = true;
				wholeTag.length = &_buffer[_cursor] - wholeTag.text;
				errorText(XEC_MISMATCH, wholeTag, tagLocation);

					// Skip to the end of tag.

				while (_cursor < _buffer.size() &&
					   _buffer[_cursor] != '>')
					   _cursor++;
				if (_cursor < _buffer.size())
					_cursor++;
				return true;
			}
		}
		while (_cursor < _buffer.size() &&
			   _buffer[_cursor] != '>')
			   _cursor++;
		if (_cursor >= _buffer.size()){
			_parseError = true;
			wholeTag.length = &_buffer[_cursor] - wholeTag.text;
			errorText(XEC_UNTERMINATED, wholeTag, tagLocation);
			return true;
		}
		_cursor++;
		return false;
	}
	tag.text = &_buffer[_cursor];
	int tagName = _cursor;
	_cursor++;
	while (_cursor < _buffer.size() &&
		   !isXMLSpace(_buffer[_cursor]) &&
		   _buffer[_cursor] != '/' &&
		   _buffer[_cursor] != '>')
		_cursor++;
	if (_cursor >= _buffer.size()){
		_parseError = true;
		wholeTag.length = &_buffer[_cursor] - wholeTag.text;
		errorText(XEC_UNTERMINATED, wholeTag, tagLocation);
		return true;
	}
	tag.length = _cursor - tagName;
	int matchingElement;
	if (_processContent)
		matchingElement = matchTag(tag);
	else
		matchingElement = 0;
	resetAttributes();
	XMLParserAttributeList* attribute  = null;
	ErrorCodes errorCause = XEC_UNTERMINATED;
	for (;;){
		skipWhiteSpace();
		if (_buffer[_cursor] == '>'){
			_cursor++;
			_consumedContents = false;
			_noContents = false;
			_allowContents = true;
			if (_processContent) {
				if (matchingElement >= 0){
					if (!matchedTag(matchingElement)) {
						errorText(XEC_EXPECTED_ATTRIBUTE, wholeTag, tagLocation);
						_parseError = true;
					}
				} else if (!anyTag(tag))
					_parseError = true;
			}
			rootTag = false;
			if (!_consumedContents)
				consumeText(tag);
			if (_processContent)
				anyCloseTag();
			resetAttributes();
			return true;
		}
		if (_buffer[_cursor] == '/'){
			_cursor++;
			skipWhiteSpace();
			if (_cursor >= _buffer.size())
				break;
			if (_buffer[_cursor] != '>'){
				errorCause = XEC_EXPECT_CLOSE;
				break;
			}
			_cursor++;
			_noContents = true;
			if (_processContent) {
				if (matchingElement >= 0){
					if (!matchedTag(matchingElement)) {
						errorText(XEC_EXPECTED_ATTRIBUTE, wholeTag, tagLocation);
						_parseError = true;
					}
				} else {
					if (!anyTag(tag))
						_parseError = true;
					anyCloseTag();
				}
			}
			resetAttributes();
			return true;
		}
		attribute = getAttribute();
		attribute->name.text = &_buffer[_cursor];
		int attrStart = _cursor;
		while (_cursor < _buffer.size() && 
			   !isXMLSpace(_buffer[_cursor]) &&
			   _buffer[_cursor] != '/' &&
			   _buffer[_cursor] != '>' &&
			   _buffer[_cursor] != '=')
			_cursor++;
		attribute->name.length = _cursor - attrStart;
		skipWhiteSpace();
		if (_cursor >= _buffer.size())
			break;
		if (_buffer[_cursor] != '='){
			attribute->location = (script::fileOffset_t)_cursor;
			attribute->value.text = &_buffer[_cursor];
			attribute->value.length = 0;
		} else {
			_cursor++;
			if (_cursor >= _buffer.size())
				break;
			attribute->location = (script::fileOffset_t)_cursor;
			attribute->value.text = &_buffer[_cursor];
			int valueStart = _cursor;
			_fillPoint = attribute->value.text;
			if (_buffer[_cursor] == '"' || _buffer[_cursor] == '\''){
				char delim = _buffer[_cursor];
				_cursor++;
				if (collectText(delim)){
					char* xp = _fillPoint;
					attribute->value.length = xp - attribute->value.text;
				} else
					break;
				_cursor++;
			} else {
				if (collectText('>')){
					char* xp = _fillPoint;
					attribute->value.length = xp - attribute->value.text;
				} else
					break;
			}
		}
		if (_processContent) {
			defineAttribute(matchingElement, attribute);
			attribute = null;
		}
	}
	if (attribute != null)
		freeAttribute(attribute);
	resetAttributes();
	_parseError = true;
	wholeTag.length = &_buffer[_cursor] - wholeTag.text;
	errorText(errorCause, wholeTag, tagLocation);
	return true;
}

void Parser::reportInlineText() {
	if (_inlineTextPoint < _fillPoint) {
		saxString sx;
		sx.text = _inlineTextPoint;
		sx.length = int(_fillPoint - _inlineTextPoint);
		if (_processContent)
			inlineText(sx, (script::fileOffset_t)(_inlineTextPoint - &_buffer[0]));
		_inlineTextPoint = _fillPoint;
	}
}

void Parser::skipWhiteSpace() {
	for (; _cursor < _buffer.size(); _cursor++) {
		switch (_buffer[_cursor]) {
		case	' ':
		case	'\t':
		case	'\r':
		case	'\f':
			break;

		case	'\n':
			lineCount++;
			break;

		default:
			return;
		}
	}
}

bool Parser::collectText(char delim) {
	while (_cursor < _buffer.size()){
		if (delim == '>'){
			if (isXMLSpace(_buffer[_cursor]))
				return true;
			if (_buffer[_cursor] == '/' &&
				_cursor + 1 < _buffer.size() &&
				_buffer[_cursor + 1] == '>')
				return true;
		}
		if (_buffer[_cursor] == delim)
			return true;
		else if (_buffer[_cursor] == '&')
			consumeEscapeSequence();
		else {
			*_fillPoint++ = _buffer[_cursor];
			if (_buffer[_cursor] == '\n')
				lineCount++;
			_cursor++;
		}
	}
	return false;
}

void Parser::defineAttribute(int matchingElement, 
							 XMLParserAttributeList* attribute) {
	if (matchingElement < 0 ||
		!matchAttribute(matchingElement, attribute)){
		attribute->next = unknownAttributes;
		unknownAttributes = attribute;
	} else
		freeAttribute(attribute);
}

void Parser::resetAttributes() {
	while (unknownAttributes != null){
		XMLParserAttributeList* attribute = unknownAttributes;
		unknownAttributes = attribute->next;
		freeAttribute(attribute);
	}
}

void Parser::skipComment() {
	saxString sx;
	script::fileOffset_t commentLoc = (script::fileOffset_t)_cursor;
	sx.text = &_buffer[_cursor];
	while (_cursor + 2 < _buffer.size() &&
		   (_buffer[_cursor] != '-' ||
		    _buffer[_cursor + 1] != '-' ||
		    _buffer[_cursor + 2] != '>')){
		if (_buffer[_cursor] == '\n')
			lineCount++;
		_cursor++;
	}
	sx.length = &_buffer[_cursor] - sx.text;
	if (_cursor + 2 >= _buffer.size()){
		_cursor = _buffer.size();
		errorText(XEC_COMMENT, sx, commentLoc);
		_parseError = true;
	} else {
		if (_processContent)
			commentText(sx, commentLoc);
		_cursor += 3;
	}
}

void Parser::consumeEscapeSequence() {
	if ((_buffer[_cursor + 1] == 'l' || _buffer[_cursor + 1] == 'L') &&
		(_buffer[_cursor + 2] == 't' || _buffer[_cursor + 2] == 'T') &&
		_buffer[_cursor + 3] == ';'){
		*_fillPoint++ = '<';
		_cursor += 4;
		return;
	}
	if ((_buffer[_cursor + 1] == 'g' || _buffer[_cursor + 1] == 'G') &&
		(_buffer[_cursor + 2] == 't' || _buffer[_cursor + 2] == 'T') &&
		_buffer[_cursor + 3] == ';'){
		*_fillPoint++ = '>';
		_cursor += 4;
		return;
	}
	if ((_buffer[_cursor + 1] == 'a' || _buffer[_cursor + 1] == 'A') &&
		(_buffer[_cursor + 2] == 'm' || _buffer[_cursor + 2] == 'M') &&
		(_buffer[_cursor + 3] == 'p' || _buffer[_cursor + 3] == 'P') &&
		_buffer[_cursor + 4] == ';'){
		*_fillPoint++ = '&';
		_cursor += 5;
		return;
	}
	if ((_buffer[_cursor + 1] == 'a' || _buffer[_cursor + 1] == 'A') &&
		(_buffer[_cursor + 2] == 'p' || _buffer[_cursor + 2] == 'P') &&
		(_buffer[_cursor + 3] == 'o' || _buffer[_cursor + 3] == 'O') &&
		(_buffer[_cursor + 4] == 's' || _buffer[_cursor + 4] == 'S') &&
		_buffer[_cursor + 5] == ';'){
		*_fillPoint++ = '\'';
		_cursor += 6;
		return;
	}
	if ((_buffer[_cursor + 1] == 'q' || _buffer[_cursor + 1] == 'Q') &&
		(_buffer[_cursor + 2] == 'u' || _buffer[_cursor + 2] == 'U') &&
		(_buffer[_cursor + 3] == 'o' || _buffer[_cursor + 3] == 'O') &&
		(_buffer[_cursor + 4] == 't' || _buffer[_cursor + 4] == 'T') &&
		_buffer[_cursor + 5] == ';'){
		*_fillPoint++ = '"';
		_cursor += 6;
		return;
	}

	_parseError = true;

	saxString sx;

	sx.text = &_buffer[_cursor];
	sx.length = 1;
	errorText(XEC_ESCAPE, sx, (script::fileOffset_t)_cursor);
	*_fillPoint++ = _buffer[_cursor++];
}

XMLParserAttributeList* Parser::getAttribute() {
	if (_freeAttribs != null){
		XMLParserAttributeList* f = _freeAttribs;
		_freeAttribs = f->next;
		return f;
	}
	return new XMLParserAttributeList();
}

void Parser::freeAttribute(XMLParserAttributeList* a) {
	a->next = _freeAttribs;
	_freeAttribs = a;
}

string escape(const string& s) {
	string output;
	for (int i = 0; i < s.size(); i++) {
		switch (s[i]){
		case	'<':
			output.append("&lt;");
			break;

		case	'>':
			output.append("&gt;");
			break;

		case	'&':
			output.append("&amp;");
			break;

		case	'\'':
			output.append("&apos;");
			break;

		case	'\"':
			output.append("&quot;");
			break;

		default:
			output.push_back(s[i]);
		}
	}
	return output;
}

bool isXMLSpace(const saxString& txt) {
	for (int i = 0; i < txt.length; i++)
		if (!isXMLSpace(txt.text[i]))
			return false;
	return true;
}

bool isXMLSpace(char c) {
	if (c == ' ' ||
		c == '\t' ||
		c == '\r' ||
		c == '\n')
		return true;
	else
		return false;
}

double sax_to_double(const char* text, int length) {
	bool neg = false;
	if (text[0] == '-') {
		neg = true;
		text++;
		length--;
	}
	double result = 0.0;
	int i;
	for (i = 0; i < length; i++){
		if (text[i] == '.')
			break;
		result = result * 10 + (text[i] - '0');
	}
	if (i < length){
		i++;
		double divisor = 10.0f;
		while (i < length){
			if (text[i] == 'e' ||
				text[i] == 'E')
				break;
			result += (text[i] - '0') / divisor;
			divisor *= 10;
			i++;
		}
		if (i < length){
			i++;
			int exponent = 0;
			bool negative = false;
			if (i < length){
				if (text[i] == '-'){
					negative = true;
					i++;
				} else if (text[i] == '+')
					i++;
				while (i < length){
					exponent = exponent * 10 + (text[i] - '0');
					i++;
				}
			}
			if (negative)
				exponent = -exponent;
			result = result * pow(10.0, exponent);
		}
	}
	if (neg)
		result = -result;
	return result;
}

const char* errorCodeString(ErrorCodes ec) {
	static const char* labels[] = {
		"bad escape sequence",					// XEC_ESCAPE
		"unterminated comment",					// XEC_COMMENT
		"unterminated tag",						// XEC_UNTERMINATED
		"expected closing angle bracket",		// XEC_EXPECT_CLOSE
		"no elements in callback tables",		// XEC_NO_ELEMENTS
		"element not matched in tables",		// XEC_UNKNOWN_ELEMENT
		"opening and closing tag do not agree",	// XEC_MISMATCH
		"non-white space text outside root tag",// XEC_EXTRA_TEXT
		"expected an attribute",				// XEC_EXPECTED_ATTRIBUTE
	};
	if (ec < XEC_ESCAPE || ec > XEC_EXPECTED_ATTRIBUTE)
		return "** Unknown error code ***";
	else
		return labels[ec];
}

}  // namespace xml
