/*		      FILE "regexp.p"			    	*/
/*
 *	This program is the CONFIDENTIAL and PROPRIETARY property
 *	of English Knowledge Systems Inc.  Any unauthorized use,
 *	reproduction or transfer of this program is strictly prohibited.
 *
 *      Copyright (c) 1988 1989 1990 1992 English Knowledge Systems, Inc.
 *	This is an unpublished work, and is subject to limited distribution and
 *	restricted disclosure only. ALL RIGHTS RESERVED.
 *
 *			RESTRICTED RIGHTS LEGEND
 *	Use, duplication, or disclosure by the Government is subject to
 *	restrictions set forth in subparagraph (c)(1)(ii) of the Rights in
 * 	Technical Data and Computer Software clause at DFARS 252.227-7013.
 *		English Knowledge Systems Inc.
 *		5525 Scotts Valley Dr. #22
 *		Scotts Valley, CA 95066
 *
 *	The REGX PLUS package may be compiled into an application
 *	and the application sold without royalty payments.  If you 
 *	wish to resell the source code we would be happy to work
 *	out a per copy or a one time licensing fee so that you may 
 *	do so.
 *				James H. Conklin
 *				President
 *				English Knowledge Systems Inc.
 */

/*
 *	9-20-91 JHC
 *	ADDITIONS:
 *	1.  Added the global variable Sr_shortmatch.  If set to 1, this
 *	    variable will have * and + match the shortest strings found
 *	    instead of the longest.
 *
 *	2.  Added more error checking to the function calls.
 *
 *	3.  Added more debugging information.
 *
 *	4.  Added more documentation.
 *
 *	CHANGES:
 *	1.  Changed the types of the interface routines.  The compiled
 *	    pattern used to be passed as a char * .  It is now passed
 *	    as SR_CPAT * .  This change will enhance the ability of the
 *	    compiler to catch errors in usage.
 *
 *	2.  Changed the data structure that is used to store information 
 *	    internally.  This change will make ports easier.
 *
 *	3.  Changed some of the code formatting to enhance readability.
 *
 *	FIXES:
 *	1.  A fix that makes sure all nodes will always be freed by
 *	    sr_search() when apropriate.
 *
 *	2.  A fix that makes sure all nodes will always be freed by
 *	    sr_free_re() whenever a pattern with an ASSIGN is given.

 * 	2-12-93 JHC
 * 	ADDITIONS:
 * 	1.  New routines.
 * 		sr_s(str, pat)		search
 * 		sr_sr(str, pat, rep)	search and replace
 * 	 	sr_srg(str, pat, rep)	search and replace global
 * 	 	sr_cs(str, pat)		compiled pattern search
 * 	 	sr_csr(str, pat, rep)	compiled pattern search and replace
 * 	 	sr_csrg(str, pat, rep)	compiled pattern search and replace global
 * 	 	sr_free_assign()	frees all memory in assigns.
 * 
 * 	2.  Added a new internal debugging routine.
 * 
 * 	3.  Added more examples to the documentation.
 * 
 * 	4.  Provide the documentation in Microsoft word for windows
 * 	    and laser jet 2 formats as well as in ascii.
 * 
 * 	5.  Added some code examples of the routines in use.
 * 
 * 	6.  Allow extended character codes from 128 to 256 to be allowed 
 * 	    in character classes.
 * 
 * 	CHANGES:
 * 	1.  Made the existing parse tree print routine available 
 * 	    outside the search and replace routines.
 * 
 *	2.  Changed the data structure that is used to store information 
 *	    internally.  This change will make ports easier.
 *
 * 	3.  Changed some code to get rid of some more lint messages.
 *
 *	4.  Changed the name of this file.
 *
 *	5.  Changed the name of the header file.
 *	
 *	6.  Changed some function definitions to be ANSI compatiple.
 *
 *	7.  Improved the sr_test.c to confirm each test as working.
 *
 * 	FIXES:
 * 	1.  A fix that frees any memory saved in the assign variables
 * 	    every time a new search is started.
 * 	2.  A fix to the scanner when dealing with a highly embedded set
 * 	    of replications.
 *	3.  Fixed problem with some special characters not being able
 *	    to be escaped.
 * 	4.  Fix to unassign assingments that were made when a sub pattern
 * 	    which had done an assign fails.
 *
 *	11/5/94 RBJ
 *
 *	CHANGES:
 *	1.  Translated to Parasol.
 *
 *	2.  Names converted.
 *
 *		SR_CPAT	-> pnode
 *		Sr_assign -> variable
 *
 *  11/10/2017 RBJ
 *
 *  CHANGES:
 *	1. Upgraded to new Parasol.
 */

/*
 * A DETAILED DESCRIPTION OF PARSE TREE STRUCTURE
 *
 *   The normal use of the fields in a parse tree node is as described above.
 *   Exceptions to this use are described below.
 *
 *   ALT and CAT:
 *       For these two types of nodes, the left and right branches are actually
 *       of type (SR_CPAT *), and point to sub-parse trees.  alter is used
 *       in scanning as a flag to indicate which branch is being executed.
 *
 *   ASSIGN:
 *       The left branch is a (SR_CPAT *) pointing to a sub-tree.  iright
 *       is a (char) with value a-z.  The asgpos is used as (char *)
 *	 pointing to beginning of the assignment location.
 *
 *   REP1 and REP2:
 *       The left branch is a (SR_CPAT *) pointing to a sub-tree.  The
 *       right branch is a (SR_CPAT *) pointing to a single node which
 *       has the replication information.  In that node, ileft is an
 *	 (int) specifying the lower bound on replication; iright is an
 *	 (int) specifying the upper bound.  Also in the sub-node, asgpos
 *	 is a (char *) pointing to the place in the string being scanned
 *	 where the current try at replication began.  It is included in order
 *	 to prevent the replication from matching the null string an infinite
 *	 number of times.  The parent and type fields are unused in the
 *	 sub-node.  In the REP1 or REP2 node, the alter field is used as a
 *	 count on number of replications.
 *
 *   CHARS1 and CHARS2:
 *       ileft is a (char) specifying which character to match.  The right
 *	 branch and the alter flag are as in REP1 and REP2, except that
 *       the alter flag is unused in the sub-node.
 *
 *   CCLASS1 and CCLASS2:
 *       The left branch is a (SR_CPAT *) pointing to a description
 *       of the character class (see CCLASS).  The right branch and alter
 *       flags are as in CHARS1 and CHARS2.
 *
 *   ARB1 and ARB2:
 *       The left branch is unused, and the right branch and alter flags
 *       are as in CHARS1 and CHARS2.
 *
 *   CHARS:
 *       ileft is a (char) specifying which character to match. The
 *       right branch is a (SR_CPAT *) pointer to additional sequences
 *       of CHARS, CCLASS, ARBITRARY, POSITION, and VARIABLE nodes
 *	 (since all of these can be processed linearly with no need
 *       to backtrack).  The alter flag is unused.

 *   CCLASS:
 *       The left branch is a (SR_CPAT *) pointer to a chain of
 *       character class ranges.  In each node in the chain, ileft and
 *       alter fields are the (char) lower and upper bounds on characters
 *       accepted, and the right branch is a (SR_CPAT *) to more
 *       links in the chain, with the parent field unused.  The chain of
 *       ranges is in ascending order, to shorten time needed to look.
 *       The right branch and alter flag are as in CHARS:
 *
 *   ARBITRARY:
 *       The left branch and alter flag are unused.  The right branch is
 *       as in CHARS.
 *
 *   POSITION:
 *       The left branch is a (SR_CPAT *) pointer to a chain of
 *       position ranges.  In each node in the chain, the ileft and
 *       alter fields are the (int) bounds on positions.  It is impossible
 *       to tell a priori which is the lower and which is the upper bound
 *       since it may depend on the length of the string being scanned.
 *       In the chained nodes, the right branch is a (SR_CPAT *)
 *       pointer to the rest of the chain.  In the POSITION node, the
 *       right branch and alter flag are as in CHARS.
 *
 *   VARIABLE:
 *       ileft is a (char) from a-z indicating which variable to expand.
 *	 The alter flag is unused, and the right branch is as in CHARS.
 *
 *
 *
 *  USE OF NODES IN SCANNING:
 *
 *   In scanning, use is made of a linked list stack of free parse tree nodes
 *   in order to do backtracking.  Normally, the parent pointer points back
 *   to the previous entry on the stack.  The left branch is a (SR_CPAT *)
 *   pointer to the tree position to which to return.  The right branch is a
 *   (char *) pointing to the place in the string being scanned at which to
 *   continue the scanning process.  The alter flag is the saved alter flag
 *   of the node in the tree to which the return is to be made.
 *
 *   The exception to this is when the type of the tree position is the
 *   special value RESTORE (which does not occur in the tree).  In that case,
 *   the right branch is a (SR_CPAT *) pointer to a node in the tree
 *   and the alter flag is to be restored to that node.  This gives a
 *   mechanism to distinguish between just resetting the alter flag value
 *   (which is necessary sometimes, even when the node is not a generator)
 *   and a FAILURE return to a node which will try another choice.
 */

