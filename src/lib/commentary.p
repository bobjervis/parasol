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
	ANNOTATION_TAKES_NO_ARGUMENTS,
	INITIALIZER_MUST_BE_CONSTANT,
	INITIALIZER_REQUIRED,
	CONSTANT_NOT_STATIC,
	EXPECTING_TERM,
	LABEL_REQUIRED,
	LABEL_NOT_IDENTIFIER,
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

public string formatMessage(MessageId messageId, CompileString[] args) {
	string format = messageCatalog[messageId];
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

private string[MessageId] messageCatalog = [ 
	ABSTRACT_INSTANCE_DISALLOWED: "Instance of abstract class disallowed",
	AMBIGUOUS_CONSTRUCTOR: 	"Ambiguous constructor call",
	AMBIGUOUS_OVERLOAD: 	"Ambiguous call, cannot choose between multiple valid overloads",
	AMBIGUOUS_REFERENCE: 	"Ambiguous function reference",
	ANNOTATION_TAKES_NO_ARGUMENTS: "'%1' Annotation takes no arguments",
	BAD_CHAR: 				"Invalid escape sequence in '%1'",
	BAD_ELLIPSIS: 			"Misplaced use of ellipsis",
	BAD_MULTI_ASSIGN: 		"Multi-assignment only allowed with a function call",
	BAD_STRING: 			"Invalid escape sequence in '%1'",
	BAD_TOKEN: 				"Invalid token '%1'",
	BREAK_NO_SEMI: 			"Break without semi-colon",
	CANNOT_CONVERT: 		"Cannot convert types",
	CASE_NO_CO: 			"Case without colon",
	CIRCULAR_DEFINITION: 	"Circular definition involving '%1'",
	CONSTANT_NOT_STATIC:	"@Constant declarations must have static storage class",
	DISALLOWED_ANNOTATION: 	"Disallowed annotation '%1'",
	DO_WHILE_NO_SEMI: 		"do-while with no semi-colon",
	DUPLICATE: 				"Duplicate definition of '%1'",
	DUPLICATE_DESTRUCTOR: 	"More than one destructor in a class",
	EXPECTING_RC: 			"Expecting a right curly brace",
	EXPECTING_RS: 			"Expecting a right square brace",
	EXPECTING_TERM: 		"Expecting a term of an expression",
	FILE_NOT_READ: 			"File could not be read",
	INITIALIZER_MUST_BE_CONSTANT: "Initializer with @Constant must be compile-time constant expression",
	INITIALIZER_REQUIRED:	"Initializer required with @Constant annotation",
	INTERNAL_ERROR: 		"Internal error detected",
	INVALID_ADD: 			"Invalid type for addition",
	INVALID_AND: 			"Invalid type for bitwise and",
	INVALID_BIT_COMPLEMENT: "Invalid type for bitwise complement",
	INVALID_BREAK: 			"Break statement outside of loop or switch",
	INVALID_CASE: 			"Case statement outside of switch",
	INVALID_COMPARE: 		"Invalid type for comparison",
	INVALID_CONTINUE: 		"Continue statement outside of loop",
	INVALID_DEFAULT: 		"Default statement outside of switch",
	INVALID_DIVIDE: 		"Invalid type for divide",
	INVALID_IMPORT: 		"Invalid import from your own namespace",
	INVALID_INDIRECT: 		"Invalid type for indirection",
	INVALID_MULTIPLY: 		"Invalid type for multiply",
	INVALID_NEGATE: 		"Invalid type for negation",
	INVALID_OR: 			"Invalid type for bitwise or",
	INVALID_REMAINDER: 		"Invalid type for remainder",
	INVALID_SUBSCRIPT: 		"Not a collection",
	INVALID_SUBTRACT: 		"Invalid type for subtraction",
	INVALID_SUPER: 			"'super' call not allowed here",
	INVALID_SWITCH: 		"Invalid type in switch expression",
	INVALID_UNARY_PLUS: 	"Invalid type for unary plus",
	INVALID_XOR: 			"Invalid type for bitwise exclusive-or",
	LABEL_REQUIRED: 		"Initializer expression must have a label",
	LABEL_NOT_IDENTIFIER: 	"Label for this expression is not an identifier",
	LEFT_NOT_INT:			"Left operand not an integral type",
	LVALUE_REQUIRED: 		"Not an assignable object expression",
	NO_CODE: 				"No code generated for this unit",
	NO_EXPRESSION_TYPE: 	"No type for expression",
	NO_FUNCTION_TYPE: 		"No type for '%1'",
	NO_MATCHING_CONSTRUCTOR: "No matching constructor",
	NO_MATCHING_OVERLOAD: 	"No overloaded definition matched this reference",
	NO_PARAMS_IN_DESTRUCTOR: "No parameters may be defined for a destructor",
	NOT_A_FUNCTION: 		"Expecting a function",
	NOT_A_TEMPLATE: 		"Expecting a template class",
	NOT_A_TYPE: 			"Expecting a type",
	NOT_ADDRESSABLE: 		"Cannot take the address of this value",
	NOT_BOOLEAN: 			"An operand does not have boolean type",
	NOT_CONSTANT: 			"Constant expression required",
	NOT_ENUM_INSTANCE: 		"Case expression not an enum instance",
	NOT_EXPECTING_ELSE: 	"Not expecting an 'else'",
	NOT_INTEGER: 			"An operand does not have integral type",
	NOT_NUMERIC: 			"An operand does not have numeric type",
	NOT_PARAMETERIZED_TYPE: "Not a parameterized type found resolving overloads for '%1'",
	NOT_SIMPLE_VARIABLE: 	"'%1' does not name a simple variable",
	ONLY_STATIC_VARIABLE: 	"Must reference a static variable",
	OVERLOAD_DISALLOWED: 	"Cannot mix overloaded and non-overloaded definitions in the same scope for '%s'",
	RETURN_DISALLOWED: 		"Return statement not allowed",
	RETURN_VALUE_DISALLOWED: "Return value not allowed",
	RETURN_VALUE_REQUIRED: 	"Return value required",
	SHIFT_NOT_INT: 			"Shift amount cannot be converted to int",
	STATIC_DISALLOWED: 		"Keyword 'static' disallowed",
	SUPER_NOT_ALLOWED: 		"Use of 'super' not allowed",
	SYNTAX_ERROR: 			"Syntax error",
	THIS_NOT_ALLOWED: 		"Use of 'this' not allowed",
	TOO_MANY_RETURN_ASSIGNMENTS: "Too many return assignments",
	TYPE_ALREADY_DEFINED: 	"Type already defined",
	TYPE_MISMATCH: 			"Types do not convert to a common type",
	UNDEFINED: 				"Undefined identifier '%1'",
	UNDEFINED_BUILT_IN: 	"Undefined built in name '%1'",
	UNEXPECTED_EOF: 		"Unexpected end of input",
	UNEXPECTED_RC: 			"Unexpected right curly brace",
	UNFINISHED_ASSIGN_STORAGE: "Unfinished: %1 assignVariableStorage()",
	UNFINISHED_ASSIGN_TYPE: "Unfinished: assignTypes %1/%2",
	UNFINISHED_BIND_DECLARATORS: "Unfinished: bindDeclarators %1/%2",
	UNFINISHED_BUILD_SCOPE: "Unfinished: buildScopes %1/%2",
	UNFINISHED_BUILD_UNDER_SCOPE: "Unfinished: buildUnderScope %1/%2",
	UNFINISHED_CHECK_STORAGE: "Unfinished: checkStorage %1",
	UNFINISHED_CONSTRUCTION: "Unfinished: constructor initializer",
	UNFINISHED_CONTROL_FLOW: "Unfinished: control flow %1/%2",
	UNFINISHED_FIXED_ARRAY: "Unfinished: fixed length array",
	UNFINISHED_GENERATE: 	"Unfinished: generate %1/%2: %3",
	UNFINISHED_INITIALIZER: "Unfinished: static initializer",
	UNFINISHED_INSTANTIATE_TEMPLATE: "Unfinished: instantiateTemplate",
	UNFINISHED_MAP_TO_VALUES: "Unfinished: mapToValues",
	UNFINISHED_MARKUP_DECLARATOR: "Unfinished: markupDeclarator %1/%2",
	UNFINISHED_NAMESPACE: "Unfinished: anonymous namespace",
	UNREACHABLE: 			"Unreachable code",
	UNRECOGNIZED_ANNOTATION: "Unrecognized annotation '%1'",
	UNRESOLVED_ABSTRACT: 	"Abstract method has no override '%1'",
];

string last = "<first>";
int lastI = -1;
for (int i = 0; i < int(MessageId.MAX_MESSAGE); i++) {
	MessageId m = MessageId(i);
	if (messageCatalog[m] == null) {
		printf("ERROR: Message %d has no message entry (last defined entry: %s %d)\n", i, last, lastI);
		string s;
		s.printf("<message #%d>", i);
		messageCatalog[m] = s;
	} else {
		last = messageCatalog[m];
		lastI = i;
	}
}
