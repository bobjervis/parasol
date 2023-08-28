<h2>{@level 2 Annotations}</h2>

{@anchor ref-annotations}

The reference implementation only recognizes the following annotations:

<table>
<tr><th>Name</th><th>Description</th></tr>
<tr><td>@CompileTarget</td><td>
				This annotation should not appear in user code.
				It is placed in the core runtime to identify the
				variable used to test what the target of the current compilation is.
</td></tr>
<tr><td>@Header</td><td>
				This annotation may appear on any enum or flags declaration.
				Any such flagged declaration will be processed by the <b>genhdr</b>
				utility to generate a C include header containing the defined 
				values as an enum in the header.
				If the annotation includes a single string literal as it's argument,
				that string value will be added as a prefix to each of the named
				enum or flags values.
</td></tr>
<tr><td>@Layout</td><td>
				This annotation may appear on any class or enum declaration.
				If the annotationn includes a single string literal, it is interpreted
				as follows:
				<ul>
					<li>"lexical" - The members of the class are laid out in
						lexical order.
						Each member is assigned an offset greater than any prior
						members and less than any subsequent members.
						Pad bytes may be inserted between members to ensure efficient
						access to the individual members.
						<p>
						This is the layout method used by C.
						If you are trying to mimic a C struct declaration, you should use
						this layout annotation.
					<li>"compact" - The members of the class are laid out in
						lexical order.
						Each member is assigned an offset greater than any prior
						members and less than any subsequent members.
						No pad bytes are inserted between members, so access to some
						members may be inefficient, the cost depending on the target
						architecture.
				</ul>
				In the absence of a @Layout annotation, a Parasol implementation is free
				to assign member objects inside a class in any order.
</td></tr>
<tr><td>@Linux</td><td>
				This annotation is placed on an abstract function declaration at unit
				scope to supply binding information for locating externally linked
				libraries, usually written in C.
				This binding applies to running programs in the Linux operating system.
				The annotation uses two string literals as arguments.
				The first argument is the name of a shared object file located in the
				program's LD_LIBRARY_PATH.
				The second argument is the name of the symbol as it appears in the shared
				object.
</td></tr>
<tr><td>@Pointer</td><td>
				This annotation should not appear in user code.
				It is used to identify the <span class=code>pointer</span> template.
</td></tr>
<tr><td>@Ref</td><td>
				This annotation should not appear in user code.
				It is used to identify the <span class=code>ref</span> template.
</td></tr>
<tr><td>@Shape</td><td>
				This annotation should not appear in user code.
				It is used to identify the <span class=code>vector</span> 
				and <snap class=code>map</span> templates.
</td></tr>
<tr><td>@Windows</td><td>
				This annotation is placed on an abstract function declaration at unit
				scope to supply binding information for locating externally linked
				libraries, usually written in C.
				This binding applies to running programs in the Windows operating system.
				The annotation uses two string literals as arguments.
				The first argument is the name of a dynamic linked library located in the
				program's PATH.
				The second argument is the name of the symbol as it appears in the library.
</td></tr>
</table>