namespace parasol:text;

import parasol:file;


public class RegularExpressionException extends Exception {	// raised on compile or search
															// failures
}

public class SearchPattern	{
	private ref<pnode> compiledPattern;

	public string[] variable;			// Assigned variables
	public char endOfLine;				// additional end-of-line character
	public boolean metaflag;			// true if meta characters are
										// recognized without escapes
	public boolean shortmatch;			// true if shortest matches are
										// preferred

	public SearchPattern() {
		metaflag = true;
		shortmatch = false;
		endOfLine = 0;
		variable.resize(26);
		compiledPattern = null;
	}

	~SearchPattern() {
		if	(compiledPattern != null) {
			sr_free_re(compiledPattern);
			compiledPattern = null;
		}
	}
/*
display: () =
	{
	sr_treep(compiledPattern, 0, 0);
	}

/*	search() takes the compiled pattern and searches
 *	the string str.  If an instance of the pattern is found,
 *	search() returns it (in the form of a substring of the original
 *	str array.
 *	If the search fails, a RegularExpressionTrap is raised.
 */
search: 	(str: [:] char) [:] char =
	{
	pos:	ref char = str;
	endstr:	ref char = str + |str;
	c:	ref char;
	i:	short;
	t:	ref pnode = compiledPattern;
	result:	[:] char;

	if (compiledPattern == 0)
		RegularExpressionTrap raise();

	freeVariables();

	while (t.ptype == CAT)
		t = t.left;

	if (t.ptype == CHARS)
		i = t.ileft;
	else
		i = 0;

	/* This loop moves along the input string str one position at a */
	/* time trying to see if the compiled pattern will match at that*/
	/* position.  scanner() will match a compiled pattern at the    */
	/* beginning of a string.					*/
	for (;;) {
		if (i)  /* fast loop to find first character 		*/
			while (pos < endstr &&
			       *pos != i   &&
			       *pos != endOfLine)
					pos++;

		c = scanner(compiledPattern, pos, str);
		if (c != 0) {
			result = pos[:c - pos];
			return result;
			}

		if (pos >= endstr ||
		    *pos == endOfLine)
			break;

		pos++;
		}
	RegularExpressionTrap raise();
	}

/*
 *	This is a very straightforward routine.  You put one pointer (c)
 *	at the beginning of the old string, and the other pointer (d)
 *	at the beginning of the new string.  You copy from the old string
 *	until you get to where the match began.  You substitute the
 *	new string (with variable referencing, if any).  And then you
 *	copy the rest of the old string over.
 */
replace:	(old_str: [:] char, old_str_st: [:] char, 
			sub_str: [:] char) [:] char =
{
	c:	ref char; /* Pointer to the old string.			*/
	d:	[:] char; /* Pointer to the new string.			*/
	index:		short;
	len, i, tail:	int;

	if (!decipher(sub_str))
		RegularExpressionTrap raise();

	len = |old_str - |old_str_st;

	/* The only special character allowed is '<' so			*/
	/* turn off all other special characters and			*/
	/* check syntax first before starting to substitute.		*/
	for (index = 0; Nextch[index]; index++)
		if (Flags[index]) {
			if (Nextch[index] != '<') {
				len++;
				Flags[index] = false;
				continue;
				}

			index++;
			if (isupper(Nextch[index]))
				Nextch[index] = tolower(Nextch[index]);
			else if (!islower(Nextch[index]))
				goto err;
			c = variable[Nextch[index] - 'a'];
			if	(c)
				len += stringLength(c);
			index++;
			if (Nextch[index] != '>')
				goto err;
			}
		else
			len++;

	/* do substitution */
	d = new [len] char;
	i = &old_str_st[0] - &old_str[0];
	tail = |old_str - (i + |old_str_st);
	memCopy(d, old_str, i);
	for (index = 0; Nextch[index]; index++) {
		if (Flags[index]) {
			index++;
			c = variable[Nextch[index++] - 'a'];
			if (c == 0)
				continue;

			while (*c){
				d[i] = *c++;
				i++;
				}
			}
		else	{
			d[i] = char(Nextch[index]);
			i++;
			}
		}
	memCopy(d + i, old_str_st + |old_str_st, tail);
	|d = i + tail;
	delete Nextch;
	delete Flags;
	return d;

label	err:
	delete Nextch;
	delete Flags;
	RegularExpressionTrap raise();
	}

/*
 * Free any memory that has been allocated to the variable array.
 */
freeVariables:	() = {
	i:	short;

	for (i = 0; i < 26; i++) {
                if (variable[i] != 0) {
                        delete variable[i];
                        variable[i] = 0;
			}
		}

	}

/*
 *	This routine returns the parsed form of the search patern
 *	that it was passed.
 */
compile:	(s: [:] char) =
{
	stack:		[SR_STACK] pstack;
	xnew:		ref pnode;
	trace1:		ref pnode;
	trace2:		ref pnode;
	nstack:		int;
	i, j, k:	int;
	next:		int;
	lastt:		int = END;    /* Last type.                */
	nextt:		int = END;    /* Next type.                */

    if (!decipher(s))
        RegularExpressionTrap raise();

    Indexsc         = 0;
    stack[0].ptype   = END;
    stack[0].newval = 0;
    stack[0].term   = true;
    stack[0].val    = 0;
    nstack          = 1;
    next            = END;
    for (;;) {
        stack[nstack].ptype = next = gettoken(&stack[nstack], next);
        if (next < 0)
            goto err;

        for (;;) {
            /*  find top terminal on the stack */
            for (i = nstack - 1; !stack[i].term; i--)
                ;

            /* see if should shift or reduce */
            if (ff[stack[i].ptype] <= gg[next])
                break;

            /* perform reduction */
            for (i = 0; i < NPROD; i++) {
                j = nstack - 1;
                k = 0;
                for (;;) {
                    if (stack[j].term != prod[i].terms[k])
                        break;

                    if (stack[j].term) {
			/* Note that you will come through this 	*/
			/* place at least twice before having the 	*/
			/* prod[i].types[k] == 0 test succeed (which is	*/
			/* the only place where lastt is used).		*/
                        lastt = nextt;
                        nextt = stack[j].ptype;
                        if (prod[i].types[k] == 0) {
                            if (ff[nextt] < gg[lastt])
				goto reduce;

			    break;
			    }

                        if (nextt != prod[i].types[k])
				break;
                        }

                    j--;
                    k++;
                    }

		continue;
                }

            goto err;

label	reduce:
            switch(i) {
                case 1:             /* N & N => N */
                    /* The code is a little involved here in the interest */
		    /* of speeding up the scanning time later.  	  */
                    /* If you have a sequence of characters, 		  */
                    /* character classes, arbitraries, positions, and     */
                    /* variables, they are put into a linked list.        */
                    /* Scanning is quick since each of these can be       */
                    /* tested without worrying about backtracking.        */
                    trace1 = stack[nstack-3].val;
                    while (trace1.ptype == CAT)
                        trace1 = trace1.right;
                    if (trace1.ptype != CHARS     &&
                        trace1.ptype != CCLASS    &&
                        trace1.ptype != ARBITRARY &&
                        trace1.ptype != POSITION  &&
                        trace1.ptype != VARIABLE)
				goto cat;

                    while (trace1.right != 0)
                        trace1 = trace1.right;

                    trace2 = stack[nstack-1].val;
                    if (trace2.ptype == CHARS     ||
                        trace2.ptype == CCLASS    ||
                        trace2.ptype == ARBITRARY ||
                        trace2.ptype == POSITION  ||
                        trace2.ptype == VARIABLE)  {
                            trace1.right   = trace2;
                            stack[nstack-2] = stack[nstack];
                            nstack         -= 2;
                            break;
                            }

label	cat:		/* fall through and handle ordinary case		 */
                case 0:             /* N | N => N */
                    xnew                         = getpnode();
                    xnew.ptype                  = stack[nstack-2].ptype,
                    xnew.left                   = stack[nstack-3].val;
                    xnew.right                  = stack[nstack-1].val;
                    stack[nstack-3].val.parent = xnew;
		    stack[nstack-1].val.parent = xnew;
                    stack[nstack-3].val         = xnew;
                    stack[nstack-2]             = stack[nstack];
                    nstack                     -= 2;
                    break;

                /* REPLICATION CODE (Cases 2 and 3)			*/
                /* The code is a little opaque here too since I		*/
                /* contract replications of single characters, single	*/
                /* character classes and a single arbitrary into a new	*/
                /* node with a different type to speed up scanning.	*/
                case 2:             /* N R1 => N */
                    trace1 = stack[nstack-2].val;
                    if (trace1.right != 0)
			goto rep;

                    if (trace1.ptype == CHARS) {
                        trace1.ptype = CHARS1;
                        goto repdone;
                        }

                    if (trace1.ptype == CCLASS) {
                        trace1.ptype = CCLASS1;
                        goto repdone;
                        }

                    if (trace1.ptype == ARBITRARY) {
                        trace1.ptype = ARB1;
                        goto repdone;
                        }
                    goto rep;

                case 3:             /* N R2 => N */
                    trace1 = stack[nstack-2].val;
                    if (trace1.right != 0)
			goto rep;

                    if (trace1.ptype == CHARS) {
                        trace1.ptype = CHARS2;
                        goto repdone;
                        }

                    if (trace1.ptype == CCLASS) {
                        trace1.ptype = CCLASS2;
                        goto repdone;
                        }

                    if (trace1.ptype == ARBITRARY) {
                        trace1.ptype = ARB2;
                        goto repdone;
                        }

                   /* CODE FOR REPLICATION CASES */
label	rep:
                    xnew                         = getpnode();
                    xnew.ptype                   = stack[nstack-1].ptype,
                    xnew.left                   = stack[nstack-2].val;
                    xnew.right                  = stack[nstack-1].val;
                    stack[nstack-2].val.parent = xnew;
                    stack[nstack-2].val         = xnew;
                    stack[nstack-1]             = stack[nstack];
                    nstack--;
                    break;

label	repdone:
                    trace1.right   = stack[nstack-1].val;
                    stack[nstack-1] = stack[nstack];
                    nstack--;
                    break;

                case 4:             /* N $ C => N */
                    if (isupper(stack[nstack-1].newval))
                            stack[nstack-1].newval = tolower(stack[nstack-1].newval);
                    else if (!islower(stack[nstack-1].newval))
			    goto err;

                    xnew                         = getpnode();
                    xnew.ptype                  = stack[nstack-2].ptype,
                    xnew.left                   = stack[nstack-3].val;
                    xnew.iright                 = stack[nstack-1].newval;
                    stack[nstack-3].val.parent = xnew;
                    stack[nstack-3].val         = xnew;
                    stack[nstack-2]             = stack[nstack];
                    nstack                     -= 2;
                    break;

                case 5:             /* ( N ) => N */
                    stack[nstack-3] = stack[nstack-2];
                    stack[nstack-2] = stack[nstack];
                    nstack         -= 2;
                    break;

                case 6:             /* C  => N */
                case 7:             /* CC => N */
                case 8:             /* A  => N */
                case 9:             /* P  => N */
                case 10:            /* V  => N */
                    xnew                  = getpnode();
                    xnew.ptype           = stack[nstack-1].ptype;
                    xnew.left            = stack[nstack-1].val;
                    xnew.ileft           = stack[nstack-1].newval;
                    xnew.right           = 0;
                    stack[nstack-1].val  = xnew;
                    stack[nstack-1].term = false;
                    break;

                default:
		    DEBUGS("sr_compile MAIN SWITCH", i);
                    goto err;
                }
            }

        if (stack[nstack++].ptype == END)
		break;

        if (nstack == SR_STACK) {
            printf("SEARCH and REPLACE error - stack overflow\n");
            nstack--;
            goto err;
            }
        }

    if (nstack-- != 3)
	goto err;

    delete Nextch;
    delete Flags;
    compiledPattern = stack[1].val;
    return;

label	err:
    for (i = 1; i <= nstack; i++)
        if (!stack[i].term)
            sr_free_re(stack[i].val);

    delete Nextch;
    delete Flags;
    RegularExpressionTrap raise();
    }

/*
 * This routine does the actual scanning of the subject string for the
 * pattern that was compiled by sr_compile().
 *
 * The subject string is the string being scanned.  The pattern is the list of
 * operations to be done in scanning that have been constructed into a parse
 * tree by sr_compile().
 *
 *
 *      			LIST OF OPERATORS:
 *
 *      Generators:
 *
 *      The essence of a generator is that if at some point sufficient
 *      information is pushed onto a stack so that if later in scanning
 *      the pattern matching should fail for some reason, popping the
 *      stack will restore the scanning process to the same state as when
 *      the push was done.  At that time the generator can then take some
 *      alternate course of action.
 *
 *      Current generators include alternation and replication.  Note that
 *      character classes and range of positions are not generators, even
 *      though they imply use of alternatives, because the alternatives
 *      can all be tested without scanning ahead in the subject string.
 *
 *      RESTORE: is a special generator.  When it is pushed, the character
 *          pointer normally associated with the scanning position is instead
 *          a pointer to a node in the tree which needs to have its alter
 *          flag restored to some previous value.  After doing the restoration,
 *          RESTORE fails.
 *
 *      ALT:
 *          First: push; execute left branch
 *          Success: (from either branch) succeed
 *          Failure: execute right branch
 *
 *      REP1: (as many as possible)
 *          First: reset alter counter; goto Success
 *          Success: bump counter;
 *                   if insufficient count then
 *                       push RESTORE; execute left branch
 *                   if upper limit hit then
 *                       push RESTORE; succeed
 *                   push normally
 *                   execute left branch
 *          Failure: push RESTORE
 *                   succeed
 *
 *      REP2: (as few as possible)
 *          First: reset alter counter; goto Success
 *          Success: bump counter;
 *                   if insufficient count then
 *                       push RESTORE; execute left branch
 *                   push normally
 *                   succeed
 *          Failure: if upper limit hit then fail
 *                   push RESTORE
 *                   execute left branch

 *      REP1 and REP2 use as their executable operand (the left branch) any
 *      arbitrary pattern.  In addition, to make scanning faster in typical
 *      cases, there are CHARS1 and CHARS2, ARB1 and ARB2, and CCLASS1 and
 *      CCLASS2.  All of these are special cases of REP1 and REP2.  The code
 *      is simpler and faster since the execution of the left branch can be
 *      skipped and only one push on the stack is required.
 *
 *      Non-Generators:
 *
 *      Note that non-generators will not normally receive either the failure
 * 	signal or the success signal.  CAT and ASSIGN are exceptions to this.
 *	Their action is described below.
 *
 *      CAT:
 *          First: set alter flag to indicate left side; execute left branch
 *          Success: if coming from left branch then push RESTORE;
 *                   set the alter flag for right branch; execute right branch
 *                   if coming from right branch, then succeed.
 *
 *      ASSIGN:
 *          First: save starting pos in alter flag; execute left branch
 *          Success: push RESTORE; succeed
 *
 *      CHARS:
 *          Succeed if the characters in the operator string match those
 *          in the subject at current position.  Otherwise fail.
 *
 *      CCLASS:
 *          Succeed if the current character from the subject is any of
 *          those in the CCLASS (or not in the CCLASS if the group is
 *          negated).  Otherwise fail.
 *
 *      ARBITRARY:
 *          Succeed if not at the end of the subject.  Otherwise fail.
 *
 *      POSITION:
 *          Succeed if in the range of positions allowed.  Otherwise fail.
 *
 *      VAR:
 *          Like CHARS, but instead of using an operand to match against,
 *          use the value of a variable.
 */

scanner:	(cpat: ref pnode, subj: ref char, 
					st_start: [:] char) ref char =
{
	twork:	ref pnode;
	t:	ref pnode = cpat;
	pos:	ref char = subj;
	endstr:	ref char = st_start + |st_start;
	d:	ref char;
	c:	ref char;
	pflag:	int = FIRST;
	i, len:	int;

    Stacksc = 0;
    for (;;) {
        if (pflag == SUCCESS)
            t = t.parent;

        if (pflag == FAILURE) {
            pos = pop(&twork);
            t   = twork;
            }

        if (t == 0) {
            if (pflag == SUCCESS) {
    		scan_free(Stacksc);
		return(pos);
                }

            /* If FAILURE, then stack is necessarily NULL. 		*/
    	    scan_free(Stacksc);
            return(0);
            }

        switch(t.ptype) {
            case RESTORE:                               /* FAILURE 	*/
		twork = ref pnode(pos);
		if (twork.ptype == ASSIGN) {
                        i = twork.iright - 'a';
			if (variable[i]) {
				delete variable[i];
				variable[i] = 0;
				}

			if (twork.asgstr) {
				variable[i]  = twork.asgstr;
				twork.asgstr = 0;
				}
			}

                (ref pnode(pos)).alter = t.alter;
                continue;

            case ALT:
                switch(pflag) {
                case FIRST:
                        if (!push(t, pos))
                            goto err;
                        t = t.left;   	/* left branch	*/
                        continue;

                case SUCCESS:
                        continue;                       /* we worked 	*/

                case FAILURE:                           /* TRY AGAIN 	*/
                        pflag = FIRST;                  /* right branch */
                        t     = t.right;
                        continue;

		default:
			DEBUGS("scanner ALT", pflag);
			continue;
                }

            case CAT:
                switch (pflag) {
                case FIRST:
                        t.alter = false;               /* left branch flag */
                        t        = t.left;
                        continue;

                case SUCCESS:
                        if (!pusher(t)) 
                            goto err;        		/* push RESTORE	*/

                        if (t.alter)
                            continue;         		/* test flag  	*/

                        t.alter = true;                /* right branch flag */
                        pflag    = FIRST;
                        t        = t.right;
                        continue;

		default:
			DEBUGS("scanner CAT", pflag);
			continue;
                }

            case ASSIGN:
                switch (pflag) {
                case FIRST:
                        t.asgpos = pos;
                        t         = t.left;
                        continue;

                case SUCCESS:
			t.asgstr = 0;
                        i         = t.iright - 'a';
                        if (variable[i] != 0) {
				t.asgstr    = variable[i];
				variable[i] = 0;
				}
			
			len = pos - t.asgpos + 1;
			if (len > 0) {
				d = variable[i] = new [len] char;
				if (d == 0)
					fatal("out of memory\n");

                        	c = t.asgpos;
                        	while (c < pos)
	                            	*d++ = *c++;

                        	*d = EOS;
				}

                        if (!pusher(t))
                            goto err;    		/* push RESTORE */
                        continue;                   	/* succeed 	*/
		default:
			DEBUGS("scanner ASSIGN", pflag);
			continue;
                    }

            case REP1:
                switch (pflag) {
                case FIRST:
                        t.alter = -1;
                        /* Fall through here */
                case SUCCESS:
                        t.alter++;                     /* bump counter */
                        if (t.alter < LOWER(t)) {      /* insufficient count */
                            if (!pusher(t)) 
                                goto err;               /* push RESTORE */

                            pflag = FIRST;              /* execute LEFT */
                            t     = t.left;
                            continue;
                            }

                        if (t.alter > LOWER(t) &&
                            pos == BEGIN(t))     {      /* null string check */
                                pflag = FAILURE;
                                continue;
                                }

                        if (!pusher(t.right))
			    goto err;
                        if (t.alter >= UPPER(t) &&
			    UPPER(t) >= 0)        {     /* upper limit hit */
                            if (!pusher(t)) 
                                goto err;               /* push RESTORE	*/

                            pflag = SUCCESS;            /* SUCCEED 	*/
                            continue;
                            }

                        setBEGIN(t, pos);                 /* null check 	*/
                        if (!push(t, pos)) 
                            goto err;                   /* push 	*/

                        pflag = FIRST;                  /* execute LEFT */
                        t     = t.left;
                        continue;

                case FAILURE:
                        if (!pusher(t))
                            goto err;                   /* push RESTORE */

                        pflag = SUCCESS;                /* SUCCEED 	*/
                        continue;

		default:
			DEBUGS("scanner REP1", pflag);
			continue;
                }

            case CHARS1:
            case ARB1:
            case CCLASS1:
                switch (pflag) {
                case FIRST:
                        t.alter = 0;
                        if (t.ptype == CHARS1)
                            while (pos[t.alter] == t.ileft)
                                t.alter++;

                        else if (t.ptype == ARB1)
                            while (pos + t.alter < endstr  &&
                                   pos[t.alter] != endOfLine)
                                        t.alter++;

                        else /* t.ptype == CCLASS1 */
                            while (inrange(pos[t.alter], t.left))
                                        t.alter++;

                        if (UPPER(t) >= 0      && 
		            UPPER(t) <= t.alter)
                            t.alter = UPPER(t);

                        /* t.alter ends at the maximum number of       */
                        /* successful matches so it needs to be bumped. */
                        t.alter++;
                        pflag = FAILURE;
                        /* fall through here */
                case FAILURE:
                        /* decrement t.alter first */
                        if (--t.alter < LOWER(t))
                            continue;    		/* FAIL 	*/

                        if (!push(t, pos))
                            goto err;

                        pos  += t.alter;
                        pflag = SUCCESS;
                        continue;

		default:
			DEBUGS("scanner CCLASS1", pflag);
			continue;
                    }

            case REP2:
                switch (pflag) {
                case FIRST:
                        t.alter = -1;
                        /* Fall through here */
                case SUCCESS:
                        t.alter++;                     /* bump counter */
                        if (t.alter < LOWER(t)) {      /* insufficient count */
                            if (!pusher(t))
                                goto err;               /* push RESTORE */

                            pflag = FIRST;              /* execute LEFT */
                            t     = t.left;
                            continue;
                            }

                        if (t.alter > LOWER(t)) {
                            if (pos == BEGIN(t)) {
                                /* null string check */
                                pflag = FAILURE;
                                continue;
                                }

                            if (!pusher(t.right))
                                goto err;
                            }

                        if (!push(t, pos)) 
                            goto err;                   /* push 	*/

                        pflag = SUCCESS;                /* SUCCEED 	*/
                        continue;

                case FAILURE:
                        if (t.alter == UPPER(t))       /* FAIL 	*/
                            continue;

                        setBEGIN(t, pos);                 /* save null check */
                        if (!pusher(t)) 
                            goto err;                   /* push RESTORE */

                        pflag = FIRST;                  /* execute LEFT */
                        t     = t.left;
                        continue;

		default:
			DEBUGS("scanner REP2", pflag);
			continue;
                }

            case CHARS2: 
            case ARB2:
            case CCLASS2:
                switch (pflag) {
                case FIRST:
                        t.alter = 0;
                        if (t.ptype == CHARS2)
                            while (pos[t.alter] == t.ileft)
                                t.alter++;

                        else if (t.ptype == ARB2)
                            while (pos + t.alter < endstr &&
                                   pos[t.alter] != endOfLine)
                                        t.alter++;

                        else /* t.ptype == CCLASS2 */
                            while (inrange(pos[t.alter], t.left))
                                    t.alter++;

                        if (UPPER(t) >= 0      &&
		            UPPER(t) <= t.alter)
                            t.alter = UPPER(t);

                        /* t.alter ends at exactly the maximum       */
                        /* number of successful matches 	      */
                        if (t.alter < LOWER(t)) {
                            pflag = FAILURE;
                            continue;
                            }

                        pos      += LOWER(t);
                        t.alter -= LOWER(t);
                        /* t. alter now contains how many different  */
                        /* options we can try                         */
                        if (!push(t, pos))
                            goto err;

                        pflag = SUCCESS;
                        continue;

                case FAILURE:
                        /* t.alter is how many left to try */
                        if (t.alter-- <= 0) 
				continue;      		/* FAIL 	*/

                        pos++;
                        if (!push(t, pos))
                            goto err;

                        pflag = SUCCESS;
                        continue;

		default:
			DEBUGS("scanner CLASS2", pflag);
			continue;
                }

            case CHARS:
            case ARBITRARY:
            case CCLASS:
            case POSITION:
            case VARIABLE:
                twork = t;
                while (twork) {
                    if (twork.ptype == CHARS) {
                        if (pos >= endstr ||
			    byte(*pos) != twork.ileft)
                            goto cfail;

			pos++;
                        }

                    else if (twork.ptype == ARBITRARY) {
                        if (pos >= endstr  || 
                            *pos == endOfLine)
                            goto cfail;

                        pos++;
                        }

                    else if (twork.ptype == CCLASS) {
                        if (pos >= endstr ||
			    !inrange(byte(*pos), twork.left))
                            goto cfail;

			pos++;
                        }

                    else if (twork.ptype == VARIABLE) {
                        c = variable[(twork.ileft) - 'a'];
                        if (c != 0) 
                            for (c = variable[(twork.ileft) - 'a']; *c; ) 
                                if (pos >= endstr ||
				    *pos++ != *c++)
					goto cfail;
                        }

                    else { /* twork.type == POSITION */
                        if (!posscan(twork.left, &pos, st_start))
				goto cfail;
			}

                    twork = twork.right;
                    }

                pflag = SUCCESS;
                continue;
label	cfail:
                pflag = FAILURE;
                continue;

            default:
		DEBUGS("scanner MAIN SWITCH", t.ptype);
                goto err;
            }
        }
label	err:
    scan_free(Stacksc);
    return(0);
    }

/*
 * This routine translates the pattern into 2 arrays.
 * The first array n contains the translated characters.  All 
 * of the escape characters are removed and any multi character
 * sequences such as octal numbers are converted into there ascii
 * representation.
 * The second array d contains an indictor (true) at any character
 * position for any character that should be interpreted as a 
 * metacharacter.
 */
decipher:	(s: [:] char) boolean =
{
	d:	ref boolean;	/* true if metacharacter.		*/
	n:	ref short;	/* The translated pattern character.	*/
	i, j:	int;
	idx:	int;

	Nextch = n = new [|s + 1] short;
	if (n == 0) 
		return(false);

	Flags = d = new [|s + 1] boolean;
	if (d == 0) {
		delete n;
		return(false);
		}

	idx = 0;
	if (s[0] != ESCCHAR &&
	    s[0] == '^'){
		*n++ = '^';
		*d++ = true;
		idx++;
	}
	while (idx < |s) {
		if (s[idx] != ESCCHAR) {
			*n++ = byte(s[idx]);
			if (special(s[idx]) &&
			    metaflag)
				*d++ = true;
			else
				*d++ = false;
			idx++;
			continue;
			}

		idx++;
		switch (s[idx]) {
			case 't':       *n++ = '\t';	goto gotit;
			case 'b':       *n++ = '\b';	goto gotit;
			case 'r':       *n++ = '\r';	goto gotit;
			case 'n':       *n++ = '\n';	goto gotit;
			case ESCCHAR:   *n++ = ESCCHAR;
label	gotit:
				idx++;
				*d++ = false;
				break;

			case '0': 
			case '1':
			case '2':
			case '3':
				i = 3;
				goto octal;

			case '4':
			case '5':
			case '6':
			case '7':
				i = 2;
label	octal:
				j = s[idx] - '0';
				idx++;
				while(s[idx] >= '0' &&
				      s[idx] <= '7' &&
				      i--){
					j = j * 8 + s[idx] - '0';
					idx++;
					}

				*n++ = j;
				*d++ = false;
				break;

			case '\0':
				break;

			default:
				*n++ = byte(s[idx]);
				if (special(s[idx]) &&
				    !metaflag)
					*d++ = true;
				else
					*d++ = false;
				idx++;
				break;
			}
		}

	*n = EOS;
	*d = false;
	return(true);
	}

gettoken:	(stack: ref pstack, last: short) short = {
	cc:		ref char;
	onoff:		char;
	m, n, ind:		short;
	c, k:	int;
	ccval:		ref pnode;
	save:		ref pnode;

	ind         = Indexsc;
	stack.term = true;
	c           = Nextch[ind];

	/* If any of these were the last token returned, 		*/
	/* don't put it in CAT operator.				*/
	if (last == END  ||
	    last == OPEN ||
	    last == ALT  ||
	    last == CAT  ||
	    last == ASSIGN)
		goto ok;

	/* If any of these are next, don't put in CAT operator 		*/
	if (c == EOS   ||
	    Flags[ind] &&
	   (c == '*'   ||
	    c == '+'   ||
	    c == '{'   ||
	    c == '|'   ||
	    c == ')'))
		goto ok;

	/* Put in the CAT operator on a trailing $, but not otherwise */
	if (Flags[ind] &&
	    c == '$'){
		if (Nextch[ind + 1] != EOS)
			goto ok;
		}

	/* Put in CAT operator */
	return(CAT);

label	ok:
	if (c == EOS)
		return(END);

	if (!Flags[ind]) {
		stack.newval = c;
		stack.val = 0;
		Indexsc++;
		return(CHARS);
		}

	Indexsc = ++ind;
	switch (c) {
		case '*':
			if (shortmatch == true) {
				n = 0;
				m = -1;
				goto REPS;
				}
			else {
				n = -1;
				m = 0;
				goto REPS;
				}

		case '+':
			if (shortmatch == true) {
				n = 1;
				m = -1;
				goto REPS;
				}
			else {
				n = -1;
				m = 1;
				goto REPS;
				}

		case '{':
			n = getint(&ind);
			if (Nextch[ind] == ',') {
				ind++;
				m = getint(&ind);
				}
			else 
				m = n;

			if (Nextch[ind++] != '}') 
				return(-1);

			Indexsc = ind;

label	REPS:
			if (n < 0 &&
			    m < 0) 
				return(-1);

			stack.val = getpnode();
			if (stack.val == 0)
				return(-1);

			/* lower limit must be on left, upper limit on right */
			if (n < 0  ||
			   (m >= 0 &&
			    m < n)) {
				stack.val.ileft  = m;
				stack.val.iright = n;
				return(REP1);
				}

			stack.val.ileft  = n;
			stack.val.iright = m;
			return(REP2);

		case '|':
			return(ALT);

		case '$':
			if	(Nextch[ind] == EOS){
				/* now, for ranges of positions */
				/* ccval points to the next node to be filled */
				ccval = getpnode();
				if (ccval == 0)
					return(-1);

				save = ccval;
				ccval.right = 0;
				ccval.ileft = -1;
				ccval.alter = -1;
				stack.val = save;
				stack.newval = 0;
				return(POSITION);
				}
			return(ASSIGN);

		case '^':
			/* now, for ranges of positions */
			/* ccval points to the next node to be filled */
			ccval = getpnode();
			if (ccval == 0)
				return(-1);

			save = ccval;
			ccval.right = 0;
			ccval.ileft = 0;
			ccval.alter = 0;
			stack.val = save;
			stack.newval = 0;
			return(POSITION);

		case '<':
			/* The code here is a little complicated since the */
			/* syntax is a bit involved.  If this is a variable*/
			/* reference, the allowable characters after the < */
			/* are a-z or A-Z, so life is easy for that case.  */
			/* Otherwise, you expect a comma-separated list of */
			/* possible positions or range of positions.  If   */
			/* the first character of a position is ~ then the */
			/* position is to be counted from the end of the   */
			/* string					   */
			n = Nextch[ind++];
			if (isupper(n))
				n = tolower(n);

			/* handle variable reference */
			if (islower(n)) {
				if (Nextch[ind++] != '>') 
					return(-1);

				Indexsc       = ind;
				stack.newval = n;
				return(VARIABLE);
				}

			/* now, for ranges of positions */
			/* ccval points to the next node to be filled */
			ccval = getpnode();
			if (ccval == 0)
				return(-1);

			save = ccval;
			/* restore ind before going into loop */
			ind = Indexsc;
			for (;;) {
				ccval.right = 0;
				if (!getpos(&ind, &n)) {
					freerange(save);
					return(-1);
					}

				k = Nextch[ind++];
				if (k == '-') {
					if (!getpos(&ind, &m)) {
						freerange(save);
						return(-1);
						}

					/* make <2-4> be col 2 thru 4	*/
					if (m > 0)
						m++;

					k = Nextch[ind++];
					}

				else
					m = n;

				ccval.ileft = n;
				ccval.alter = m;
				if (k == '>')
					break;

				if (k != ',') { 
					freerange(save);
					return(-1);
					}

				ccval.right = getpnode();
				ccval        = ccval.right;
				}

			Indexsc    = ind;
			stack.val = save;
			stack.newval = 0;
			return(POSITION);

		case '[':
			/* The code here is complicated.  Part of the problem */
			/* is that the rules for forming a character class are*/
			/* complicated.  The things to remember are:          */ 
			/*	1)  a circumflex ^ first indicates that that  */
			/*	    character class is negated.		      */ 
			/*	2)  a close bracket ] first (after a possible */
			/*          leading ^) is treated as a regular	      */
			/*          character.  Otherwise it ends the         */
			/*          character class.			      */
			/*	3)  a minus - either first (after a possible  */
			/*          leading ^) or last (before the closing ]) */
			/*	    is treated as a regular character.        */
			/*	    Also, a minus after a minus is treated as */
			/*          a regular character.		      */
			/*          Otherwise it indicates a range of         */
			/*          characters.  Normally the first           */
			/*          character will be less than the second.   */
			/*				                      */
			/* I form a Boolean array 256 long (one for each      */
			/* character).  I then go through the character class */
			/* specification and at the end of the pass through,  */
			/* the array will have ones corresponding to          */
			/* included characters and otherwise zeros.  Then I   */
			/* generate nodes for the individual ranges           */
			/* represented in the array.			      */ 
			cc = new [256] char;
			if (cc == 0)
				return(-1);

			if (Nextch[ind] == '^') {
				for (n = 1; n < 256; n++)
					cc[n] = true;

				ind++;
				onoff = false;
				}
			else {
				for (n = 1; n < 256; n++) 
					cc[n] = false;

				onoff = true;
				}

			for (;;) {
				n = Nextch[ind++];

label	gotn:
				if (n == EOS) {
					delete cc;
					return(-1);
					}

				cc[n] = onoff;

				/* look ahead one character */
				m = Nextch[ind++];
				if (m == ']') 
					break;

				if (m == '-') {
					/* look ahead another character */
					m = Nextch[ind++];
					if (m != ']') {
						/* minus sign indicates range */ 
						/* of characters              */
						while (n < m) 
							cc[++n] = onoff;

						while (n > m) 
							cc[--n] = onoff;

						/* take care of ] right after */
						/* range of characters        */
						if (Nextch[ind++] == ']')
							break;

						ind--;
						}
					else {
						/* minus sign was last before ] */
						cc['-'] = onoff;
						break;
						}
					}
				else {
					/* already looked ahead so have     */
					/* next n value                     */
					n = m;
					goto gotn;
					}
				}

			Indexsc = ind;
			ccval   = getpnode();
			/* ccval constantly points to the next node to be  */
			/* filled.  At the end, ccval must be freed since  */
			/* it is a useless node. 			   */
			ccval.right = 0;
			save = ccval;
			for (n = 1; n < 256; ) {
				while (n < 256 && !cc[n]) 
					n++;	  /* skip over false      */

				if (n == 256) 
					break;

				for (m = n + 1; m < 256 && cc[m]; m++) 
					;

				ccval.right         = getpnode();
				ccval.right.parent = ccval;
				ccval.ileft         = n;
				ccval.alter         = m - 1;
				ccval                = ccval.right;
				ccval.right         = 0;
				n                    = m;
				}

			if (save.right == 0)
				save = 0;

			else
				ccval.parent.right = 0;

			freepnode(ccval);
			stack.val = save;
			stack.newval = 0;
			delete cc;
			return(CCLASS);

		case '(':
			return(OPEN);

		case ')':
			return(SR_CLOSE);

		case '.':
			stack.newval = 0;
			return(ARBITRARY);

		default:
			return(-1);
		}
	}
/* tests ranges for character classes */
inrange:	(c: short, t: ref pnode) boolean = {

	/* this requires that ranges are in numerical order	 	*/
	if (c == endOfLine) 
		return(false);

	while (t) {
		if (c < t.ileft)
			return(false);	  		/* lower limit	*/

		if (c <= t.alter)
			return(true);		   	/* upper limit	*/

		t = t.right;
		}

	return(false);
	}

posscan:	(t: ref pnode, posadr: ref ref char, 
				subject: [:] char) boolean =
{
	pos:		ref char = *posadr;
	endstr:		ref char = subject + |subject;
	c:		ref char;
	slen, bplace, 
		eplace, 
		first, 
		second, 
		i:	short;

	i      =  0;
	eplace = -1;
	bplace =  0;
	for (c = subject; c < endstr && *c != endOfLine; c++) {
		if (c == pos)
			bplace = i;

		if (*c == '\t') 
			i = (i + 8) & ~7;		 /* tab stop */
		else 
			i++;

		if (c == pos)
			eplace = i - 1;
		}

	slen = i;
	if (eplace < 0) {
		/* in case pos was out of range */
		bplace = i;
		eplace = i;
		}

	/* At this point, slen has how long the string is, bplace has 	*/
	/* the character position from which to begin, and eplace has 	*/
	/* the character position from which to end.			*/
	while (t) {
		first  = t.ileft;
		second = t.alter;
		if (first < 0) 
			first = slen + 1 + first;

		if (second < 0)
			second = slen + 1 + second;

		if (first < second) {
			if (first  <= eplace && 
			    bplace <= second) {
				*posadr += (second - first);
				return(true);
				}
			}
		else {
			if (second <= eplace &&
			    bplace <= first)  {
				*posadr += (first - second);
				return(true);
				}
			}

		t = t.right;
		}

	return(false);
	}
*/
}

