<h2>{@level 2 Statements}</h2>

{@grammar}
{@production statement [ <i>annotation_list</i> ] <i>base_statement</i>}
{@production base_statement <i>empty_statement</i>}
{@production | <i>expression_statement</i>} 
{@production | <i>block</i>}
{@production | <i>declaration</i>}
{@production | <i>control_flow_statement</i>}
{@production | <i>import</i>}
{@production | <i>namespace_statement</i>}
{@end-grammar}

The statements of Parasol correspond closely to those of C++, Java and related languages.

<h3>{@level 3 Annotations}</h3>

{@grammar}
{@production annotation_list ( <b>@</b> <i>identifier</i> [ <b>(</b> <i>expression</i> <b>)</b> ] ) ...}
{@end-grammar}

Annotations may be placed at the beginning of some statements.
<p>
Note that the full role of annotations is not very extensively thought out.
At present, the notion is that you can annotate statements that define an identifier and the annotations apply to the defined object.
<p>
Whether annotations will be extended to be allowed on non-definition statements is an open question.

<h3>{@level 3 Empty Statement}</h3>

{@grammar}
{@production empty_statement <b>;</b>}  
{@end-grammar}

A semi-colon by itself is a statement.
The statement has no effect.

<h3>{@level 3 Expression Statements}</h3>

{@grammar}
{@production expression_statement <i>expression</i> <b>;</b>}  
{@end-grammar}

An expression followed by a semi-colon is a statement.
When the statement is executed, the expression is evaluated.

<h3>{@level 3 Blocks}</h3>

{@grammar}
{@production block [ <i>lock_prefix</i> ] <b>{</b> [ <i>statement</i> ] ... <b>&rbrace;</b>}
{@production lock_prefix <b>lock (</b> <i>expression</i> <b>)</b>}
{@end-grammar}

A <i>block</i> is a sequence of zero or more statements enclosed in curly braces.
The statements of a block are executed in sequence from first to last.
<p>
A block also always defines a scope.
All identifiers defined within a block are visible throughout the block.
<p>
A lock prefix on a block specifies an lvalue expression of a monitor object.
If present, the block is performed while holding the specified monitor object.
If multiple threads attempt to execute locked blocks that designate the same monitor object,
only one thread will enter one of the locked blocks at a time.
