<h2>{@level 2 ETS Scripts}</h2>

{@anchor ets-script}
ETS (for Europa Test Script) was a markup syntax originally developed for writing unit test scripts for a C++
application many years ago.
It was intended to be a little more terse than XML and HTML, but with similar capabilities.
The syntax choices were intended to seem familiar to programmers who were familiar with C, Java or similar
languages.
<p>
The parser and parsed objects were converted to Parasol to facilitate creation of test scripts for the Parasol
runtime and subsequently used again for Parasol build scripts.
<p>
Like HTML, ETS tags can be interspersed with plain text. 
Non-tag text that appears outside of any object elements
are allowed and generally will be treated by the Parasol test and build tools as comments (they will not affect the 
behavior of tags embedded in them).
Since an application is free to interpret the whole body of parsed text as it wishes, any application that uses this
format should indicate how the elements will be interpreted.
<p>
Coders can mark some text as comments, in which case the text will be excluded from the parsed set of Atoms.

<h3>{@level 3 Concepts}</h3>

A script is typically identified as a text file in the local file system,
but an application can parse an arbitrary in-memory string as well.
<p>
The {@link parasol:script.Parser script Parser} scans the input text and returns a vector of {@link parasol:script.Atom Atom}
objects.
Atoms can be simple runs of text or more complex objects, depending on the elements included in the file.

<h3>{@level 3 Syntax}</h3>

{@grammar}
{@production script <i>element</i> ...  }
{@production element <i>text-run</i> }
{@production | <i>string<i> }
{@production text-run any sequence of text characters that do not include other defined elements }
{@end-grammar}

<h3>{@level 3 The <span class=code>pbuild</span> Build Script Tag Set}</h3>

{@anchor make-pbld}

<table>
<tr><td>Tag</td><td>Attribute</td><td>Description</td></tr>
<tr><td><b>after_pass</b></td><td></td><td>
						May only appear in <span class=code>tests</span> objects.
						The content of the tag is a shell script. 
						It is executed after everything else
						in <span class=code>pbuild</span>.
						If the build these tests were run in passes, this script is
						executed.
						This element appears in certain Parasol build tests because they
						must modify the binary files that are running the tests.
						<p>
						You shouldn't encounter any situations where this is needed.
</td></tr>
<tr><td><b>application</b></td><td></td><td>
						This defines a self-contained compiled Parasol application.
						A directory will be created containing copies of the <span class=code>parasolrt</span> and
						<span class=code>libparasol.so.1</span> binaries, a compiled PXI file of the application
						Parasol code and a shell script named <span class=code>run</span> that runs the compiled
						code.
						<p>
						One can either directly execute the shell script or create a link in a directory in your
						PATH that points to the run script.
						<p>
						Note: Part of the pbuild changes being added to add support for installation steps in this
						sequence will allow pbuild to create any links in your path, or installing the application
						in your environment as part of the build.
						<p>
						Note: It is expected that applications might want to embed data files for use at run time
						in the install directory of an application. 
						Similarly, packages may want to attach data
						files to themselves and expect to refer to them at runtime.
						This suggests the need for package and application relative path support in the runtime.
						For example, 

{@code
    myDataFile := storage.path(context.path("some-lib:acme.com"),
                               "some.dat");
}
						or
{@code
    myDataFile := storage.path(runtime.applicationPath(),
                               "some.dat");
}

</td></tr>
<tr><td></td><td><i>main</i></td><td>
						This is the path to the main unit file for the application.
						It is a path relative to the directory containing the <span class=code>make.pbld</span> file.
</td></tr>
<tr><td></td><td><i>name</i></td><td>
						This is the name of the application.
						<p>
						Note: This name currently determines the name of the directory in <span class=code>build</span> 
						where the appplication is created.
</td></tr>
<tr><td></td><td>role</td><td>
						This is the 'role' of the application.
						Currently this is merely a matter of documentation and does not affect the bult product.
						Values that appear so far are 'service' for a long-running server process or 'test' for a
						command-line test program.
</td></tr>
<tr><td></td><td>version</td><td>
						This is the version to assign to the built application.
						The version strings embedded in the build scripts are actually templates. 
						You may use the letter D in the place of one of the digit sequences of the version
						number.
						The letter D expands to the date/time stamp of the build, using the time format
						<span class=code>yyyyMMddHHmmss</span>.