/* This is the structure of a compiled pattern.				  */
class pnode {
	ref<pnode> parent;	/* parent pointer 				  */
	ref<pnode> left;		/* left  operand pointer			  */
	ref<pnode> right;	/* right operand pointer 			  */
	pointer<byte> asgpos;    /* the assigned postion			  */
	pointer<byte> asgstr;    /* the saved assign string.		  */
    short	alter;       /* alternative count                     	  */
	short ileft;	     /* left integer				  */
	short iright;       /* right integer 				  */
	ParseTokens ptype;        /* type field 				  */
}


/* LIST OF TOKENS							*/
enum ParseTokens {

	END,
	ALT,                    /* alternation 				*/
	CAT,                    /* concatenation 			*/
	ASSIGN,                 /* assignment 				*/
	REP1,                   /* repetition count type 1 		*/
	REP2,                   /* repetition count type 2 		*/
	CHARS,                  /* characters 				*/
	CCLASS,                 /* character class 			*/
	ARBITRARY,              /* arbitrary 				*/
	POSITION,               /* position from beginning of string 	*/
	VARIABLE,               /* variable 				*/
	OPEN,                   /* ( 					*/
	SR_CLOSE,               /* ) 					*/

/*
 *  The above token values are used as indices into the precedence functions
 *  to determine when reductions should occur.  They are also used during
 *  scanning as the node type.
 *
 *  The following are not returned by gettoken(), but are node types used
 *  during scanning.
 */
	CHARS1,                 /* CHARS repetition count type 1 	*/
	CHARS2,                 /* CHARS repetition count type 2 	*/
	CCLASS1,                /* CCLASS repetition count type 1 	*/
	CCLASS2,                /* CCLASS repetition count type 2 	*/
	ARB1,                   /* ARB repetition count type 1 		*/
	ARB2,                   /* ARB repetition count type 2 		*/
	RESTORE,                /* special value for FAILURE in scanning*/
}
/*
/* MACROS FOR EASY REFERENCE FOR REPLICATIONS */
LOWER:	(t: ref pnode) short = { return    t.right.ileft; }
UPPER:	(t: ref pnode) short = { return    t.right.iright; }
BEGIN:	(t: ref pnode) ref char = { return t.right.asgpos; }
setBEGIN:	(t: ref pnode, c: ref char) = { t.right.asgpos = c; }

