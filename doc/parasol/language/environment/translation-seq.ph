
<h2>{@level 2 Translation Sequence}</h2>
Translation of a Parasol program is described below as if the entire program were built from scratch.
A development environment may in fact maintain internal state information to limit 
the amount of compilation that in fact does take place after changes are made to an already built project.
<p>
A program or library is built in the following steps:
<ol>
	<li>The units are parsed.
	The following steps are performed for each unit.
	As units are added in step A.3 these steps are repeated.
	<ol>
		<li>The source text for a unit is tokenized.
		Comments are replaced by white space.
		<li>Declarations are parsed.
		Namespace and import statements and object, function and type definitions are processed into a parse tree.
		<li>Namespace and import statements are processed.
		Any unit named that is not yet part of the arena is located and added to it (recursively 
		repeating steps A.1 through A.3).
	</ol>
	<li>Any reference to an identifier (other than as the right-hand operand
	of a dot operator or as the name of a function in a function call) is associated with its appropriate definition.
	<li>The actual types appearing in declarations are determined, the types
	of all operators in expressions are determined, and integral constant expressions are evaluated.
	Identifiers appearing as right-hand operands of dot operators are associated with their definitions.
	Function names in member function calls are associated with their definitions.
	<li>The initial values of static objects and the object code for functions are generated.
	<li>The executable image of a program or the object code of a library is created.
</ol>

