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
#include <ctype.h>
#include <stdio.h>
#include "script.h"
#include "string.h"

namespace xml {

class Attribute;
class Document;
class DOMParser;
class Element;

Document* load(const string& filename, bool exact);

/*
	The XML parser contained in this file is based on the XML Specification
	described in W3C document REC-xml-19980210.  It is available at

		http://www.w3.org/TR/1998/REC-xml-19980210.html

	At present this implementation is incomplete.  Processing instructions, !DOCTYPE, 
	!ATTLIST and !ELEMENT tags are not recognized.  Escape sequences are recognized 
	for lt, gt, amp, apos and quot.  Character escape sequences (&#) are not recognized.

	As an extensions, the tag name is optional in a closing tag.  Thus

		<foo>
		</>

	is equivalent to

		<foo>
		</foo>

	A parse error is reported only if the XML is not well-formed.  No schema validation
	is done.

	Because this is not an exhaustive implementation of XML, one should use caution
	with this code.  In particular, adding code to this may be needed to recognize
	certain forms properly.
 */
class Document {
	friend class DOMParser;
public:
	Document();

	void clear();

	Element* root() const { return _root; }

	void set_root(Element* e) { _root = e; }
	/*
	newRoot:		event (root: Element)
	newChild:		event (parent: Element)
	newSibling:		event (existing: Element)
	closeTag:		event (closing: Element)
	deleteElement:	event (deleting: Element)
	changeElement:	event (changing: Element)

	new: ()
	{
	}

	new: (root: Element, pe: boolean)
	{
		this._root = root
		this.parseError = pe
	}
	*/
	Element* getValue(const string& id);

	bool load(const string& filename, bool exact);

	void load(FILE* stream, bool exact);
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
	*/
bool		parseError() const { return _parseError; }

private:
	Element*	_root;
	bool		_parseError;
};

enum ElementKind {
	ELEMENT,
	TEXT,						// tag is the text, no children
	COMMENT,					// tag is the text, no children
	PROCESSING_INSTRUCTION,		// tag is the PITarget and text
	ERROR_TEXT,					// tag is the bad text
	ROOT,						// root node of a parse
	DECLARATION,				// tag is the declaration tag (!DOCTYPE, etc.)
};

class Element {
public:
	Element(const string& tag, script::fileOffset_t i);

	Element(const string& tag, script::fileOffset_t i, ElementKind kind);

	Element* getById(const string& id);

	string* getValue(const string& name);

	void setValue(const string& name, const string* value, script::fileOffset_t location);
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
	void append(Element* e);
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
	void extract();
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
	*/

	Element*				parent;
	Element*				child;
	Element*				sibling;
	ElementKind				kind;
	string					tag;
	script::fileOffset_t	location;
	Attribute*				attributes;

private:
	void init();
};

class Attribute {
public:
	Attribute(const string& name, const string& value, script::fileOffset_t location) {
		this->next = null;
		this->name = name;
		this->value = value;
		this->location = location;
	}

	Attribute*				next;
	string					name;
	string					value;
	script::fileOffset_t	location;
};

enum ErrorCodes {
	XEC_ESCAPE,						// bad escape sequence
	XEC_COMMENT,					// unterminated comment
	XEC_UNTERMINATED,				// end of stream with unterminated tag
	XEC_EXPECT_CLOSE,				// expected closing angle bracket
	XEC_NO_ELEMENTS,				// no elements in callback tables
	XEC_UNKNOWN_ELEMENT,			// element not matched in tables
	XEC_MISMATCH,					// opening and closing tag do not agree
	XEC_EXTRA_TEXT,					// non-white space text outside root tag
	XEC_EXPECTED_ATTRIBUTE,			// expected an attribute (text is the attribute name)
};

const char* errorCodeString(ErrorCodes ec);

double sax_to_double(const char* text, int length);

struct saxString {
	char*				text;
	int					length;

	saxString() {
		text = null;
		length = 0;
	}

	bool equals(const char* v) const {
		if (strncmp(text, v, length) == 0 &&
			v[length] == 0)
			return true;
		else
			return false;
	}

	string toString() const {
		return string(text, length);
	}

	double toDouble() const {
		// turns out: strtod is really, really slow in VC
		return sax_to_double(text, length);
	}

	int toInt() const {
		string s(text, length);
		return atoi(s.c_str());
	}

