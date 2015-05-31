#include "platform.h"

#include <windows.h>

namespace platform {

void setup() {
#ifdef _MSC_VER
#ifdef _CRTDBG_MAP_ALLOC
	_CrtSetDbgFlag ( _CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF );
	HANDLE hLogFile;
	hLogFile = CreateFile("memleak.txt", GENERIC_WRITE, FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	_CrtSetReportMode(_CRT_WARN, _CRTDBG_MODE_FILE);
	_CrtSetReportFile(_CRT_WARN, hLogFile);
#endif
#endif
}

}
