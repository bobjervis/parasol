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
namespace parasol:compiler;

public enum MessageId {
	ABSTRACT_INSTANCE_DISALLOWED			("Instance of abstract class disallowed, '%1' is not implemented."),
	AMBIGUOUS_CONSTRUCTOR					("Ambiguous constructor call"),
	AMBIGUOUS_OVERLOAD						("Ambiguous call, cannot choose between multiple valid overloads"),
	AMBIGUOUS_REFERENCE						("Ambiguous function reference"),
	ANNOTATION_TAKES_NO_ARGUMENTS			("'%1' Annotation takes no arguments"),
	BAD_CHAR								("Invalid escape sequence in '%1'"),
	BAD_COMPILE_TARGET						("More than one symbol with @CompileTarget annotation"),
	BAD_ELLIPSIS							("Misplaced use of ellipsis"),
	BAD_LINUX_BINDING						("@Linux annotation requires two arguments"),
	BAD_MONITOR_REF							("Reference to monitor member '%1' disallowed with dot operator"),
	BAD_MONITOR_REF_IDENTIFIER				("Reference to monitor member '%1' disallowed outside lock statement"),
	BAD_MULTI_ASSIGN						("Multi-assignment only allowed with a function call"),
	BAD_STRING								("Invalid escape sequence in '%1'"),
	BAD_TOKEN								("Invalid token '%1'"),
	BAD_WINDOWS_BINDING						("@Windows annotation requires two arguments"),
	BAD_WRITE_ATTEMPT						("Modification of @Constant value is not allowed"),
	BREAK_NO_SEMI							("Break without semi-colon"),
	CANNOT_CONVERT							("Cannot convert types"),
	CANNOT_COPY_ARGUMENT					("Cannot pass %1 by value."),
	CANNOT_COPY_ASSIGN						("Cannot assign %1 by value."),
	CANNOT_COPY_RETURN						("Cannot return %1 by value."),
	CANNOT_EXTEND_ENUM						("Cannot extend enum type"),
	CASE_NO_CO								("Case without colon"),
	CIRCULAR_DEFINITION						("Circular definition involving '%1'"),
	CIRCULAR_EXTENDS						("Circular extends clause"),
	CLASS_MISSING_METHOD_FROM_INTERFACE		("Class missing method %1 for interface %2"),
	CONSTANT_NOT_ALLOWED					("@Constant annotation not allowed"),
	CONSTANT_NOT_STATIC						("@Constant declarations must have static storage class"),
	DISALLOWED_ANNOTATION					("Disallowed annotation '%1'"),
	DO_WHILE_NO_SEMI						("do-while with no semi-colon"),
	DUPLICATE								("Duplicate definition of '%1'"),
	DUPLICATE_DESTRUCTOR					("More than one destructor in a class"),
	DUPLICATE_INDEX							("Duplicate index in initializer"),
	EXPECTING_TERM							("Expecting a term of an expression"),
	EXPECTING_RC							("Expecting a right curly brace"),
	EXPECTING_RS							("Expecting a right square brace"),
	FILE_NOT_READ							("File could not be read"),
	FINAL_BASE_CLASS						("Cannot extend from final base class"),
	FINAL_BASE_INTERFACE					("Cannot extend from final base interface"),
	INITIALIZER_BEYOND_RANGE				("Initializer out of index range"),
	INITIALIZER_MUST_BE_CONSTANT			("Initializer with @Constant must be compile-time constant expression"),
	INITIALIZER_REQUIRED					("Initializer required with @Constant annotation"),
	INCORRECT_RETURN_COUNT					("Incorrect number of return expressions"),
	INTERNAL_ERROR							("Internal error detected"),
	INVALID_ADD								("Invalid type for addition"),
	INVALID_AND								("Invalid type for bitwise and"),
	INVALID_BINDING							("Invalid parameter name declaration of '%1'"),
	INVALID_BIT_COMPLEMENT					("Invalid type for bitwise complement"),
	INVALID_BREAK							("Break statement outside of loop or switch"),
	INVALID_CASE							("Case statement outside of switch"),
	INVALID_CAST_ARGS						("A cast expression must contain a single argument"),
	INVALID_COMPARE							("Invalid type for comparison"),
	INVALID_CONTINUE						("Continue statement outside of loop"),
	INVALID_DEFAULT							("Default statement outside of switch"),
	INVALID_DIVIDE							("Invalid type for divide"),
	INVALID_IMPORT							("Invalid import from your own namespace"),
	INVALID_INDIRECT						("Invalid type for indirection"),
	INVALID_MONITOR_EXTENSION				("Monitor cannot extend non-monitor base class"),
	INVALID_MULTIPLY						("Invalid type for multiply"),
	INVALID_NEGATE							("Invalid type for negation"),
	INVALID_OR								("Invalid type for bitwise or"),
	INVALID_REMAINDER						("Invalid type for remainder"),
	INVALID_SUBSCRIPT						("Not a collection"),
	INVALID_SUBTRACT						("Invalid type for subtraction"),
	INVALID_SUPER							("'super' call not allowed here"),
	INVALID_SWITCH							("Invalid type in switch expression"),
	INVALID_UNARY_PLUS						("Invalid type for unary plus"),
	INVALID_VOID							("Invalid use of void type"),
	INVALID_XOR								("Invalid type for bitwise exclusive-or"),
	LABEL_MISSING							("Label missing"),
	LABEL_REQUIRED							("Initializer expression must have a label"),
	LABEL_NOT_IDENTIFIER					("Label for this expression is not an identifier"),
	LEFT_NOT_INT							("Left operand not an integral type"),
	LVALUE_REQUIRED							("Not an assignable object expression"),
	MEMBER_REF_NOT_ALLOWED					("Reference to the member '%1' is not allowed"),
	METHOD_IS_FINAL							("Cannot override, base class method is final"),
	METHOD_MUST_BE_STATIC					("Method '%1' must be static"),
	NEEDS_MONITOR							("Expression must have monitor type"),
	NO_CODE									("No code generated for this unit"),
	NO_DEFAULT_CONSTRUCTOR					("No default constructor"),
	NO_EXPRESSION_TYPE						("No type for expression"),
	NO_FUNCTION_TYPE						("No type for '%1'"),
	NO_MATCHING_CONSTRUCTOR					("No matching constructor"),
	NO_MATCHING_OVERLOAD					("No overloaded definition matched %1"),
	NO_MATCHING_OVERLOAD_IN_CLASS			("No overloaded definition matched %1 in class %2"),
	NO_NAMESPACE_DEFINED					("No namespace defined"),
	NO_PARAMS_IN_DESTRUCTOR					("No parameters may be defined for a destructor"),
	NON_UNIQUE_NAMESPACE					("More than one namespace statement in the unit"),
	NOT_A_FUNCTION							("Expecting a function"),
	NOT_A_SHAPE								("Expecting a shape type"),
	NOT_A_TEMPLATE							("Expecting a template class"),
	NOT_A_TYPE								("Expecting a type"),
	NOT_ADDRESSABLE							("Cannot take the address of this value"),
	NOT_AN_ALLOCATOR						("Not an Allocator"),
	NOT_AN_EXCEPTION						("Not an Exception"),
	NOT_AN_INTERFACE						("Expecting an interface name"),
	NOT_BOOLEAN								("An operand does not have boolean or flags type"),
	NOT_CONSTANT							("Constant expression required"),
	NOT_ENUM_INSTANCE						("Case expression not an enum instance"),
	NOT_EXPECTING_ELSE						("Not expecting an 'else'"),
	NOT_INTEGER								("An operand does not have integral type"),
	NOT_NUMERIC								("An operand does not have numeric type"),
	NOT_PARAMETERIZED_TYPE					("Not a parameterized type found resolving overloads for '%1'"),
	NOT_SIMPLE_VARIABLE						("'%1' does not name a simple variable"),
	ONLY_STATIC_VARIABLE					("Must reference a static variable"),
	OVERLOAD_DISALLOWED						("Cannot mix overloaded and non-overloaded definitions in the same scope for '%s'"),
	REDUNDANT_DOCLET						("Too many paradoc doclet comments for this namespace"),
	REFERENCE_PREMATURE						("Cannot access an object before it has been constructod"),
	RETURN_DISALLOWED						("Return statement not allowed"),
	RETURN_VALUE_DISALLOWED					("Return value not allowed"),
	RETURN_VALUE_REQUIRED					("Return value required"),
	SHIFT_NOT_INT							("Shift amount cannot be converted to int"),
	STATIC_DISALLOWED						("Keyword 'static' disallowed"),
	STRING_LITERAL_EXPECTED					("String literal expected"),
	SUPER_NOT_ALLOWED						("Use of 'super' not allowed"),
	SYNTAX_ERROR							("Syntax error"),
	TEMPLATE_NAME_DISALLOWED				("Template name disallowed as a class"),
	THIS_NOT_ALLOWED						("Use of 'this' not allowed"),
	TOO_MANY_RETURN_ASSIGNMENTS				("Too many return assignments"),
	TYPE_ALREADY_DEFINED					("Type already defined"),
	TYPE_MISMATCH							("Types do not convert to a common type"),
	UNDEFINED								("Undefined identifier '%1'"),
	UNDEFINED_BUILT_IN						("Undefined built in name '%1'"),
	UNEXPECTED_ABSTRACT						("Unexpected abstract keyword in interface definition"),
	UNEXPECTED_EOF							("Unexpected end of input"),
	UNEXPECTED_FINAL						("Unexpected final keyword"),
	UNEXPECTED_RC							("Unexpected right curly brace"),
	UNREACHABLE								("Unreachable code"),
	UNRECOGNIZED_ANNOTATION					("Unrecognized annotation '%1'"),
	
