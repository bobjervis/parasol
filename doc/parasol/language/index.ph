<h1>{@level 0 Parasol Language Reference}</h1>

<ul class=sec-map>
	<li>{@topic ../implementation/index.ph}
	<li>{@topic environment/index.ph}
	<li>{@topic lex/index.ph}
	<li>{@topic grammar/index.ph}
	<li>{@topic semantics/index.ph}
</ul>

<p>
This reference is intended to provide a precise description of the Parasol language and its runtime environment.
An implementation, including a validation test suite, exists at <a href="https://github.com/bobjervis/parasol">Github</a>
which also serve as a reference for Parasol.
At present, neither this reference nor the above implementation are uniformly definitive. 
<p>
Where this reference specifies a behavior that contradicts the behavior of the implementation, the two are in conflict and
neither behavior is definitive.
The conflict will have to be reconciled through a change to one or both.
Where this reference indicates that a behavior is not completely specified, 
the behavior of the implementation does not prescribe how a conforming implementation of Parasol should behave.
<p>
The Parasol language is based on the C/C++/Java/... family of languages.
The syntax choices are probably closer to Java, given that the designers of that language did a good job with features like 
enum's as classes, variable argument lists, no header files, etc.
However, Parasol differs from Java in one enormous respect: Parasol does not support garbage collection.
<p>
Another important aspect of the design of Parasol that does not leap out immediately is that Parasol is designed to compile and run as a single step.
In this respect, Parasol is more like scripting languages like Javascript, even though it is strongly typed.
In fact, the choice of 'var' as a dynamically typed 'variant' type mimics Javascript's declaration syntax for variables.
While compiling to a binary image is possible with Parasol (for maximum launch speed with large applications) 
the eventual goal is to devise techniques to allow run-time 'eval' as a feature.