	int hexInt() const {
		int v = 0;
		for (int i = 0; i < length; i++) {
			v <<= 4;
			if (isdigit(text[i]))
				v += text[i] - '0';
			else if (isxdigit(text[i]))
				v += 10 + tolower(text[i]) - 'a';
			else
				return -1;
		}
		return v;
	}
};

struct XMLParserAttributeList {
	XMLParserAttributeList*	next;
	saxString				name;
	saxString				value;
	script::fileOffset_t	location;

	XMLParserAttributeList() {
		next = null;
		location = script::FILE_OFFSET_ZERO;
	}
};

class Parser {
public:
	Parser(script::MessageLog* messageLog);

	virtual ~Parser();

		// These methods are generated by the compiler - DO NOT MODIFY

	virtual int matchTag(const saxString& tag);

	virtual bool matchedTag(int index);

	virtual bool matchAttribute(int index, 
								XMLParserAttributeList* attribute);

		// Implementation methods below - Modify as much as you like

	void open(const string& text);

	void close();

	bool parse();

	bool load(const string& filename);

	void disallowContents();

	void parseContents();

	void skipContents();

	virtual void inlineText(const saxString& text, script::fileOffset_t location);

	virtual void errorText(ErrorCodes code, const saxString& text, script::fileOffset_t location);

	virtual void commentText(const saxString& text, script::fileOffset_t location);

	virtual bool anyTag(const saxString& tag);

	virtual void anyCloseTag();

	script::fileOffset_t textLocation(const saxString& s);

	bool reportError(const string& message, script::fileOffset_t location);

	script::MessageLog* messageLog() const { return _messageLog; }

	bool parseError() const { return _parseError; }

	int						lineCount;
	saxString				tag;
	script::fileOffset_t	tagLocation;
	XMLParserAttributeList*	unknownAttributes;
	bool					rootTag;
private:
	void consumeText(const saxString& enclosingTag);

	bool consumeTag(const saxString& enclosingTag);

	void reportInlineText();

	bool collectText(char delim);

	void skipWhiteSpace();

	void skipComment();

	void resetAttributes();

	XMLParserAttributeList* getAttribute();

	void defineAttribute(int matchingElement,
						 XMLParserAttributeList* attribute);

	void freeAttribute(XMLParserAttributeList* a);

	void consumeEscapeSequence();

	bool					_parseError;
	bool					_consumedContents;
	bool					_noContents;
	bool					_allowContents;
	string					_buffer;
	char*					_fillPoint;
	int						_cursor;
	char*					_inlineTextPoint;
	XMLParserAttributeList* _freeAttribs;
	bool					_processContent;
	script::MessageLog*		_messageLog;
};

class DOMParser : public Parser {
	typedef Parser super;
public:
	/*
	new: ()
	{
		xmlDoc = new Document()
	}
	*/
	DOMParser(Document* doc, script::MessageLog* messageLog);
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
	void parse() { super::parse(); }

	Document* parse(FILE* stream, bool e);

	virtual void inlineText(const saxString& text, script::fileOffset_t location);

	virtual void errorText(ErrorCodes code, const saxString& text, script::fileOffset_t location);

	virtual void commentText(const saxString& text, script::fileOffset_t location);

	virtual bool anyTag(const saxString& tag);

	virtual void anyCloseTag();

private:
	void append(Element* e);

	void push();

	bool pop();

	Document* result();

	Document*			xmlDoc;
	bool				exact;
	Element*			last;
	Element*			context;
};

string escape(const string& s);

#if 0
XMLParserElementCallbacks: public type {
public:
	name:					string
	knownAttributes:		pointer [] instance XMLParserAttributeDescriptor
	allowUnknownAttributes:	boolean
	tag:					pointer (callbacks: pointer XMLParserImpl,
										parentContext: pointer any, 
										tag: saxString, 
										attributeInfo: pointer any, 
										additionalAttributes: pointer XMLParserAttributeList) pointer any
	closeTag:				pointer (callbacks: pointer XMLParserImpl,
										context: pointer any)
}

XMLParserAttributeDescriptor: public type {
public:
	name:				string
	offset:				size_t
	kind:				script.TypeinfoKind
}
#endif
extern saxString saxNull;

bool isXMLSpace(const saxString& txt);

bool isXMLSpace(char c);

}  // namespace xml