	UNFINISHED_CHECK_STORAGE				("Unfinished: checkStorage %1"),
	UNFINISHED_MAP_TO_VALUES				("Unfinished: mapToValues"),
	UNFINISHED_INSTANTIATE_TEMPLATE			("Unfinished: instantiateTemplate"),
	UNFINISHED_NAMESPACE					("Unfinished: anonymous namespace"),
	UNFINISHED_INITIALIZER					("Unfinished: static initializer"),
	UNFINISHED_CONTROL_FLOW					("Unfinished: control flow %1/%2"),
	UNFINISHED_MARKUP_DECLARATOR			("Unfinished: markupDeclarator %1/%2"),
	UNFINISHED_BUILD_SCOPE					("Unfinished: buildScopes %1/%2"),
	UNFINISHED_BUILD_UNDER_SCOPE			("Unfinished: buildUnderScope %1/%2"),
	UNFINISHED_BIND_DECLARATORS				("Unfinished: bindDeclarators %1/%2"),
	UNFINISHED_GENERATE						("Unfinished: generate %1/%2: %3"),
	UNFINISHED_ASSIGN_STORAGE				("Unfinished: %1 assignVariableStorage()"),
	UNFINISHED_FIXED_ARRAY					("Unfinished: fixed length array"),
	UNFINISHED_CONSTRUCTION					("Unfinished: constructor initializer"),
	UNFINISHED_LOCK							("Unfinished: lock statement without monitor"),
	UNFINISHED_VAR_CAST						("Unfinished: conversion to var from %1"),