</td></tr>
<tr><td>command</td><td></td><td>Description</td></tr>
<tr><td></td><td>main</td><td></td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td>elf</td><td></td><td>Description</td></tr>
<tr><td></td><td>makefile</td><td></td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>target</td><td></td></tr>
<tr><td>ets</td><td></td><td>Description</td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td>execute</td><td></td><td>Description</td></tr>
<tr><td></td><td>suite</td><td></td></tr>
<tr><td>file</td><td></td><td>Description</td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>src</td><td></td></tr>
<tr><td>folder</td><td></td><td>Description</td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td>include</td><td></td><td>Description</td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>type</td><td></td></tr>
<tr><td>init</td><td></td><td>Description</td></tr>
<tr><td></td><td>placement</td><td></td></tr>
<tr><td>link</td><td></td><td>Description</td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>target</td><td></td></tr>
<tr><td>on_pass</td><td></td><td>Description</td></tr>
<tr><td>package</td><td></td><td>Description</td></tr>
<tr><td></td><td>manifest</td><td></td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>preserveAnonymousUnits</td><td></td></tr>
<tr><td></td><td>version</td><td>
						This is the version to assign to the built application.
						The version strings embedded in the build scripts are actually templates. 
						You may use the letter D in the place of one of the digit sequences of the version
						number.
						The letter D expands to the date/time stamp of the build, using the time format
						<span class=code>yyyyMMddHHmmss</span>.
</td></tr>
<tr><td>pxi</td><td></td><td>Description</td></tr>
<tr><td></td><td>main</td><td></td></tr>
<tr><td></td><td>name</td><td></td></tr>
<tr><td></td><td>target</td><td></td></tr>
<tr><td></td><td>version</td><td>
						This is the version to assign to the built application.
						The version strings embedded in the build scripts are actually templates. 
						You may use the letter D in the place of one of the digit sequences of the version
						number.
						The letter D expands to the date/time stamp of the build, using the time format
						<span class=code>yyyyMMddHHmmss</span>.
</td></tr>
<tr><td>target</td><td></td><td>Description</td></tr>
<tr><td></td><td>cpu</td><td></td></tr>
<tr><td></td><td>os</td><td></td></tr>
<tr><td>tests</td><td></td><td></td></tr>
<tr><td></td><td>suite</td><td></td></tr>
<tr><td>use</td><td></td><td>Description</td></tr>
<tr><td></td><td>package</td><td></td></tr>
</table>
<p>
In the tag hierarchy below, if a tag name appears in bold, 
it may appear on an object at the level of the <span class=code>make.pbld</span> file
itself.
Tag names that appear indented underneath another tag may appear in the contents of
the outer tag.
<p>

<p>
The tag hierarchy:

<ul>
	<li><b>application</b>
		<ul>
			<li><b>target</b>
			<li><b>use</b>
		</ul>
	<li><b>command</b>
	<li><b>package</b>
		<ul>
			<li><b>elf</b>
			<li><b>file</b>
			<li><b>folder</b>
				<ul>
					<li><b>elf</b>
					<li><b>file</b>
					<li><b>folder</b>
					<li><b>include</b>
					<li><b>link</b>
					<li><b>pxi</b>
					<li><b>target</b>
				</ul>
			<li><b>include</b>
			<li><b>init</b>
				<ul>
					<li>The contents of an init object are 
						plain text with a sequence of file names
						of Parasol unit files separated by white space.
						Unit file names obviously cannot contain white
						space characters if they are to appear in an
						init object.
						The named files must be members of the package
						and the path is relative to the constructed
						package directory.
						The named units will be initialized (i.e. have
						their static initializers executed) in the order
						they are named in the tag, at the placement given
						by the placement attribute of the object.
				</ul>
			<li><b>link</b>
			<li><b>pxi</b>
			<li><b>target</b>
			<li><b>use</b>
		</ul>
		Note that, in effect, the contents of a package object
		are the contents of the package directory.
		As a result, the contents of a package object are anything
		that can appear in a folder object, plus possible init and use objects.
	<li><b>target</b>
		<br>
		Target tags are a special case.
		They should be thought of as 'conditional compilation'.
		A target object defines a set of filters and, if they are true,
		the contents appear in the spot where the target object was
		placed.
		Thus, the set of tags that can appear in a target object's
		contents are the set that can appear where the target object
		appears.
		For example, a target object placed inside a tests object
		can contain after_pass, ets, execute, on_pass and, of course, other
		target objects.
	<li><b>tests</b>
		<ul>
			<li><b>after_pass</b>
				<ul>
					<li>The contents of this tag is a shell script.
				</ul>
			<li><b>ets</b>
			<li><b>execute</b>
			<li><b>on_pass</b>
				<ul>
					<li>The contents of this tag is a shell script.
				</ul>
			<li><b>target</b>
		</ul>
</ul>

<h3>{@level 3 The Parasol Compiler and Runtime Test Scripts Tag Set}</h3>

{@anchor runets}