FAILURE:	const int = 0;
SUCCESS:	const int = 1;
FIRST:		const int = 2;
EOS:		const char = '\0';
ESCCHAR:	const char = '\\';
GETNODE:	const int = 20;	/* The number of nodes to malloc each time.*/
SR_MAX_REP_BUF:	const int = 1000;
				/* The size of the temperary buffer to hold*/
				/* the new string while a search and 	   */
				/* replace is taking place.		   */
*/
//@Constant
boolean SR_DEBUG = false;				/* Set this to true to enable debugging */

short Kntnode = 0;
/*
TYPES:	const int = 19;



Restore:	pnode = [
    null,   null,   null,   null,   null,  0,  0,  0,  RESTORE,
    ] ;

/* This is the structure of a parse stack entry.			*/
pstack:	type { public:
	ptype:	char; 		/* type of stack entry (token type) 	*/
	term:	boolean;  	/* terminal or not 			*/
	newval:	short;		/* character value from gettoken()	*/
	val:	ref pnode;   	/* pointer to value 			*/
    	};

/* This is the pointer to the top of the scanning stack saved by generators */
Stacksc:	ref pnode;	/* The stack for the scanner.		*/
Nextch:		ref short;	/* A processed copy of the pattern.	*/
Flags:		ref boolean;	/* A set of flags that goes with Nextch.*/
Indexsc:	short;		/* Index into the string being complied.*/