	MAX_MESSAGE;

	private string _message;

	MessageId() {
//		printf("this = %p\n", this);
	}

	MessageId(string message) {
		_message = message;
	}

	string message() {
		return _message;
	}
}

public class Commentary {
	MessageId _messageId;
	ref<Commentary> _next;
	substring _message;

	Commentary(ref<Commentary> next, MessageId messageId, substring message) {
		_next = next;
		_messageId = messageId;
		_message = message;
	}

	public ref<Commentary> clone(ref<MemoryPool> pool) {
		ref<Commentary> next;
		if (_next != null)
			next = _next.clone(pool);
		return pool.newCommentary(next, _messageId, pool.newCompileString(_message));		
	}
	
	public void print(int indent) {
		printf("%*.*c%d %s[%s]\n", indent, indent, ' ', int(_messageId), string(_messageId), _message);
	}

	public ref<Commentary> next() { 
		return _next; 
	}
	
	public substring message() { 
		return _message; 
	}

	public MessageId messageId() { 
		return _messageId; 
	}
}

public class Message {
	public ref<Commentary> commentary;
	public ref<Node> node;
}

public string formatMessage(MessageId messageId, substring[] args) {
	string format = messageId.message();
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
//				printf("messageId %s position = %d args.length=%d\n", string(messageId), position, args.length());
//				printf("args[%d]={%x,%d}\n", position, int(args[position].data), args[position].length);
				if (position < args.length()) {
					string inclusionString(args[position]);
//					printf("inclusionString=%s\n", inclusionString);
					s.append(inclusionString);
				} else {
					s.append('%');
					s.append(format[i]);
				}
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
