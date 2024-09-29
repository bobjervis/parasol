<h2>{@level 2 White Space}</h2>

<h3>{@level 3 Space Characters}</h3>

Any Unicode white space character, horizontal tab, form feed, newline or carriage return characters are collectively termed <i>white space characters</i>.
<p>
Any amount of white space can appear between two tokens, with a few exceptions described below.
<p>
In general, tokens must be separated by white space only to disambiguate otherwise indistinguishable tokens.
For example in the following:

{@code
	int i;
}

The white space between <span class=code>int</span> and <span class=code>i</span> is needed, 
because otherwise this would be the single token <span class=code>inti</span>.
The lack of white space between the 'i' and the semi-colon token does not alter the tokenization, and so white-space is optional there.
<p>
Other than at the beginning of a unit, white space that contains a newline character is a <i>possible statement break</i>.
A possible statement break will be interpreted as a semi-colon token if semi-colon elision is enabled and
the pair of tokens before and after the white space form an <i>implied statement boundary</i>.

<h3>{@level 3 Comments}</h3>

Text beginning with a <span class=code>//</span> sequence up to the end of the same line is a <i>single-line comment</i>.
All text on the line following the <span class=code>//</span> pair is ignored.
<p>
Text beginning with a <span class=code>/*</span> and ending with an <span class=code>*/</span>, possibly spanning multiple lines, 
is a <i>block comment</i> and all enclosed text is ignored, except for nested block comments within.
If a <span class=code>/*</span> sequence appears within a block comment, 
it is treated as a nested comment and must be followed by a corresponding <span class=code>*/</span> pair within the comment.
<p>
A block comment without a closing <span class=code>*/</span> pair within the same file is an error.

<h3>{@level 3 White Space Exceptions}</h3>

White space <i>must</i> appear adjacent to certain tokens in some contexts.
Note that this is contrary to how these tokens are treated in C++, Java or other languages.
The goal is to enable Parasol code to be parsed independently of semantic analysis.
<p>
The less-than (&lt;) and greater-than (&gt;) tokens may appear as binary comparison operators or 
may be used as angle-brackets enclosing the arguments of a template class.
In order for these tokens to be interpreted as operators, they must appear with white space immediately preceding them.
If no white space precedes these tokens, they are assumed to be angle brackets enclosing template parameters.
<p>
Unlike C++ or Java, for example, Parasol has no restrictions on declaration order, cannot determine 
whether a given identifier 
is a type name at parse time, and so cannot in all cases disambiguate between comparison operators and 
template expressions (in the absence of the implemented white-space rule).

<h3>{@level 3 Implied Statement Boundaries}</h3>

If semi-colon elision is enabled, possible statement breaks at implied statement boundaries will be interpreted as a semi-colon token.
<p>
If the token preceding or following a possible statement break is a semi-colon token, the possible statement break is ignored.
<p>
Otheriwse, an implied statement boundary is formed whenever the preceding token is one of the following:

<ul>
	<li><i>identifier</i>
	<li><b>--</b> (minus minus)
	<li><b>++</b> (plus plus)
	<li><b>}</b> (right curly brace)
	<li><b>)</b> (right parenthesis)
	<li><b>]</b> (right square bracket)
	<li><b>;</b> (semi-colon)
</ul>

and the possible statement break occurs at the end of a unit or the succeeding token is one of the following:

<ul>
	<li><i>identifier</i>
	<li><b>{</b> (left curly brace)
	<li><b>(</b> (left parenthesis)
	<li><b>[</b> (left square bracket)
	<li><b>--</b> (minus minus)
	<li><b>++</b> (plus plus)
	<li><b>;</b> (semi-colon)
</ul>

