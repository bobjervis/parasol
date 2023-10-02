
<h2>{@level 2 Operation}</h2>

Parasol is compiled and run by entering shell commands.

<h3>{@level 3 pc}</h3>

The Parasol compiler.

<h4>Use is:</h4>

{@code
    <b>pc</b> [ <i>options</i> ... ] <i>filename</i> [ <i>arguments</i> ... ]
}

<h4>Options:</h4>
<table>
<tr><td>-v</td><td></td><td>Enables verbose output.</td></tr>
<tr><td></td><td>--asm</td><td>Display disassembly of instructions and internal tables.</td></tr>
<tr><td>-c</td><td>--compile</td><td>Only compile the application, do not run it.</td></tr>
<tr><td></td><td>--context</td><td>Defines a Parasol context to use in the compile and
                      execution of the application. This overrides the value of
                      the <span class=code>PARASOL_CONTEXT</span> environment variable.</td></tr>
<tr><td></td><td>--cover</td><td>Produce a code coverage report, accumulating the data in a
                      file at the path provided in the argument value.</td></tr>
<tr><td></td><td>--heap</td><td>Select one of the following heaps:
		<table>
			<tr><th>Value</th><th>Description</th></tr>
			<tr><td>{@code prod}</td><td>The production heap. Allocation is
						currently implemented using the underlying C heap.
				</td></tr>
			<tr><td>{@code leaks}</td><td>The leaks heap option writes a leaks 
						report to leaks.txt when the process terminates normally.
				</td></tr>
			<tr><td>{@code guard}</td><td>The guarded heap writes sentinel bytes 
						before and after each allocated region of memory and checks 
						their value when the block is deleted, or when the program 
						terminates normally. If the guarded heap detects that these 
						guard areas have been modified, it throws a 
						<span class=code>CorruptHeapException</span>.
				</td></tr>
		</table>
		Default: <span class=code>prod</span>
	</td></tr>
<tr><td>-?</td><td>--help</td><td>Displays a simplified version of this 
						documentataion.</td></tr>
<tr><td></td><td><nobr>--logImports<nobr></td><td>Log all import processing.</td></tr>
<tr><td>-p</td><td>--profile</td><td>Produce a profile report, writing the profile data to the
						path provided as this argument value.</td></tr>
<tr><td></td><td>--pxi</td><td>Writes compiled output to the given file. Does not execute
						the program.</td></tr>
<tr><td></td><td>--root</td><td>Designates a specific directory to treat as the <i>root</i>
						of the install tree. The default is the parent directory of the runtime 
						binary program.
					</td></tr>
<tr><td></td><td>--syms</td><td>Print the symbol table.</td></tr>
<tr><td></td><td>--target</td><td>Selects the target runtime for this execution.
						<br>
						Default: <span class=code>X86_64_LNX</span>
					</td></tr>
<tr><td></td><td>--version</td><td>Displays the compiler version.</td></tr>
</table>
<p>
The given filename is run as a Parasol program. Any command-line arguments
appearing after are passed to any main function in that file.

<h3>{@level 3 pbuild}</h3>

The Parasol build utility.

<h4>Use is:</h4>

{@code
    <b>pbuild</b> [ <i>options</i> ... ] [ <i>products</i> ... ]
}

<h4>Options:</h4>

<table>
<tr><td>-v</td><td></td><td>Enables verbose output.</td></tr>
<tr><td></td><td>--asm</td><td>Display disassembly of bytecodes.</td></tr>
<tr><td></td><td>--cpu</td><td>
                 	Selects the target processor for this execution.
					<br>
                    Default: <span class=code>x86-64</span>
</td></tr>
<tr><td>-d</td><td>--dir</td><td>
					Designates the root directory for the build source tree.
					<br>
                    Default: <span class=code>.</span>
</td></tr>
<tr><td>-f</td><td>--file</td><td>
        Designates the path for the build file. If this option is
                    provided, only this one build script will be loaded and
                    executed.
					<br>
					Default: Apply the search algorithm described below.
</td></tr>
<tr><td>-?</td><td>--help</td><td>Displays a simplified form of this help.</td></tr>
<tr><td></td><td><nobr>--logImports</nobr></td><td>Log all import processing.</td></tr>
<tr><td>-m</td><td>--manifest</td><td>
        Selects a manifest file that contains auxiliary information to
					guide the build process. This file will typically contain
					information that constrains what package versions can be built
					in this run and which of the pacckages being compiled will be
					installed.
					<br>
                      Default: <span class=code>linux</span>
</td></tr>
<tr><td></td><td>--os</td><td>
                  Selects the target operating system for this execution.
					<br>
                      Default: <span class=code>linux</span>
</td></tr>
<tr><td>-o</td><td>--out</td><td>
         Designates the output directory where all build products and intermediate files will be
                      stored.
					<br>
					  Default: <span class=code>build</span>
