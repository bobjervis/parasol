<h2>{@level 2 Comparison Operators}</h2>

Parasol supports comparison operators for all of the scalar types, but also allows a programmer to create custom comparators for classes.
<p>
In general, a Parasol class can define three alternative custom comparators, depending on the distinctions the comparator can make. 
In each case, the comparator method must be named <span class=code>compare</span> and must take a single argument of the same class type. 
The category of comparator is determiend by the return type. The options are:
<ol>
    <li>Equality (both the <span class=code>==</span> and <span class=code>!=</span> operators).
    If the comparator method returns a boolean type, then a true value of the comparator will produce a true result for the 
    <span class=code>==</span> operator and false for <span class=code>!=</span>.
     <li>Fully-ordered (all comparison operators except identity -- <span class=code>===</span> and <span class=code>!==</span>).
     If the comparator method returns a signed integral type, then a negative return value yields a true result for the less-than operator (<span class=code>&lt;</span>), 
     a zero value matches equality (<span class=code>==</span>) and a positive result yields true for greater-than (<span class=code>&gt;</span>).
     <li>Partially-ordered (all comparison operators except identity -- <span class=code>===</span> and <span classs=code>!==</span>). 
     If the comparator method returns a floating point type, comparisons will behave the same as for comparators that return an integral type, except that 
     comparisons will treat a NaN result as unordered. 
     Unordered comparisons have the value true for all the not operators (they include an exclamation mark character) and false for all other comparison operators. 
     This allows you to create a class that mimics the behavior of floating-point comparisons.
     