/*
 * Do a search on the input buffer.
 * Return the next position in str after the matched pattern.
 * Raises RegularExpressionTrap on error.
 */
sr_s:	public	(str: [:] char, pat: [:] char) ref char =
{

	found:	[:] char;	/* Where in str the match was found.	*/
	p:	ref searchPattern = new searchPattern[ ];
				/* The compiled pattern.		*/

	p compile(pat);
	try	{
		found = p search(str);
		delete p;
		return &found[|found];
		}
	except	{
		delete p;
		continue;
		}
	}


/*
 * Do a search and a replace once on the input buffer.
 */
sr_sr:	public	(str: [:] char, /* The input string to do the search on.*/
		 pat: [:] char, /* The pattern to search for.		*/
		 sub: [:] char) /* The replacement string.		*/
		 [:] char =
{

	found:	[:] char;	/* Where in str the match was found.	*/
	buf:	[:] char;	/* Buffer for the changed string.	*/
	p:	ref searchPattern = new searchPattern[ ];
				/* The compiled pattern.		*/

	p compile(pat);
	try	{
		found = p search(str);
		}
	except	{
		delete p;
		continue;
		}
	buf = p replace(str, found, sub);
	delete p;
	return buf;
	}

/*
 * Do a search and a replace globally on the input buffer.
 * Return the number of patterns that were matched in the string.
 * This function assumes that there is enough room in the str argument to
 * hold the results.
 */
