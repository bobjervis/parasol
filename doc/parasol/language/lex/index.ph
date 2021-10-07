<h1>{@level 1 LEXICAL CONVENTIONS}</h1>

<ul>
	<li>{@topic identifiers.ph}
<p>
Parasol programs consist of a set of one or more text source files, one of which is designated as the 'main file'.
Each source file consists of a stream of <i>tokens</i> identified by a single forward pass over the source text possibly separated by runs of white space.
With a handful of exceptions, white space has no effect on tokenization other than to separate otherwise indistinguishable tokens.
<p>
Text may appear in any encoding, but the following documentation assumes some form of Unicode.
If your compiler does not support Unicode, it must describe how its supported character set is mapped to Unicode.
Parasol assigns special meaning to most of the characters in the ASCII (\u00 - \u7f) range.
Unicode characters that lie outside that range and which are classified as letters or decimal digits may be used in identifiers and numeric constants.
Unicode white space characters may be used as white space.
The exact set of characters which are so classified does vary from revision to revision of Unicode.
Currently the Parasol compiler is targeting the Unicode 8.0 version of the specification.
<p>
The goal is to provide non-English speaking programmers with facilities that make their own source code more readable to them.
Within the constraints of the character set that it supports, a Parasol compiler must allow combinations that would be confusing to a human reader (such as mixing ASCII digits with Thai digits in the same numeric constant).
Digits from any valid code point range can be used in Parasol decimal fractions, even though the decimal point (.), exponent (e or E) and exponent sign (+ or -) are restricted to the ASCII characters.
<p>
## Annotations

An unescaped identifier preceded by an at-sign (@) is an annotation.

For example:

`@Constant`

## Special Tokens

These tokens are composed of one or more printable non-alphanumeric characters (the name of the token follows each character sequence):

Token | Description
---- | ----
& | Ampersand - either Address-of or Bitwise And
&& | Logical And
&= | And assignment
\| | Bitwise inclusive or
\|= | Inclusive or assignment
^ | Bitwise exclusive or
^= | Exclusive or assignment
 \+ | Plus
\+= | Plus assignment
\+\+ | Increment
\- | Minus
\-= | Minus assignment
\-\- | Decrement
/ | Division
/= | Divide assignment
% | Remainder
%= | Remainder assignment
\* | Asterisk - either Indirection or multiplication
\*= | Multiply assignment
, | Comma
; | Semi-colon
: | Colon
~ | Bit complement
. | Dot
.. | Range
... | Ellipsis
== | Equal
=== | Identical
< | Less than
<= | Less than or equal
<> | Less than or greater than
<>= | Less than, greater than or equal (not a NaN)
\> | Greater than
\>= | Greater than or equal
! | Logical Not
!= | Not equal
!== | Not identical
!< | Not less than
!<= | Not less than or equal
!<> | Not less than or greater than
!<>= | Not less than, greater than or equal (is a NaN)
!> | Not greater than
!>= | Not greater than or equal
( | Left parenthesis
) | Right parenthesis
[ | Left square bracket
] | Right square bracket
{ | Left curly brace
} | Right curly brace

## Numbers

Numbers are sequences of one or more digits and other characters that comprise a single numeric value.
The type of a number depends on the form, value and context of the number itself.
Integer constants have some integral type and floating point numbers have some floating type.
Integer constants have the smallest signed integral type that can represent the constant's value.
Floating point numbers have the smallest floating type that can represent the constant's magnitude and will have a representation in the native numeric format closest in value to the exact value of the constant.
A floating point number with a type specifier (letter f) has float type and must be representable as a float.

### Decimal Integers

A sequence of one or more decimal digits beginning with a non-zero digits is a _decimal integer_.
The value of the constant is the decimal value of the digits.
Any extended Unicode decimal digit character is allowed and is interpreted according to the value assigned it in the Unicode version 8.0 specification.

### Hexadecimal Integers

A sequence of one or more hexadecimal digits (0-9, a-f or A-F) preceded by a 0x or 0X is a _hexadecimal integer_.
The value of the constant is the value of the digits following the 0x in the hexadecimal number system.
While the letters of a hexadecimal digit string are constrained to the ASCII range, digit characters can be any Unicode version 8.0 decimal digit and is interpreted according to the value assigned it in the specification.

### Octal Integers

A sequence of one or more octal digits (0-7) beginning with a zero digit is an _octal integer_.
The value of the constant is the value of the digits in octal number system.
Any extended Unicode decimal digit character whose value is between 0 and 7, inclusive, is allowed and is interpreted according to the value assigned it in the Unicode version 8.0 specification.


### Floating Point Numbers

