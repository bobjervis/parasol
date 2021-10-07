<h2>{@level 2 CHARACTER SETS}</h2>

Two sets of characters and their associated collating sequences shall be defined:
the set in which source files are written, and the target character set interpreted in the execution environment.
The values of the members of the target character set are implementation-defined.
<p>
In a character constant or string literal, members of the execution character set shall be
represented by corresponding members of the source character set or by escape sequences consisting of the backslash \ followed by one or more characters. 
<p>
In the following descriptions, the Unicode character set refers to the Unicode, Version 8 Standard.
An alternate character set can be used by a conforming implementation to encode equivalent character
values provided that such an implementation defines the equivalencies. 
<p>
Both the source and execution character sets shall have at least the following members: the 26 upper-case letters of the English alphabet
<p>
{@code
	A	B	C	D	E	F	G	H	I	J	K
	L	M	N	O	P	Q	R	S	T	U	V
	W	X	Y	Z
}
<p>
the 26 lower-case letters of the English alphabet
<p>
{@code
 	a	b	c	d	e	f	g	h	i	j	k
	l	m	n	o	p	q	r	s	t	u	v
	w	x	y	z
}
the 10 decimal digits
<p>
{@code
 	0	1	2	3	4	5	6	7	8	9
}
<p>
the following 30 graphic characters
<p>
{@code
 	!	"	#	$	%	&amp;	'	(	)	*	+
	,	-	.	/	:	;	&lt;	=	&gt;	?	[
	\	]	^	_	{	|	&rbrace;	~
}
<p>
the space character, and control characters representing horizontal tab, vertical tab and form-feed.  
<p>
In source files, there shall be some way of indicating the end of each line of text, which is 
discussed here as if it were a single new-line character.
<p>
In both the source and execution base character sets, the value of each character after 0 in
the above list of decimal digits shall be one greater than the value of the previous.
In numeric constants, the decimal value of decimal digits is that specified in the Unicode Character Database.
<p>
In addition to the above characters, the source character set shall have
<ul>
	<li>any characters of the Unicode character set with a General Category of Letter (L, Lc, Lu, Ll, Lt, Lm, Lo);
	<li>any characters of the Unicode character set with a General Category of Decimal_Number (Nd);
	<li>any characters of the Unicode character set with a General Category of White Space (Zs);
</ul>
<p>
If any other characters are encountered in a source file (except in a character constant, a string literal, or a comment), the behavior is undefined.
<p>
In the execution character set, there shall be control characters representing alert, backspace, carriage return, and new-line.
