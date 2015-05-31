#include	<stdio.h>

int	p_setvbuf(FILE *f, char *buf, size_t sz)
	{
	if	(sz)
		setvbuf(f, buf, _IOFBF, sz);
	else
		setvbuf(f, buf, _IONBF, sz);
	}

int	p_getClass(FILE *f)
	{
	return 0;
	}

FILE	*p_cStream(int i)
	{
	switch	(i){
	case	0:		return stdin;
	case	1:		return stdout;
	case	2:		return stderr;
	default:		return 0;
		}
	}

