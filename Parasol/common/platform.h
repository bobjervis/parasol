/*
 *	Platofrm specific common declarations
 */
#ifdef _MSC_VER
#ifdef _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>

#ifndef DEBUG_NEW
#define DEBUG_NEW new(_NORMAL_BLOCK, __FILE__, __LINE__)
#define new DEBUG_NEW
#endif
#endif
#endif

namespace platform {
/*
 * Performs platform-specific setup such as initializing
 * memory leak detection when needed.
 */
void setup();

}

