<h2>{@level 2 Application Structure}</h2>

Parasol is designed to be used in a number of contexts:

<ul>
	<li>Simple scripting. 
		Even though Parasol's features would seem to be oriented to high performance software, it also possesses
		a set of features that make it attractive in such scenarios. The ability to simply run a single file
		application consisting of a few lines make it productive for such light-weight tasks. There is also
		significant support for simple text manipulation, file i/o and even HTTP requests, as well as support for
		data technologies like JSON make it a viable tool in a modern cloud-based operating environment.
		For these applications, garbage collection is largely immaterial. Scripts typically run for short periods
		and terminate. You can achieve the effect of garbage collection by just not deleting any of your data
		structures.
	<li>Mid-sized engineering applications. Parasol has support for floating point operations including NaN's
		as well as vector operations. 
		This makes it an interesting language for eventual implementtion on a vector processor.
		Combined with multi-threding support as well as remote procedure calls, Parasol can deliver substantial
		performance.
	<li>Large applications. Parasol also provides a system for defining and building larger-scale applications
		incorporating third-party libraries. 
		Namespaces form the language's framework for exposing interfaces and managing a large code base.
		Compilation into binary runtimes make for fast startup.
		Large applications often create complex data structures that are hard to keep stable. 
		Parasol supports no garbage collection because there are some applications where you can get
		significantly smaller memory requirements and faster performance than with garbage collected languages.
</ul>

Parasol is not for everyone. 
Until there is a substantial community contributing code, it will be a choice for
adventurous developers.

<h3>{@level 3 Simple Scripting}</h3>

The reference implementaation of the Parasol compiler provides an operating mode to directly execute a Parasol
source program without need for a distinct compile step.

