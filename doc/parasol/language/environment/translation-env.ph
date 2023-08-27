
<h2>{@level 2 Translation Environment}</h2>
A Parasol program operates within a computing environment called its arena.
It is built as a collection of <i>units</i> injected over time into the arena.
A unit corresponds to a single distinguished sequence of text, either one source file or string value.
<p>
A Parasol arena need not be built all at once.
Sets of units can be pre-compiled into libraries and later loaded into an arena to create a complete,
running program.
<p>
Each unit contains definitions for objects, functions, types and constants.
Parasol source files can be compiled into library components called packagess, or directly into programs.
<p>
The meaning of a set of units loaded into an arena is independent of how they were
packaged.
All of the units of a library package will not necessarily be included in an arena if the arena
references the package.
Reorganizing, for example, a single package into two separate packages will not alter the meaning of 
the units in an arena, as long as the arena draws in both libraries when it is compiled and run.

