
<h2>{@level 0 SYMBOL TABLE}</h2>

There are four major categroies of objects, each represented by a class hierarhy:
All of these objects are created by the compiler in the course of translating a Parasol program.
<ul>
	<li>Nodes. These are objects typically created by the parser. They describe the syntactic 
	elements and structure of a span of Parasol source text. 
	The compiler also generates numerous Node objects in the course of generating code.
	Rather than directly craft the instruction sequences in every case, the compiler will
	sometimes transform the tree of nodes produced by the parser or generate from scratch
	more complex code sequences as nodes with no text source. 
	<li>Scopes. These objects are inferred from the nodes created by the parser.
	Some correspond to specific syntactic elements, such as almost all curly-brace enclosed blocks.
	Others have no corresponding node in the parse tree.
	For example, in {@doc-link RPC RPC's}, certain support functions and even whole classes are
	generated to implement the runtime feature.
	<li>Symbols. These objects are inferred from the nodes created by the parser and assigned to 
	scopes.
	There are two main categories of symbols, plain and overloaded.
	A plain symbol's name is defined exactly once in it's scope.
	Such a symbol will typically be used to represent some specific object.
	Overloaded symbols may appear with the same name any number of times. These are either functions or templates.
	Their definitions always appear in context with a set of parameters that must be unique across
	the entire scope in which they appear.
	Within a single scope, all overloaded symbols must be either functions or templates, not both.
	Also, a plain symbol cannot have the same name as a set of overloaded symbols in the same scope.
	<li>Types. These objects are inferred from the nodes created by the parser, in part by consulting
	information associated with symbols.
	In principle, types are abstract entities. 
	In particular, once created by the compiler, at runtime a type is immutable.
	The compiler is free to create multiple copies of a type or retain just one.
	Types are instead compared using the Parasol comparison operators.
	Types are partially ordered, so the result of a comparison can be that two types
	are equal, one is less than or greater than the other and, finally, two types can be unrelated.
	A derived class is always less than any of it's base classes.
	Two enum types are unrelated, they are never equal, less than or greater than each other.
</ul>
The bulk of these objects are created in the course of compilation from Parasol source code in
some form or another.
Parasol programs, as well as the compiler itself, may also choose to create instances of these objects
without first parsing Parasol source code.
The objects can then be used to generate binary runtime objects or even compiled instructions.
It is therefore critical that there be a clear, documented model for creating these objects that will yield correct, functioning 
objects and code.