sr_srg:	public	(str: [:] char,	/* The input string to do the search on.*/
		 pat: [:] char, /* The pattern to search for.		*/
		 sub: [:] char, /* The replacement string.		*/
		 num_found: ref int) /* The number of matches           */
		 [:] char =
{

	found:	[:] char;	/* Where in str the match was found.	*/
	buf:	[:] char;	/* Buffer for the changed string.	*/
	p:	ref searchPattern = new searchPattern[ ];
				/* The compiled pattern.		*/

	p compile(pat);
	str = stringDup(str);
	*num_found = 0;
	for	(;;){
		try	{
			found = p search(str);
			buf = p replace(str, found, sub);
			delete p;
			delete str;
			str = buf;
			(*num_found)++;
			}
		except	{
			delete p;
			return str;
			}
		}
	}

/*
 * Do a search on the input buffer.
 * Return the next position in str after the matched pattern.
 */
sr_cs:	public	(str: [:] char, p: ref searchPattern) ref char =
{

	found:	[:] char;	/* Where in str the match was found.	*/

	found = p search(str);
	return(&found[|found]);
	}


/*
 * Do a search and a replace once on the input buffer.
 */
sr_csr:	public	(str: [:] char, p: ref searchPattern, 
						sub: [:] char) [:] char =
{
	found:	[:] char;	/* Where in str the match was found.	*/
	buf:	[:] char;	/* Buffer for the changed string.	*/

	found = p search(str);
	return p replace(str, found, sub);
	}