</td></tr>
<tr><td>-r</td><td>--report</td><td>Reports which file caused a given product to be rebuilt.</td></tr>
<tr><td></td><td>--syms</td><td>Print the symbol table.</td></tr>
<tr><td></td><td>--tests</td><td>Run the indicated test suite(s) after successful
                      completion of the build.</td></tr>
<tr><td>-t</td><td>--threads</td><td>
     Declares the number of threads to be used in the build.
					<br>
                      Default: number of cpus on machine.
</td></tr>
<tr><td></td><td>--trace</td><td>Trace the execution of each test.</td></tr>
<tr><td></td><td>--ui</td><td>
                  Display error messages with mark up suitable for a UI.
<p>
                      The argument string is the filename prefix that identifies
                      files being compiled (versus reference libraries not in
                      the editor) ?
</td></tr>
</table>
<p>
This program builds a Parasol application according to the rules in build files.
<p>
With no file option specified, the builder will search the current directory and
then recursively in sub-directories until at least one build file named
<span class=code>make.pbld</span> is found. At each sub-directory, if a 
<span class=code>make.pbld</span> file is found
there, the search stops and that build file is included in the build and no
directories underneath that one are searched.If multiple build files are found
in separate branches of the directory hierarchy, all will be included in the
build.
<p>
Thus, by arranging a collection of related projects under a single root, one can
orchestrate a build across all included build files. While making the builder do
more work, if there are changes in multiple sub-projects, or dependencies across
projects, this build will properly handle them.
<p>
If no products are given as arguments, then all products enabled in the build
scripts will be built. If one or more products are given as arguments, then only
those products plus any products the named ones are dependent on will be built.

<h4>{@level 4 Build Scripts}</h4>

The text file that the Parasol <span class=code>pbuild</span> application uses to
control a build is called a <i>build script</i> and is written using the {@doc-link ets-script ETS script syntax}.
The following describes the tags that are supported by the pbuild tool.
<p>

For details about the tag set defined for <span class=code>pbuild</span> is described {@doc-link make-pbld here}.

<h3>{@level 3 pcontext}</h3>

<h4>Use is:</h4>

{@code
    <b>pcontext</b> [ <i>options</i> ... ] <i>sub-command</i> [ <i> arguments </i> ]
}


<h4>Options:</h4>

<table>
<tr><td>-?</td><td>--help</td><td>Displays this help.</td><tr>
</table>

This command manages the user's Parasol language.contexts. It
performs many different functions.
<p>

<h4>Sub-commands:</h4>

{@code
      <b>pcontext create</b> <i>context-name</i> ( <i>path</i> | <i>url</i> )
}
<div class=sub-command>
	
	<p>
      Create or define a new context. If no path or url are given, then a new
      context database is created. If a path to an existing, readable directory
      is supplied, it must be a context database, or a copy of one. The named
      directory will be used to hold any newly installed packages or other
      updated information. If a path to a directory that can be created is
      given, but does not exist, the directory is created.
</div>

{@code
      <b>pcontext install</b> [ <i>options</i> ... ] <i>directory</i>
}
<div class=sub-command>
	
	<h4>Options:</h4>

	<table>
	<tr><td>-c</td><td>--context</td><td>If present, install the package to this context.</td><tr>
	</table>

      Install a package into a context. The named directory must contain a
      Parasol package.
</div>

{@code
      <b>pcontext ls</b> [ <i>options</i> ... ]
}
<div class=sub-command>
	
	<p>
      List all contexts.
</div>
	
	<h4>Options:</h4>

	<table>
	<tr><td>-p</td><td>--packages</td><td>If present, list the packages present in each context.</td><tr>
	<tr><td>-v</td><td>--versions</td><td>If present, list the packages and their versions present in each context.</td><tr>
	</table>

<h3>{@level 3 paradoc}</h3>

<h4>Use is:</h4>

{@code
    <b>paradoc</b> [ <i>options</i> ... ] <i>output-directory package-name</i> ...
}

<h4>Options:</h4>

<table>
<tr><td>-v</td><td></td><td>Enables verbose output.</td></tr>
<tr><td>-c</td><td>--content</td><td>
     Designates that the output directory named in the command
                      line is to be constructed by copying recursively the
                      contents of the directory named by this option. Each file
                      with a .ph extension is processed by paradoc and replaced
                      by a file with the same name, but with a .html extension.
</td></tr>
<tr><td>-?</td><td>--help</td><td>Displays a simplified version of this help.</td></tr>
<tr><td></td><td><nobr>--logImports</nobr></td><td>Log all import processing</td></tr>
<tr><td></td><td>--syms</td><td>Print the symbol table.</td></tr>
<tr><td>-t</td><td>--template</td><td>
    Designates a directory to treat as the source for a set of
                      template files. These templates fill in details of the
                      generated HTML and can be customized without modifying the
                      program code.</td></tr>
</table>

The given input directories are analyzed as a set of Parasol libraries.
<p>
Refer to the Parasol language reference manual for details on permitted syntax.
<p>
The inline documentation (paradoc) in the namespaces referenced by the sources
in the given input directories are written as HTML pages to the output
directory.


