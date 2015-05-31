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
#ifndef PARASOL_TOKEN_H
#define PARASOL_TOKEN_H

namespace parasol {

enum Token {
	T_ERROR,
	T_END_OF_STREAM,

	// Each of these tokens has an associated 'value'

	T_IDENTIFIER,
	T_INTEGER,
	T_FLOATING_POINT,
	T_CHARACTER,
	T_STRING,
	T_ANNOTATION,

	// Each of these are paired tokens:

	T_LEFT_PARENTHESIS,
	T_RIGHT_PARENTHESIS,
	T_LEFT_CURLY,
	T_RIGHT_CURLY,
	T_LEFT_SQUARE,
	T_RIGHT_SQUARE,
	T_LEFT_ANGLE,
	T_RIGHT_ANGLE,
	T_SP_LA,				// space-<
	T_SP_RA,				// space->

	// These are single character tokens:

	T_SEMI_COLON,
	T_COLON,
	T_DOT,
	T_COMMA,
	T_SLASH,
	T_PERCENT,
	T_ASTERISK,
	T_PLUS,
	T_DASH,
	T_AMPERSAND,
	T_CARET,
	T_VERTICAL_BAR,
	T_EXCLAMATION,
	T_EQUALS,
	T_QUESTION_MARK,
	T_TILDE,

	// These are multi-character tokens:

	T_ELLIPSIS,
	T_DOT_DOT,
	T_SLASH_EQ,
	T_PERCENT_EQ,
	T_ASTERISK_EQ,
	T_PLUS_EQ,
	T_DASH_EQ,
	T_AMPERSAND_EQ,
	T_CARET_EQ,
	T_VERTICAL_BAR_EQ,
	T_EQ_EQ,						// ==
	T_EQ_EQ_EQ,						// ===
	T_LA_EQ,						// <=
	T_RA_EQ,						// >=
	T_LA_RA,						// <>
	T_LA_RA_EQ,						// <>=
	T_EXCLAMATION_EQ,				// !=
	T_EX_EQ_EQ,						// !==
	T_EX_LA,						// !<
	T_EX_RA,						// !>
	T_EX_LA_EQ,						// !<=
	T_EX_RA_EQ,						// !>=
	T_EX_LA_RA,						// !<>
	T_EX_LA_RA_EQ,					// !<>=
	T_LA_LA,						// <<
	T_RA_RA,						// >>
	T_RA_RA_RA,						// >>>
	T_LA_LA_EQ,						// <<=
	T_RA_RA_EQ,						// >>=
	T_RA_RA_RA_EQ,					// >>>=
	T_AMP_AMP,						// &&
	T_VBAR_VBAR,					// ||
	T_PLUS_PLUS,					// ++
	T_DASH_DASH,					// --

	// Keywords

	T_ABSTRACT,
	T_BREAK,
	T_BYTES,
	T_CASE,
	T_CONTINUE,
	T_CLASS,
	T_DEFAULT,
	T_DELETE,
	T_DO,
	T_ELSE,
	T_ENUM,
	T_EXTENDS,
	T_FALSE,
	T_FINAL,
	T_FOR,
	T_FUNCTION,
	T_IF,
	T_IMPLEMENTS,
	T_IMPORT,
	T_NAMESPACE,
	T_NEW,
	T_NULL,
	T_PRIVATE,
	T_PROTECTED,
	T_PUBLIC,
	T_RETURN,
	T_STATIC,
	T_SUPER,
	T_SWITCH,
	T_THIS,
	T_TRUE,
	T_WHILE,

	// Pseudo-tokens not actually returned by a Scanner

	T_EMPTY,
	T_MAX_TOKEN = T_EMPTY
};

class Tokens {
public:
	Tokens();

	static const char* name[];
};

extern Tokens tokens;
}

#endif // PARASOL_TOKEN_H
