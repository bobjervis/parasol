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

{@anchor exec-stmt}<i>Executable</i> statements are statements that produce code that carries out computations 
and possibly modifies the state of the running program.

The following are executable statements:

<ul>
    <li><i>expression_statement</i>
	<li><i>control_flow_statement</i>
</ul>

The following are never executable:

<ul>
    <li><i>empty_statement</i>
	<li><i>import</i>
	<li><i>namespace_statement</i>
</ul>

A <i>block</i> is executable if it contains any executable statements.

<h3>{@level 3 Annotations}</h3>
{@anchor Annotated}

{@grammar}
{@production annotation_list ( <b>@</b> <i>identifier</i> [ <b>(</b> <i>expression</i> <b>)</b> ] ) ...}
{@end-grammar}


Annotations may be placed at the beginning of any statement.
<p>
The meaning of annotations are unspecified and any environment that implements one or more annotations
shall accept any annotations present in a program, even if they do not conform to annotations implemented
in that environment.

Refer to the documentation for the {@doc-link ref-annotations annotations} defined by the reference
implementation for more details.

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
