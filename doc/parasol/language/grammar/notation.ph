<h2>{@level 2 Grammar Notation}</h2>

<h3>{@level 3 Productions}</h3>

The grammar of Parasol is defined using a context-free phrase-structure grammar 
described in blocks like this example:

{@grammar}
{@production example <i>phrase1 phrase2 etc</i> }
{@end-grammar}

Each production is written as above with the production name in italics (in this case <i>example</i>)
followed by a colon.
<p>
On the right is the sequence of symbols the production on the left can expand to.

<h3>{@level 3 Terminal And Non-Terminal Symbols}</h3>

Terminal symbols are written in bold text. 
If the terminal symbol is an operator or some other punctuation it
will be displayed as the literal characters of the symbol.
<p>
Non-terminal symbols are written as possibly-hyphenated words in italic.
<p>
For example:

{@grammar}
{@production example <i>phrase1</i> <b>keyword</b> <i>etc</i> <b>;</b> }
{@production | <i>phrase3</i> }
{@end-grammar}

In this case, The non-terminal <i>example</i> expands to the non-terminal <i>phrase1</i>,
the terminal symbol <b>keyword</b>, another non-terminal <i>etc</i> and it terminated with
the terminal semi-colon token (<b>;</b>).

<h3>{@level 3 Alternation}</h3>

If a given non-terminal symbol can be expanded to two or more separate
expansions, they are written, one per line, with each subsequent line wirtten with a 
vertical bar character at the beginning of each line.
<p>
For example:

{@grammar}
{@production example <i>phrase1 phrase2 etc</i> }
{@production | <i>phrase3</i> }
{@end-grammar}

In this case, the non-terminal <i>example</I> may expand to either the three phrases
<i>phrase1 phrase2 etc</i> or the one non-terminal <i>phrase3</i>.

<h3>{@level 3 Optional and Repetitive Phrases }</h3>

To simplify the grammar certain notation is used to express optional or
repeating phrases.
<p>
Optional symbols or sequences of symbols are enclosed in square braces.
<p>
A simple example:

{@grammar}
{@production example1 <i>phrase1</i> [ <b>something</b> ] }
{@end-grammar}

This production is equivalent to the following:

{@grammar}
{@production example1 <i>phrase1</i> }
{@production | <i>phrase1</i> <b>something</b> }
{@end-grammar}

Lastly, a repetitive set of phrases can be expressed by enclosing a squence of symbols
in parentheses or square brackets and follow that with an ellipsis. The group of symbols can
be repeated as many times as desired.
<p>
If the squence is enclosed in parentheses, the group must be repeated at least once.
If the sequence is in square brackets, the group may be omitted entirely.
<p>
For example:

{@grammar}
{@production example1 <i>phrase1</i> ( <i>etc</i> ) ... }
{@production example2 <i>phrase1</i> [ <b>as</b> <i>etc</i> ] ... }
{@end-grammar}

In the above, <i>example1</i> must exapnd to at least <i>phrase1 etc</i>, but may be
expanded to <i>phrase1 etc etc etc</i>.
<p>
The symbol <i>example2</i> can be expanded to just <i>phrase1</i>, or <i>phrase1</i> <b>as</b> <i>etc</i> or
<i>phrase1</i> <b>as</b> <i>etc</i> <b>as</b> <i>etc</i> and so on.



