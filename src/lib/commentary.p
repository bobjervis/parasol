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
namespace parasol:compiler;

enum MessageId {
	ABSTRACT_INSTANCE_DISALLOWED,
	AMBIGUOUS_REFERENCE,
	BAD_TOKEN,
	FILE_NOT_READ,
	BREAK_NO_SEMI,
	CASE_NO_CO,
	DISALLOWED_ANNOTATION,
	EXPECTING_TERM,
	NOT_EXPECTING_ELSE,
	UNEXPECTED_EOF,
	DO_WHILE_NO_SEMI,
	UNEXPECTED_RC,
	EXPECTING_RS,
	EXPECTING_RC,
	SYNTAX_ERROR,
	DUPLICATE,
	OVERLOAD_DISALLOWED,
	UNDEFINED,
	UNDEFINED_BUILT_IN,
	INVALID_IMPORT,
	NOT_A_TYPE,
	CANNOT_CONVERT,
	NOT_A_FUNCTION,
	INVALID_SUPER,
	NOT_A_TEMPLATE,
	NO_CODE,
	BAD_STRING,
	BAD_CHAR,
	UNREACHABLE,
	CIRCULAR_DEFINITION,
	RETURN_VALUE_DISALLOWED,
	RETURN_VALUE_REQUIRED,
	RETURN_DISALLOWED,
	TYPE_MISMATCH,
	INVALID_MULTIPLY,
	INVALID_DIVIDE,
	INVALID_REMAINDER,
	INVALID_ADD,
	INVALID_SUBTRACT,
	INVALID_NEGATE,
	INVALID_SUBSCRIPT,
	INVALID_BIT_COMPLEMENT,
	INVALID_UNARY_PLUS,
	LEFT_NOT_INT,
	SHIFT_NOT_INT,
	NOT_BOOLEAN,
	INVALID_CASE,
	NOT_ENUM_INSTANCE,
	INVALID_DEFAULT,
	INVALID_BREAK,
	INVALID_CONTINUE,
	INVALID_AND,
	INVALID_OR,
	INVALID_XOR,
	INVALID_COMPARE,
	INVALID_INDIRECT,
	INVALID_SWITCH,
	NOT_INTEGER,
	NOT_NUMERIC,
	NOT_ADDRESSABLE,
	BAD_ELLIPSIS,
	NOT_SIMPLE_VARIABLE,
	DUPLICATE_DESTRUCTOR,
	NO_PARAMS_IN_DESTRUCTOR,
	THIS_NOT_ALLOWED,
	SUPER_NOT_ALLOWED,
	NO_MATCHING_OVERLOAD,
	NO_MATCHING_CONSTRUCTOR,
	AMBIGUOUS_OVERLOAD,
	AMBIGUOUS_CONSTRUCTOR,
	NOT_CONSTANT,
	NOT_PARAMETERIZED_TYPE,
	NO_FUNCTION_TYPE,
	NO_EXPRESSION_TYPE,
	TYPE_ALREADY_DEFINED,
	STATIC_DISALLOWED,
	ONLY_STATIC_VARIABLE,
	BAD_MULTI_ASSIGN,
	TOO_MANY_RETURN_ASSIGNMENTS,
	LVALUE_REQUIRED,
	INTERNAL_ERROR,
	UNRESOLVED_ABSTRACT,
	UNRECOGNIZED_ANNOTATION,
	
	UNFINISHED_CHECK_STORAGE,
	UNFINISHED_MAP_TO_VALUES,
	UNFINISHED_INSTANTIATE_TEMPLATE,
	UNFINISHED_NAMESPACE,
	UNFINISHED_INITIALIZER,
	UNFINISHED_ASSIGN_TYPE,
	UNFINISHED_CONTROL_FLOW,
	UNFINISHED_MARKUP_DECLARATOR,
	UNFINISHED_BUILD_SCOPE,
	UNFINISHED_BUILD_UNDER_SCOPE,
	UNFINISHED_BIND_DECLARATORS,
	UNFINISHED_GENERATE,
	UNFINISHED_ASSIGN_STORAGE,
	UNFINISHED_FIXED_ARRAY,
	UNFINISHED_CONSTRUCTION,
	