/*
 * Do a search and a replace globally on the input buffer.
 * Return the number of patterns that were matched in the string.
 */
sr_csrg:	public	(str: [:] char, p: ref searchPattern, 
			 sub: [:] char, num_found: ref int) [:] char =
	{
	found:	[:] char;	/* Where in str the match was found.	*/
	buf:	[:] char;	/* Buffer for the changed string.	*/

	*num_found = 0;
	str = stringDup(str);
	for	(;;){
		try	{
			found = p search(str);
			buf = p replace(str, found, sub);
			delete str;
			str = buf;
			(*num_found)++;
			}
		except	{
			return str;
			}
		}
	}

/*
 *	This frees the memory allocated by scanner()
 */
scan_free:	(point: ref pnode) =
{
	tree:	ref pnode;
	t:	ref pnode;

	/* Check for NULL value.					*/
	if (point == 0)
		return;

	tree = point;
	while (tree != 0) {
		t = tree.parent;
		freepnode(tree);
		tree = t;
		}

	return;
	}

*/
/*
 *	This frees the memory allocated by sr_compile()
 */
void sr_free_re(ref<pnode> point) {
	ref<pnode> tree;

	/* Check for NULL value.					*/
	if (point == null)
		return;

	tree = point;
	freepnode(tree);
	switch (tree.ptype) {
	case ASSIGN:
		sr_free_re(tree.left);
		break;

	case ALT:
	case CAT:
		sr_free_re(tree.left);
		sr_free_re(tree.right);
		break;

	case REP1:
	case REP2:
		sr_free_re(tree.left);
		freepnode(tree.right);
		break;

	case CHARS1:
	case CHARS2:
	case ARB1:
	case ARB2:
		freepnode(tree.right);
		break;

	case CCLASS1:
	case CCLASS2:
		freepnode(tree.right);
		freerange(tree.left);
		break;

	case CHARS:
	case ARBITRARY:
	case CCLASS:
	case POSITION:
	case VARIABLE:
		for (;;) {
			if (tree.ptype == ParseTokens.CCLASS ||
			    tree.ptype == ParseTokens.POSITION)
				freerange(tree.left);

			tree = tree.right;
			if (tree == null)
				break;

			freepnode(tree);
		}
		break;

	default:
		DEBUGS("sr_free_re", short(tree.ptype));
		break;
	}
}

/*
/*
 *   The parsing scheme uses an operator precedence grammar.
 *
 *   In the following comments the productions, precedence matrix, and
 *   precedence functions are listed.
 *
 *   The scanning scheme is a backtracking one which remembers where
 *   earlier alternatives were chosen. If the match should fail,
 *   the algorithm can retreat back to the last place where a different
 *   alternative could have been selected and try again.
 *
 *   For a description of how backtracking works, the SNOBOL and ICON
 *   programming languages are excellent instructors in the use of
 *   backtracking, particularly in string analysis.
 *
 *   LIST OF PRODUCTIONS
 *
 *	Production               Number             Schematic
 *
 *	OR      OR | AND            0                 N | N
 *	        AND
 *	AND     AND & UNARY         1                 N & N
 *	        UNARY
 *	UNARY   UNARY *      --
 *	        UNARY +        |--  2                 N REP-COUNT-1
 *	        UNARY {n,}     |--  3                 N REP-COUNT-2
 *	        UNARY {n}      |                      (whether 2 or 3 depends
 *	        UNARY {,m}     |                      on n compared to m)
 *	        UNARY {n,m}  --
 *	        UNARY $ CHARS       4                 N $ CHARS
 *	        TERM
 *	TERM    ( OR )              5                 ( N )
 *	        CHARS               6                 CHARS
 *	        CHAR-CLASS          7                 CHAR-CLASS
 *	        ARBITRARY           8                 ARBITRARY
 *	        POSITION            9                 POSITION
 *	        VARIABLE           10                 VARIABLE
 *
 *	Precedence Matrix
 *	    R1 = REP-COUNT-1
 *	    R2 = REP-COUNT-2
 *	    C  = CHARS
 *	    CC = CHAR-CLASS
 *	    A  = ARBITRARY
 *	    P  = POSITION
 *	    V  = VARIABLE
 *
 *	         2  4  6  6  6  6  6  6  6  6  6  1
 *	         |  &  $  R1 R2 C  CC A  P  V  (  )
 *	3   |    >  <  <  <  <  <  <  <  <  <  <  >
 *	5   &    >  >  <  <  <  <  <  <  <  <  <  >
 *	6   $                   =
 *	7   R1   >  >  >  >  >                    >
 *	7   R2   >  >  >  >  >                    >
 *	7   C    >  >  >  >  >                    >
 *	7   CC   >  >  >  >  >                    >
 *	7   A    >  >  >  >  >                    >
 *	7   P    >  >  >  >  >                    >
 *	7   V    >  >  >  >  >                    >
 *	1   (    <  <  <  <  <  <  <  <  <  <  <  =
 *	7   )    >  >  >  >  >                    >
 *
 */

/* PRECEDENCE FUNCTIONS 					   */
/*                  END |  &  $  R1 R2 C  CC A  P  V  (  )         */
ff:	[] char  = [ 0, 3, 5, 6, 7, 7, 7, 7, 7, 7, 7, 1, 7, ] ;
gg:	[] char  = [ 0, 2, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 1, ] ;

/* ENCODING OF PRODUCTIONS */

/* Productions are reversed because the stack works from the most	*/
/* recently pushed at the top.  Comparisons are done from the top of 	*/
/* the stack down in order to get a reduction.			       	*/
/*									*/
/* In the N arrays, 0 signifies a non-terminal position.		*/
/*                  1 signifies a terminal position.			*/
/* In the M arrays, 0 fills in non-terminal positions.			*/
/*                  the terminal needed for the particular production	*/
/*		    is in the terminal position.			*/
/* The last entry in both the N and M arrays is a dummy value that	*/
/* facilitates searching for which reduction to apply.			*/
N00:	[] char = [0, 1, 0, 1, ];
M00:	[] char = [0, ALT, 0, 0, ] ;
N01:	[] char = [0, 1, 0, 1, ];
M01:	[] char = [0, CAT, 0, 0, ] ;
N02:	[] char = [1, 0, 1, ];
M02:	[] char = [REP1, 0, 0, ] ;
N03:	[] char = [1, 0, 1, ];
M03:	[] char = [REP2, 0, 0, ] ;
N04:	[] char = [1, 1, 0, 1, ];
M04:	[] char = [CHARS, ASSIGN, 0, 0, ] ;
N05:	[] char = [1, 0, 1, 1, ];
M05:	[] char = [SR_CLOSE, 0, OPEN, 0, ] ;
N06:	[] char = [1, 1, ];
M06:	[] char = [CHARS, 0, ] ;
N07:	[] char = [1, 1, ];
M07:	[] char = [CCLASS, 0, ] ;
N08:	[] char = [1, 1, ];
M08:	[] char = [ARBITRARY, 0, ] ;
N09:	[] char = [1, 1, ];
M09:	[] char = [POSITION, 0, ] ;
N10:	[] char = [1, 1, ];
M10:	[] char = [VARIABLE, 0, ] ;

SR_STACK:	const	int =   20;              /* size of stack */
NPROD:		const	int =   11;

prod:	[NPROD] { public:
	terms:	ref char;
	types:	ref char;
    	} = [
        [N00,    M00],            /* N | N => N */
        [N01,    M01],            /* N & N => N */
        [N02,    M02],            /* N R1  => N */
        [N03,    M03],            /* N R2  => N */
        [N04,    M04],            /* N $ C => N */
        [N05,    M05],            /* ( N ) => N */
        [N06,    M06],            /* C     => N */
        [N07,    M07],            /* CC    => N */
        [N08,    M08],            /* A     => N */
        [N09,    M09],            /* P     => N */
        [N10,    M10],            /* V     => N */
        ] ;
*/
private ref<pnode> pfree = null;      /* beginning of list of free nodes 	*/
/*
/*
 *	We can normally alloc nodes that have been previously freed.
 *	Previously freed nodes are on the stack pointed to by pfree.
 *	If we don't have any nodes in pfree then we will malloc GETNODE
 *	nodes at once.  This is much faster then having to malloc 
 *	each node separatly.
 */
getpnode:	() ref pnode = {

	t:	ref pnode;
	i:	int;

	if (pfree == 0) {
		if	(SR_DEBUG){
			printf("getting nodes\n");
			Kntnode += GETNODE;
			}
		pfree = new [GETNODE] pnode;
		if (pfree == 0) 
			fatal("no memory in parsing");

		for (i = 0; i < GETNODE - 1; i++)
			pfree[i].parent = &pfree[i+1];

		pfree[GETNODE - 1].parent = 0;
		}

	t         = pfree;
	pfree     = pfree.parent;
	t.parent = 0;
	t.asgstr = 0;
	if	(SR_DEBUG)
		Kntnode--;
	return(t);
	}
