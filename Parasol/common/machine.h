#ifndef COMMON_MACHINE_H
#define COMMON_MACHINE_H
#include <math.h>
#include "string.h"

#define null 0
#define dimOf(a) (sizeof(a)/sizeof(a[0]))

typedef unsigned char byte;

/*
 *	disableMessages
 *
 *	This will cause fatalMessage and warningMessage to NOT put up
 *	an interactive window.  fatalMessage will still exit with a code
 *	of 1.  warningMessage will become a no-op.
 */
void disableMessages();

void fatalMessage(const string& s);

void warningMessage(const string& s);

void debugPrint(const string& s);

void setRbp(void *newValue);

const float sqrt3 = float(sqrt(3.0));

/*
 *	The appropriate way to test for equality is:
 *
 *		if (result == EQUAL)
 *
 *	In general, for any comparison operator, op,
 *	the correct construct is:
 *
 *		if (result op EQUAL)
 *
 *	thus, testing for greater than or equal to
 *	use:
 *
 *		if (result >= EQUAL)
 */
enum compareResult_t {
	LESS = -1,
	EQUAL = 0,
	GREATER = 1,
};

typedef long long Milliseconds;

Milliseconds millisecondMark();
#endif  // COMMON_MACHINE_H