	MAX_MESSAGE
}

class Commentary {
	MessageId _messageId;
	ref<Commentary> _next;
	string _message;

	Commentary(ref<Commentary> next, MessageId messageId, string message) {
		_next = next;
		_messageId = messageId;
		_message = message;
	}

	public ref<Commentary> clone(ref<MemoryPool> pool) {
		ref<Commentary> next;
		if (_next != null)
			next = _next.clone(pool);
		return pool.newCommentary(next, _messageId, _message);		
	}
	
	public void print(int indent) {
		printf("%*.*c%d %s[%s]\n", indent, indent, ' ', int(_messageId), string(_messageId), _message);
	}

	public ref<Commentary> next() { 
		return _next; 
	}
	
	public string message() { 
		return _message; 
	}

	public MessageId messageId() { 
		return _messageId; 
	}
}

class Message {
	public ref<Commentary> commentary;
	public Location location;
}

MessageMap messageMap;

class MessageMap {
	private static string[MessageId] _message;
	
	MessageMap() {
		_message.resize(MessageId.MAX_MESSAGE);
		_message[MessageId.ABSTRACT_INSTANCE_DISALLOWED] = "Instance of abstract class disallowed";
		_message[MessageId.AMBIGUOUS_CONSTRUCTOR] = "Ambiguous constructor call";
		_message[MessageId.AMBIGUOUS_OVERLOAD] = "Ambiguous call, cannot choose between multiple valid overloads";
		_message[MessageId.AMBIGUOUS_REFERENCE] = "Ambiguous function reference";
		_message[MessageId.BAD_CHAR] = "Invalid escape sequence in '%1'";
		_message[MessageId.BAD_ELLIPSIS] = "Misplaced use of ellipsis";
		_message[MessageId.BAD_MULTI_ASSIGN] = "Multi-assignment only allowed with a function call";
		_message[MessageId.BAD_STRING] = "Invalid escape sequence in '%1'";
		_message[MessageId.BAD_TOKEN] = "Invalid token '%1'";
		_message[MessageId.BREAK_NO_SEMI] = "Break without semi-colon";
		_message[MessageId.CANNOT_CONVERT] = "Cannot convert types";
		_message[MessageId.CASE_NO_CO] = "Case without colon";
		_message[MessageId.CIRCULAR_DEFINITION] = "Circular definition involving '%1'";
		_message[MessageId.DISALLOWED_ANNOTATION] = " Disallowed annotation '%1'";
		_message[MessageId.DO_WHILE_NO_SEMI] = "do-while with no semi-colon";
		_message[MessageId.DUPLICATE] = "Duplicate definition of '%1'";
		_message[MessageId.DUPLICATE_DESTRUCTOR] = "More than one destructor in a class";
		_message[MessageId.EXPECTING_RC] = "Expecting a right curly brace";
		_message[MessageId.EXPECTING_RS] = "Expecting a right square brace";
		_message[MessageId.EXPECTING_TERM] = "Expecting a term of an expression";
		_message[MessageId.FILE_NOT_READ] = "File could not be read";
		_message[MessageId.INTERNAL_ERROR] = "Internal error detected";
		_message[MessageId.INVALID_ADD] = "Invalid type for addition";
		_message[MessageId.INVALID_AND] = "Invalid type for bitwise and";
		_message[MessageId.INVALID_BIT_COMPLEMENT] = "Invalid type for bitwise complement";
		_message[MessageId.INVALID_BREAK] = "Break statement outside of loop or switch";
		_message[MessageId.INVALID_CASE] = "Case statement outside of switch";
		_message[MessageId.INVALID_COMPARE] = "Invalid type for comparison";
		_message[MessageId.INVALID_CONTINUE] = "Continue statement outside of loop";
		_message[MessageId.INVALID_DEFAULT] = "Default statement outside of switch";
		_message[MessageId.INVALID_DIVIDE] = "Invalid type for divide";
		_message[MessageId.INVALID_IMPORT] = "Invalid import from your own namespace";
		_message[MessageId.INVALID_INDIRECT] = "Invalid type for indirection";
		_message[MessageId.INVALID_MULTIPLY] = "Invalid type for multiply";
		_message[MessageId.INVALID_NEGATE] = "Invalid type for negation";
		_message[MessageId.INVALID_OR] = "Invalid type for bitwise or";
		_message[MessageId.INVALID_REMAINDER] = "Invalid type for remainder";
		_message[MessageId.INVALID_SUBSCRIPT] = "Not a collection";
		_message[MessageId.INVALID_SUBTRACT] = "Invalid type for subtraction";
		_message[MessageId.INVALID_SUPER] = "'super' call not allowed here";
		_message[MessageId.INVALID_SWITCH] = "Invalid type in switch expression";
		_message[MessageId.INVALID_UNARY_PLUS] = "Invalid type for unary plus";
		_message[MessageId.INVALID_XOR] = "Invalid type for bitwise exclusive-or";
		_message[MessageId.LEFT_NOT_INT] = "Left operand not an integral type";
		_message[MessageId.LVALUE_REQUIRED] = "Not an assignable object expression";
		_message[MessageId.NO_CODE] = "No code generated for this unit";
		_message[MessageId.NO_EXPRESSION_TYPE] = "No type for expression";
		_message[MessageId.NO_FUNCTION_TYPE] = "No type for '%1'";
		_message[MessageId.NO_MATCHING_CONSTRUCTOR] = "No matching constructor";
		_message[MessageId.NO_MATCHING_OVERLOAD] = "No overloaded definition matched this reference";
		_message[MessageId.NO_PARAMS_IN_DESTRUCTOR] = "No parameters may be defined for a destructor";
		_message[MessageId.NOT_A_FUNCTION] = "Expecting a function";
		_message[MessageId.NOT_A_TEMPLATE] = "Expecting a template class";
		_message[MessageId.NOT_A_TYPE] = "Expecting a type";
		_message[MessageId.NOT_ADDRESSABLE] = "Cannot take the address of this value";
		_message[MessageId.NOT_BOOLEAN] = "An operand does not have boolean type";
		_message[MessageId.NOT_CONSTANT] = "Constant expression required";
		_message[MessageId.NOT_ENUM_INSTANCE] = "Case expression not an enum instance";
		_message[MessageId.NOT_EXPECTING_ELSE] = "Not expecting an 'else'";
		_message[MessageId.NOT_INTEGER] = "An operand does not have integral type";
		_message[MessageId.NOT_NUMERIC] = "An operand does not have numeric type";
		_message[MessageId.NOT_PARAMETERIZED_TYPE] = "Not a parameterized type found resolving overloads for '%1'";
		_message[MessageId.NOT_SIMPLE_VARIABLE] = "'%1' does not name a simple variable";
		_message[MessageId.ONLY_STATIC_VARIABLE] = "Must reference a static variable";
		_message[MessageId.OVERLOAD_DISALLOWED] = "Cannot mix overloaded and non-overloaded definitions in the same scope for '%s'";
		_message[MessageId.RETURN_DISALLOWED] = "Return statement not allowed";
		_message[MessageId.RETURN_VALUE_DISALLOWED] = "Return value not allowed";
		_message[MessageId.RETURN_VALUE_REQUIRED] = "Return value required";
		_message[MessageId.SHIFT_NOT_INT] = "Shift amount cannot be converted to int";
		_message[MessageId.STATIC_DISALLOWED] = "Keyword 'static' disallowed";
		_message[MessageId.SUPER_NOT_ALLOWED] = "Use of 'super' not allowed";
		_message[MessageId.SYNTAX_ERROR] = "Syntax error";
		_message[MessageId.THIS_NOT_ALLOWED] = "Use of 'this' not allowed";
		_message[MessageId.TOO_MANY_RETURN_ASSIGNMENTS] = "Too many return assignments";
		_message[MessageId.TYPE_ALREADY_DEFINED] = "Type already defined";
		_message[MessageId.TYPE_MISMATCH] = "Types do not convert to a common type";
		_message[MessageId.UNDEFINED] = "Undefined identifier '%1'";
		_message[MessageId.UNDEFINED_BUILT_IN] = "Undefined built in name '%1'";
		_message[MessageId.UNEXPECTED_EOF] = "Unexpected end of input";
		_message[MessageId.UNEXPECTED_RC] = "Unexpected right curly brace";
		_message[MessageId.UNFINISHED_ASSIGN_STORAGE] = "Unfinished: %1 assignVariableStorage()";
		_message[MessageId.UNFINISHED_ASSIGN_TYPE] = "Unfinished: assignTypes %1/%2";
		_message[MessageId.UNFINISHED_BIND_DECLARATORS] = "Unfinished: bindDeclarators %1/%2";
		_message[MessageId.UNFINISHED_BUILD_SCOPE] = "Unfinished: buildScopes %1/%2";
		_message[MessageId.UNFINISHED_BUILD_UNDER_SCOPE] = "Unfinished: buildUnderScope %1/%2";
		_message[MessageId.UNFINISHED_CHECK_STORAGE] = "Unfinished: checkStorage %1";
		_message[MessageId.UNFINISHED_CONSTRUCTION] = "Unfinished: constructor initializer";
		_message[MessageId.UNFINISHED_CONTROL_FLOW] = "Unfinished: control flow %1/%2";
		_message[MessageId.UNFINISHED_FIXED_ARRAY] = "Unfinished: fixed length array";
		_message[MessageId.UNFINISHED_GENERATE] = "Unfinished: generate %1/%2: %3";
		_message[MessageId.UNFINISHED_INITIALIZER] = "Unfinished: static initializer";
		_message[MessageId.UNFINISHED_INSTANTIATE_TEMPLATE] = "Unfinished: instantiateTemplate";
		_message[MessageId.UNFINISHED_MAP_TO_VALUES] = "Unfinished: mapToValues";
		_message[MessageId.UNFINISHED_MARKUP_DECLARATOR] = "Unfinished: markupDeclarator %1/%2";
		_message[MessageId.UNFINISHED_NAMESPACE] = "Unfinished: anonymous namespace";
		_message[MessageId.UNREACHABLE] = "Unreachable code";
		_message[MessageId.UNRECOGNIZED_ANNOTATION] = "Unrecognized annotation '%1'";
		_message[MessageId.UNRESOLVED_ABSTRACT] = "Abstract method has no override '%1'";
		string last = "<first>";
		int lastI = -1;
		for (int i = 0; i < int(MessageId.MAX_MESSAGE); i++) {
			MessageId m = MessageId(i);
			if (_message[m] == null) {
				printf("ERROR: Message %d has no message entry (last defined entry: %s %d)\n", i, last, lastI);
				string s;
				s.printf("<message #%d>", i);
				_message[m] = s;
			} else {
				last = _message[m];
				lastI = i;
			}
		}
	}

	public string format(MessageId messageId, CompileString[] args) {
		string format = _message[messageId];
		string s;
		int i = 0;
		
		while (i < format.length()) {
			if (format[i] == '%') {
				int position;
				i++;
				switch (format[i]) {
				case	'1':
				case	'2':
				case	'3':
				case	'4':
				case	'5':
				case	'6':
				case	'7':
				case	'8':
				case	'9':
					position = format[i] - '1';
//					printf("position = %d args.length=%d\n", position, args.length());
//					printf("args[0]={%x,%d}\n", int(args[position].data), args[position].length);
					string inclusionString(args[position].data, args[position].length);
//					printf("inclusionString=%s\n", inclusionString);
					s.append(inclusionString);
					break;

				case	'%':
					s.append('%');

				default:
					break;
				}
			} else
				s.append(format[i]);
			i++;
		}
		return s;
	}

	MessageId messageId(string messageIdName) {
		for (int i = 0; i < int(MessageId.MAX_MESSAGE); i++)
			if (string(MessageId(i)) == messageIdName)
				return MessageId(i);
		return MessageId.MAX_MESSAGE;
	}

};
