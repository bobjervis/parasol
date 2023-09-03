<h2>{@level 2 Software Evolution and Versioning}</h2>

Authors want to support the software they publish.
Users ask questions, report bugs and request features.
Authors response often include software updates.
<p>
The Parasol reference implementation includes tools intended to assist an
author in building and identifying their updates, and also assist users in finding those updates.

<h3>{@level 3 Parasol Version Strings}</h3>

A <i>Parasol version string</i> is used to identify versions of packages and applications created by the
reference implementation.
It is recommended that 3rd party packages follow this format as the build tools can support determining
which versions are compatible with which.

The format is:

{@code
		<i>digits</i> <b>.</b> <i>digits</i> <b>.</b> <i>digits</i>
}

Three numbers are required, so the shortest version string has 5 characters in it.
Also, the leading digit in a group can only be a zero if it is the only digit in the group.
Thus, the following version string is not considered well-formed (because the middle group has a leading zero):

{@code
		1000.07.5005
}

<p>
The first number is the <i>major version</i>, the second number is the <i>minor version</i> and the
third is the <i>fix version</i>.
<p>
Two versions can be compared.
If major versions differ, the string with the higher major version is largest.
Otherwise, if minro versions differ, the string with the higher minor version is largest.
<p>
For unpublished software, the convention is to use the number 0 as the major version. 
Also for unpublished software there is no expectation that two different versions are in any way compatible.
<p>
The first published version should be 1.0.0. 
All subsequent versions should not duplicate any released version.
Version numbers can be skipped, but if any new version is released if the major and minor are the same as a
pre-existing version, the new version must have a larger fix version.
Also, if only the major version is the same as a previously released version, the minor version number 
should be larger than any that have been previously released for that major version.

For example the following release sequence conforms to these version numbering rules:

{@code
		1.0.0
		1.4.0
		1.0.1
		2.0.5
		2.1.0
		1.5.3
}

The following release sequences do not conform:

{@code
		1.0.0
		1.4.0
		1.3.0		The minor release decreased
}

{@code
		1.0.0
		1.1.10
		1.1.5		The fix release decreased
}

{@code
		1.0.0
		1.4.0
		2.0.0
		1.3.0		The smallest allowed minor release would be 1.5
}


<h3>{@level 3 Versions}</h3>

It's already widespread practice to assign versions to product releases, and open source libraries in
a variety of languages use them.
There is even a phrase "DLL Hell" that refers specifically to the problem of managing library versions when
running the Windows operating system.
But Windows is not alone in having this problem.
<p>
Let's outline a simple example of an application that uses two 3rd Party libraries, call them A and B.
In turn, the authors of A and B each chose to use a common library from yet another author, C.
Now we have 4 authors and the application's author, wanting or needing bug fixes in library A finds out 
the version she needs but when she gets it, she find out that it depends on a feature added to library C.
But library B was built to depend on an older version of C.
Our poor application author must now investigate all the versions and all the conflicts and figure out 
how to get them to all happily work together.
And that may only be possible by engaging with the various authors and negotiating the necessary changes
to make them work.
<p>
Needless to say, exercises like this one go on every day for some software developer.
The economics of software development make it necessary to use 3rd party libraries for many valuable, but
application independent, tasks.
There is also no question that the occasional headache brought on by version conflicts is an easy
price to pay for the value of having them there.
<p>
In general, it is perilously dangerous to try and run two versions of the same library in one program.
Without detailed knowledge of how that library was implemented, and how the two versions differ, there may be 
hidden abd subtle interactions that could cause any amount of havoc in the application where they are included.
<p>
So, a developer needs tools to understand which versions of which libraries are needed and which are available.
In parasol, a library is called a package.
<p>
The Parasol builder must assemble packages into an application and uses various metadata associated with the
packages to facilitate that.
Some of the most important bits of the metadata deal with versions.
<p>
A <i>package version</i> is a string, assigned when the package is created.
In principle, there is no particular format to that string. 
However, certain facilities of the Parasol tool suite can provide more functionality if
a specific format is used.

<h3>{@level 3 Package Metadata}</h3>
A package has an object in JSON format as it's metadata.

The various fields are optional and their description is given below:

<ul>
	<li><b>"version"</b> - A string value. This should be a Parasol version string. It is assigned
							by the builder based on command-line options and configuration parameters.
	<li><b>"built_by"</b> - A string value. This is a Parasol version string. It is assigned by the
							Parasol builder.
	<li><b>"uses"</b> - A list. Each element of the list is a JSON object as follows:
		<ul>
			<li><b>"name"</b> - A string value. The package name of a package that musst be included
							in an application that uses this one.
			<li><b>"built_with"</b> - A string value. This is any version string defined for the named
							package. When this package was built, it was compiled with this particular
							version of the used sub-package.
			<li><b>"allow_versions"</b> - A list of strings. See under Version Constraints below for details.
			<li><b>"disallow_versions"</b> - A list of strings. See under Version Constraints below for details.
		</ul>
</ul>

<h4>{@level 4 Version Constraints}</h4>

When a package is built, it depends on other packages.
The build script may optionally include two metadata properties, "allow_versions" and "disallow_versions" on
the use() tag for a package.
The builder must use one of the versions of the named package that is available in the current Parasol context 
for the build.
If no such lists are provided, then all available versions are considered qualified.
<p>
If a "disallow_versions" list is provided, then each string in the list is interpreted as a <i>version
constraint</i>.
If any of the constraints in the "disallow_versions" list applies to an available version, the available version
is discarded.
<p>
Otherwise, if an "allow_versions" list is provided, then each string in the list is interpreted as a 
version constraint.
If any of the constraints in the "allow_versions" list applies to an available version, that version is
included in the qualified list of versions.
<p>
If at the end of this process there are no qualified package versions available, the build fails.
If more than one qualified package version is available, the highest number is chosen.
<p>
A version constraint begins with one or two comparison characters.
The following are the allowed combinations:

{@code
	==	!=	<	<=	>	>=
}

These characters are then followed by Parasol version number.
The available version number is then compared to the constraint.
The available version is compared using the supplied comparison and version number.
If the comparison is true, the constraint applies to the available version nmuber.
<p>
 If a version number does not conform to the Parasol version number format, the behavior is undefined.

