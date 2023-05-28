
<h1>The Parasol Language</h1>


<ul class=sec-map>
	<li>{@topic reflection/index.ph}
	<li>{@topic language/index.ph}
	<li>{@paradoc runtime Parasol Runtime}
	<li>{@topic implementation/index.ph}
</ul>

<h2>Overview</h2>

The Parasol Language was originally created by Bob Jervis in 1990.
It was a research language designed to create distributed and parallel applications.
The ALYS operating system was written in Parasol and was a full 32-bit multi-tasking kernel.
It made extensive use of messages to communicate between services, exploiting Parasol's RPC feature. 
<p>
You can read an old article about this version of Parasol at <a href="http://www.drdobbs.com/tools/the-parasol-programming-language/184409086">Dr. Dobb's</a>.
<p>
Rapidly changing technology in the mid 1990's stranded ALYS and work on Parasol was suspended.
<p>
In December, 2010, Bob resumed work on a parallel programming language and re-designed Parasol from the ground up.
At the end of May, 2015 he completed work on a self-hosted 64-bit native compiler running on Windows 7.
This was deployed as version 0.1, essentially an early alpha copy of the project.
The language had almost no parallel programming features in this release.
The goal of the release was to create a performant self-hosted compiler so that features could be directly developed in Parasol itself.
<p>
Since that release a number of new features have been added. For example, treatment of extended Unicode characters has been refined to provide for appropriate treatment of non-ASCII letters, digits and white-space. In the original release, all non-ASCII characters were treated as identifier characters, which is really not in the spirit of Unicode. The current implementation is much more careful.
<p>
Some of vector arithmetic has been implemented and at least the parsing of a number of smaller features have been implemented. 
It isn't exactly versatile, since I am in a number of cases only partially implementing a feature such as vector arithmetic.
The intention is to have substantially all of the features currently described under the syntax implemented as part of the next 'release' of the language.
Until then, each committed build has passed the full Parasol test suite.
<p>
A Linux port has been completed so Parasol programs can be written for Linux.
Since then, the Windows version has not been maintained and should not be considered operational.
<p>
Recent development has focused on dccumenting and filling out the runtime. 
String classes are far more thoroughly implemented and most memory leaks have been plugged. 
The bindings for Linux are more complete, including the entire Linux C math library.
<p>
The <span class=code>paradoc</span> application has been written to generate a set of HTML pages (including this one) from the inline documentation of the API's.
<p>
Interested developers are invited to participate.
</ul>
	<li><a href="https://github.com/bobjervis/parasol/wiki/Project-Roadmap">Project Roadmap</a>
	<li><a href="https://github.com/bobjervis/parasol/wiki/The-Linux-64-Bit-Implementation">The Linux 64-Bit Implementation</a>
	<li><a href="https://github.com/bobjervis/parasol/wiki/The-Windows-64-Bit-Implementation">The Windows 64-Bit Implementation</a>
	<li><a href="https://github.com/bobjervis/parasol/wiki/Installation-and-Setup>Installation and Setup</a>
	<li><a href="https://github.com/bobjervis/parasol/wiki/Building-and-Testing">Building and Testing</a>
	<li><a href="https://github.com/bobjervis/parasol/wiki/Project-Diary">Project Diary</a>
</ul>


