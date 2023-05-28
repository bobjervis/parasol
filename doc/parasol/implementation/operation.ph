
<h2>{@level 0 OPERATION}</h2>

Parasol is compiled and run by entering shell commands.

<h3>pc</h3>

Use is:

{@code
    <b>pc</b> [ <i>options</i> ... ] <filename> [ <i>arguments</i> ... ]
}

<h4>Options:</h4>
<table>
<tr><td>-v</td><td></td><td>Enables verbose output.</td></tr>
<tr><td></td><td>--asm</td><td>Display disassembly of instructions and internal tables.</td></tr>
<tr><td>-c</td><td>--compile</td><td>Only compile the application, do not run it.</td></tr>
<tr><td></td><td>--context</td><td>Defines a Parasol context to use in the compile and
                      execution of the application. This overrides the value of
                      the {@code PARASOL_CONTEXT} environment variable.</td></tr>
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
						{@code CorruptHeapException}.
				</td></tr>
		</table>
		Default: {@code prod}
	</td></tr>
<tr><td>-?</td><td>--help</td><td>Displays a siplified version of this 
						documentataion.</td></tr>
<tr><td></td><td>--logImports</td><td>Log all import processing.</td></tr>
<tr><td>-p</td><td>--profile</td><td>Produce a profile report, wriitng the profile data to the
						path provided as this argument value.</td></tr>
<tr><td></td><td>--pxi</td><td>Writes compiled output to the given file. Does not execute
						the program.</td></tr>
<tr><td></td><td>--root</td><td>Designates a specific directory to treat as the <i>root</i>
						of the install tree. The default is the parent directory of the runtime 
						binary program.
					</td></tr>
<tr><td></td><td>--syms</td><td>Print the symbol table.</td></tr>
<tr><td></td><td>--target</td><td>Selects the target runtime for this execution.
						<p>
						Default: {@code X86_64_LNX}
					</td></tr>
</table>
<p>
The given filename is run as a Parasol program. Any command-line arguments
appearing after are passed to any main function in that file.

<h3>pbuild</h3>
<h3>pcontext</h3>
<h3>paradoc</h3>
