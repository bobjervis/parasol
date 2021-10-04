
<h2>SYMBOL TABLE</h2>

There are four major categroies of objects, each represented by a class hierarhy:
All of tehse objects are created by the compiler in the course of translating a Parasol program.
<ul>
	<li>Nodes. These are objects typically created by the parser.
	<li>Scopes. These objects are inferred from the nodes created by the parser.
	<li>Symbols. These objects are inferred from the nodes created by the parser and assigned to 
	scopes.
	<li>Types. These objects are inferred from the nodes created by the parser, in part by consulting
	information associated with symbols.
</ul>
The bulk of these objects are created in the course of compilation from Parasol source code in
some form or another.
Parasol programs, as well as the compiler itself, may also choose to create instances of these objects
without first parsing Parasol source code.
The objects can then be used to generate binary runtime objects or even compiled instructions.
It is therefore critical that there be a clear, documented model for creating these objects that will yield correct, functioning 
objects and code.