*/
/*
 * 	Note that freed nodes are not actually returned to the memory cache.
 *	Note also that the values are not affected except for the parent 
 *	pointer so that in particular, the left and right values may be used.
 *
 *	We free the nodes to a stack of free nodes which pnode() will then
 *	allocate from.  This is considerably faster then calling free()
 *	and then malloc() each time a node is freed and realloced.
 */
void freepnode(ref<pnode> p) {
/*      WARNING!!!!  Havoc will result if you free the same 		 */
/*	node twice.  A simple check helps prevent this.			 */

	ref<pnode> t;

	if (p == null)
		return;

	for (t = pfree; t != null; t = t.parent)
		if (t == p)
			return;

	p.parent = pfree;
	pfree     = p;
	if	(SR_DEBUG) {
		Kntnode++;

	    	short i;

		t = pfree;
		for (i = 0; i < Kntnode; i++)
			t = t.parent;

		if (t != null)
			fatal("the free list is corrupted");
	}
}

/* freerange(tree) frees ranges for CCLASS and POSITION nodes */
void freerange(ref<pnode> tree) {
	while (tree != null) {
		freepnode(tree);
		tree = tree.right;
	}

	return;
}
/*
special:	(c: short) boolean = {

	if (stringScan(".[*()|$+<{", c) >= 0)
		return(true);

	return(false);
	}


/*
 * getint is similar to atoi but is special purpose and updates indices 
 */
getint:	(indpt: ref short) short =
{
	i:	short;

	if (!isdigit(Nextch[*indpt]))
		return(-1);

	i = 0;
	while (isdigit(Nextch[*indpt]))
		i = 10 * i + Nextch[(*indpt)++] - '0';

	return(i);
	}

/*      getpos gets a position entry.  If ~ is first, it is from the end.
 *	0 value is beginning of string and working forward.
 *	-1 value is end of string working backward.
 */
getpos:	(indpt: ref short, valpt: ref short) boolean =
{
	flag:	short	= false;

	if (Nextch[*indpt] == '~') {
		(*indpt)++;
		flag = true;
		}

	*valpt = getint(indpt);
	if (*valpt < 0)
		return(false);

	if (flag)
		*valpt = -1 - *valpt;		 /* from the end */

	return(true);
	}

/* normal push */
push:	(t: ref pnode, pos: ref char) boolean =
{
	xnew:	ref pnode;

	xnew = getpnode();
	if (xnew == 0)
		return(false);

	xnew.parent = Stacksc;
	xnew.left   = t;
	xnew.right  = ref pnode(pos);
	xnew.alter  = t.alter;
	xnew.asgstr = t.asgstr;
	if	(SR_DEBUG){
		xnew.ptype   = t.ptype;
		xnew.ileft  = t.ileft;
		xnew.iright = t.iright;
		xnew.asgpos = t.asgpos;
		}
	Stacksc     = xnew;
	return(true);
	}

/* push RESTORE */
pusher:	(t: ref pnode) boolean =
{
	xnew:	ref pnode;

	xnew = getpnode();
	if (xnew == 0)
		return(false);

	xnew.parent = Stacksc;
	xnew.left   = &Restore;
	xnew.right  = t;
	xnew.alter  = t.alter;
	xnew.asgstr = t.asgstr;
	if	(SR_DEBUG){
		xnew.ptype   = t.ptype;
		xnew.ileft  = t.ileft;
		xnew.iright = t.iright;
		xnew.asgpos = t.asgpos;
		}
	Stacksc     = xnew;
	return(true);
	}

pop:	(t: ref ref pnode) ref char =
{
	old:	ref pnode;
	c:	ref char;

	old = Stacksc;
	if (old == 0) {
		*t = 0;
		return(0);
		}

	*t          = old.left;
	(*t).alter = old.alter;
	c           = ref char(old.right);
	Stacksc     = old.parent;
	freepnode(old);
	return(c);
	}

*/
/* 
 *	This routine is called in case of fatal error,
 *	including out of memory.
 */
void fatal(string s) {
	printf("%s\n", s);
}
/*
/* the following is the debugging code.					*/
indexx:	[TYPES] ref char = [
	"END",
	"ALT",
	"CAT",
	"ASSIGN",
	"REP1",
	"REP2",
	"CHARS",
	"CCLASS",
	"ARBITRARY",
	"POSITION",
	"VAR",
	"OPEN",
	"CLOSE",
	"CHARS1",
	"CHARS2",
	"CCLASS1",
	"CCLASS2",
	"ARB1",
	"ARB2",
	] ;

stack_prn:	(call_from: ref char) =
{
	xnew:	ref pnode;

	printf("\n%-10s address type     left     right    il ir al asgpos\n", call_from);

	xnew = Stacksc;
	while (xnew != 0) {
		printf("         %p %-6s %p %p %2d %2d %2d %s\n",
			xnew,
			indexx[xnew.ptype],
			xnew.left,
			xnew.right,
			xnew.ileft,
			xnew.iright,
			xnew.alter,
			xnew.asgpos);
		xnew = xnew.parent;
		}

	return;
	}


/* the following is parse stack tracing for debugging purposes      */
stackp:	(stack: ref pstack, nstack: short) = {

	i:	short;

	for (i = 0; i <= nstack; i++) {
		if (stack[i].term) {
			if (stack[i].ptype >= 0 && 
			    stack[i].ptype <= TYPES)
				printf("%s\n", indexx[stack[i].ptype]);
			else
				printf("undefined terminal %d\n", stack[i].ptype);
			}

		else 
			printf("non-terminal\n");
		}

	putchar('\n');
	}

/*
 *	This routine will print out the parse tree.
 *	For debugging call this routine with p = 0, indent = 0,
 *	and the regular expression returned from sr_compile()
 *	in tree.
 */
sr_treep:	public	(tree: ref pnode, p: ref pnode, indent: short) = {

	i:	short;

	if (tree == 0)
		return;

	for (i = 0; i < indent; i++) 
		putchar(' ');

	if (tree.ptype >= 0   && 
	    tree.ptype <= TYPES)
		printf("%s", indexx[tree.ptype]);
	else
		printf("unrecognized type: %d", tree.ptype);

	if (tree.parent != p)
		printf("  parent mismatch");

	switch (tree.ptype) {
		case ALT: case CAT:
			putchar('\n');
			sr_treep(tree.left, tree, indent+4);
			sr_treep(tree.right, tree, indent+4);
			break;

		case ASSIGN:
			printf("   %c\n", tree.iright);
			sr_treep(tree.left, tree, indent+4);
			break;

		case CHARS:
		case ARBITRARY:
		case CCLASS:
		case POSITION:
		case VARIABLE:
			for (;;) {
				if (tree.ptype == CHARS) {
					printf("   ");
					while (tree                &&
					       tree.ptype == CHARS) {
						printf("%c", tree.ileft);
						tree = tree.right;
						}

					if (tree == 0)
						break;

					printf("\n%*s%s", indent, "",
						          indexx[tree.ptype]);
					continue;
					}

				printf("   ");
				if (tree.ptype == CCLASS)
					rangep(tree.left);

				else if (tree.ptype == ARBITRARY)
					printf(" ARB ");

				else if (tree.ptype == POSITION)
					for (p = tree.left; ; ) {
						printf(" %d %d", p.ileft, p.alter);
						p = p.right;
						if (p == 0) 
							break;

						printf(" OR ");
						}

				else /* tree.ptype == VARIABLE */
					printf("   %c", tree.ileft);

				tree = tree.right;
				if (tree == 0) 
					break;

				printf("\n%*s%s", indent, "", 
						  indexx[tree.ptype]);
				}

			putchar('\n');
			break;

		case CHARS1:
		case CHARS2:
			printf("	%c  %d  %d\n",
				tree.ileft, LOWER(tree), UPPER(tree));
			break;

		case CCLASS1:
		case CCLASS2:
			rangep(tree.left);
			printf("	%d  %d\n", LOWER(tree), UPPER(tree));
			break;

		case ARB1:
		case ARB2:
			printf("	%d  %d\n", LOWER(tree), UPPER(tree));
			break;

		case REP1:
		case REP2:
			printf("	%d  %d\n", LOWER(tree), UPPER(tree));
			sr_treep(tree.left, tree, indent+4);
			break;

		default:
			putchar('\n');
			break;
		}
	}

rangep:	(t: ref pnode) =
{
	while (t) {
		putchar(' ');
		pp(t.ileft);
		putchar('-');
		pp(t.alter);
		t = t.right;
		}

	return;
	}

pp:	(i: short) = {

	if (i < 0)
		printf("NEGATIVE");

	else if (i < '!')
		printf("\\%03o", i);

	else if (i < 256)
		printf("%c", i);

	else
		printf("%d", i);

	return;
	}

private void DEBUGS(string cp, short val) {
	printf("switch default error in %s with value <%d>\n", cp, val);
	return;
	}