A sequence of two or more decimal digits with a period (decimal point) contained between two of the digits followed by an optional exponent and/or an optional type specifier is a _floating point number_.
An exponent is the letter **e** or **E** followed by an optional plus (+) or minus (-) sign and one or more decimal digits.
A type specifier is the letter **f** or **F**.
Any extended Unicode decimal digit character is allowed and is interpreted according to the value assigned it in the Unicode version 8.0 specification.

## String Literals

A sequence of characters enclosed in quotation marks is a string literal.
Unescaped newline characters may not appear within a string literal.

## Character Literals

A sequence of characters enclosed in apostrophes is a character literal.
Unescaped newline characters may not appear within a character literal.

The text within a character literal may only represent a single character.
Thus the text can be a single character itself, or a single escape sequence that represents a character.

## Escape Sequences

Within string literals, character literals or escaped identifiers, the backslash character (\\) may be used to initiate an _escape sequence_.
Each escape sequence represents a single character.
Two escape sequences that produce the same Unicode code point are equivalent.

The following are the defined two-character escape sequences (and their equivalent ASCII character value):
* \\\\ Backslash
* \a Audible Bell
* \b Backspace
* \f Form Feed
* \n Newline
* \r Carriage Return
* \t Horizontal Tab
* \v Vertical Tab
* \\" Quotation Mark
* \\' Apostrophe
* \\` Grave Accent

Longer escape sequences begin with the following pair:
* \u _or_
* \U Unicode code point escape. The initial characters are followed by one or more hexadecimal digits. The value of the hexadecimal number must be a valid Unicode code point.
* \x _or_
* \X Hexadecimal escape. The initial characters are followed by one or more hexadecimal digits. The value of the hexadecimal number must be between 0 and 255 decimal.
* \0 _or_
* \1 _or_
* \2 _or_
* \3 _or_
* \4 _or_
* \5 _or_
* \6 _or_
* \7 Octal escape. The initial characters are followed by zero or more octal digits. The value of the octal number must be between 0 and 255 decimal.

A backslash character followed by a newline itself is a special escape sequence that represents no character at all.
Instead, it may appear within a literal to allow the literal to span two or more lines of text.

All other characters following a backslash are invalid escape sequences.

Any token containing an invalid escape sequence or a sequence whose value is out of range is an invalid token.

## Comments

Text beginning with a // sequence up to the end of the same line is a _single-line comment_.
All text on the line following the // pair is ignored.

Text beginning with a /* and ending with an \*/, possibly spanning multiple lines, is a _block comment_ and all enclosed text is ignored, except for nested block comments within.
If a /* sequence appears within a block comment, it is treated as a nested comment and must be followed by a corresponding \*/ pair within the comment.

A block comment without a closing \*/ pair within the same file is an error.

## White Space

Any Unicode white space character, horizontal tab, form feed, newline or carriage return characters are collectively termed _white space_.

Any amount of white space can appear between two tokens, with a few exceptions described below.

In general, tokens must be separated by white space only to disambiguate otherwise indistinguishable tokens.
For example in the following:

`int i;`

The white space between 'int' and 'i' is needed, because otherwise this would be the single token 'inti'.
The lack of white space between the 'i' and the semi-colon token does not alter the tokenization, and so is optional.

### White Space Exceptions

White space _must_ appear adjacent to certain tokens in some contexts.
Note that this is contrary to how these tokens are treated in C++, Java or other languages.
The goal is to enable Parasol code to be parsed independently of semantic analysis.

The less-than (<) and greater-than (>) tokens may appear as binary comparison operators or may be used as angle-brackets enclosing the arguments of a template class.
In order for these tokens to be interpreted as operators, they must appear with white space immediately preceding them.
If no white space precedes these tokens, they are assumed to be angle brackets enclosing template parameters.

Unlike C++ or Java, for example, Parasol has no restrictions on declaration order, cannot determine whether a given identifier is a type name at parse time, and so cannot in all cases disambiguate between comparison operators and template expressions.

The increment (++) or decrement (\-\-) operators may appear as either prefix or suffix operators.
In contexts where two expressions may appear adjacent, increment or decrement operators must be preceded by white space to be treated as prefix operators for the second expression.
If no white space appears before the operators and they could be suffix operators, they will be treated that way even if the resulting parsed expressions have some semantic error.

Even though increment and decrement are not currently supported there, Parasol defines a declaration as a type-valued expression followed by a set of declarators with no intervening token.
So, formally speaking white space could alter the parsing choice in a declaration, but since the increment and decrement operators cannot appear in a type-valued expression currently, this is a somewhat moot restriction.
However, it is still open whether Parasol will use the APL vector-value syntax of a simple sequence of expressions or whether it will use the C++ and Java conventions of using commas to separate the individual elements of a vector.
Also, if Parasol is extended to support run-time dynamic typing (so that the type expression in a declaration does not have to be a compile-time constant), then there may be some obscure reason to include increment or decrement operators in the type expression.

