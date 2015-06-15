/*
	Copyright (c) 1993 by Robert Jervis
	All rights reserved.

	Permission to use, copy, modify and distribute this software is
	subject to the license described in the READ.ME file.
 */
/*
	boot.c
	Version 1.0
 */
#include	<stdio.h>
#include	<dos.h>
#include	<dir.h>
#include	<io.h>
#include	<stdlib.h>
#include	<string.h>
#include	<alloc.h>

#define	DEBUGTABLES	16		/* Maximum # of debug tables
						 in a unit. */

#define	RUN_MAGIC	0x8c6a
#define	RUN_VERSION	0x10

#define	G_SVC		0x00
#define	G_GATE		0x01

typedef	struct	{
	unsigned short	magic;
	unsigned char	version;
	unsigned char	_res_;
	unsigned short	cs;
	unsigned short	ds;
	unsigned short	ss;
	unsigned short	_res_2;
	unsigned long	ip;
	unsigned long	sp;
	long		descriptors;
	long		image;
	long		fixups;
	long		gates;
	long		codeLen;
	long		dataInitLen;
	long		dataTotalLen;
	long		externGates;
	long		debugInfo;
	long		codeOffset;
	long		dataOffset;
	long		threadLoc;
	long		symbols;
	long		dataConstLen;
	long		tables[45];
	}	runHeader;

typedef	struct	{
	char		name[9];
	char		nTables;
	unsigned short	flags;
	long		codeOffset;
	long		nextUnit;
	long		tableOffsets[DEBUGTABLES];
	}	debugUnitHeader;

#define	CMOS_PORT	0x70

typedef	unsigned long	paddr_t;
/*
	Some cheesy machine code to avoid inline asm statements.
 */
#define	_idle_()	__emit__(0xeb, 0x00);
#define	fninit()	__emit__(0xdb, 0xe3);
#define	fstswAX()	__emit__(0xdf, 0xe0);
#define	fsetpm()	__emit__(0xdb, 0xe4);
#define	lidt(i)		__emit__(0x0f, 0x01, 0x1e, (char near *)&i);
#define	lgdt(g)		__emit__(0x0f, 0x01, 0x16, (char near *)&g);
#define	pushCX()	__emit__(0x51);
#define	pushDX()	__emit__(0x52);
#define	retf()		__emit__(0xcb);
#define	jumpTo()	__emit__(0xea, 0x00, 0x00, 0x08, 0x00);

long                    addrToLong(void *addr);
unsigned char           getCMOSbyte(int addr);
void                    *readImage(int fd, long, long, long);
void			setMapping(unsigned, unsigned short, paddr_t,
				paddr_t);

#define	PE	1			/* protection enabled */
#define	MP	2			/* monitor processor extension */
#define	EM	4			/* emulate processor extension */

typedef	struct	{
	short	limit;
	long	base;
	}	descriptorReg;

descriptorReg IDT = { 8 * 256 };
descriptorReg GDT = { 8 * 64 };		/* GDT comes after the IDT */

typedef	struct	{
	unsigned short	limit;
	unsigned short	base;
	unsigned char	base16;
	unsigned char	attribute;
	unsigned short	reserved;
	}	descriptor;

void		empty_8042(void);
void		jumpToKernel(void);
void		loadKernel(int, char **);
void		loadRunfile(char *);

runHeader	Rh;

descriptor	*Desc;

unsigned long	Conventional;
unsigned long	Extended;

/*
		ALYS 1.0 boot procedure

		1. Move the ALYS code into low memory.
		2. Build the GDT and the IDT.
		3. Switch to protected mode.
		4. Jump to the startup routine

	Note: for now this is a real mode boot procedure.
 */
main(int argc, char **argv)
	{
	Extended = getCMOSbyte(0x17) + ((unsigned)(getCMOSbyte(0x18)) << 8);
	Conventional = getCMOSbyte(0x15) + ((unsigned)(getCMOSbyte(0x16)) << 8);
	loadKernel(argc, argv);
	jumpToKernel();
	}
/*
	This function loads the kernel and sets up the hardware tables.
 */
void	loadKernel(int argc, char **argv)
	{
	int		fd;
	char		*filename;
	int		i;
	long		image;
	unsigned long	x;

	if	(argc < 2){
		printf(	"Use is: BOOT [ options ] kernel_file\n"
			"\tOptions:\n"
			"\t\t-c#\tConventional Memory Size in Kilobytes\n"
			"\t\t-x#\tExtended Memory Size in Kilobytes\n"
			"Note: Override memory sizes only when default sizes are not correct\n");
		exit(0);
		}
	filename = argv[1];
	argv++;
	argc--;
	while	(argc > 1 && filename[0] == '-'){
		switch	(filename[1]){
		case	'c':
			x = atol(filename + 2);
			if	(x > 640){
				printf("Option specifies too much memory: %s\n",
						filename);
				printf("Conventional memory is limited to 640K\n");
				exit(0);
				}
			else
				Conventional = x;
			break;

		case	'x':
			x = atol(filename + 2);
			if	(x > 0xFFF00000){
				printf("Option specifies too much memory: %s\n",
						filename);
				printf("Extended memory is limited to %luK\n",
						0xFFF00000L);
				exit(0);
				}
			else
				Extended = x;
			}
		filename = argv[1];
		argv++;
		argc--;
		}
	printf("Conventional memory = %luK ", Conventional);
	printf("Extended memory = %luK\n", Extended);
	loadRunfile(filename);
	}
/*
	This function switches to protected mode.  This code was arrived at
	by trial and error.  The transition code from real to protected mode
	is poorly documented, and is incomplete since the IBM PC needs to
	have some io ports poked.  This code seems to work for both 80386 and
	80486 based PC's.  There may be better ways to do this code.
 */
void	jumpToKernel()
	{
	unsigned	*ip;
	int		fpStatus;
	char		**xpp;
	char		*cp;

	disable();
	outportb(0x80, 0x00);			/* clear exception error flag */

		/* gate the a20 line */

	empty_8042();
	outportb(0x64, 0xd1);			/* write output port */
	empty_8042();
	outportb(0x60, 0xdf);			/* 8042 port data */
	empty_8042();


	lidt(IDT);
	lgdt(GDT);
	_SS = Rh.ss;
	__emit__(0x66);				/* Make the assignment 32-bit */
	_SP = Rh.sp;
	__emit__(0x0f, 0x20, 0xc0);	/* mov eax,cr0 */
	_AL |= 1;
	__emit__(0x0f, 0x22, 0xc0);	/* mov cr0,eax */
	_idle_();				/* flush the instruction Queue */
	_DX = Rh.cs;
	pushDX();
	_DX = Rh.codeOffset;
	pushDX();
	retf();
	}

void	empty_8042()
	{
	char		i;
	unsigned	cnt;

	cnt = 0;
	do	{
		i = inportb(0x64);
		cnt--;
		}
		while	((i & 2) && cnt);
	}

void	*RunDesc;
/*
	This function allocates large segments of memory.  It was originally
	designed to load segments on paragraph boundaries, but has been
	modified to round to full 4K pages.
 */
void	*allocBrklvl(long size)
	{
	unsigned	paraSize;
	long		blong;
	long		rem;
	unsigned	bpara;
	unsigned	hpara;
	void		*bp;

	paraSize = (size + 15) >> 4;
	blong = (long)sbrk(0);
	bpara = blong >> 16;
	rem = coreleft();
	hpara = (long)(blong + (rem << 12)) >> 16;
	if	(rem & 0xf)
		hpara++;
	if	((int)blong != 0)
		bpara++;
	bpara += 255;
	bpara &= 0xff00;		/* round to nearest 4K page */
	if	(bpara + paraSize > hpara){
		printf("Not enough room to load image\n");
		exit(1);
		}
	bp = MK_FP(bpara, 0);
	bpara += paraSize;
	brk(MK_FP(bpara, 0));
	return(bp);
	}
/*
	This function loads the kernel Run file and sets up the initial GDT.
	Also, the CS and DS register values are corrected in the Run Header.
	A Run file coming out of the linker sets those registers for LDT
	descriptors, while the kernel will use GDT descriptors.
 */
void	loadRunfile(char *rf)
	{
	int	fd;
	long	i;
	long	j;
	long	fix;
	int	n;
	int	dig;
	int	dc;
	long	*addrp;
	void	*xp;
	char	*cp;
	char	*cp2;
	char	fdrive[MAXDRIVE];
	char	fdir[MAXDIR];
	char	ffile[MAXFILE];
	char	fext[MAXEXT];
	char	fpath[MAXPATH];
	char	**dvp;
	char	**dvpp;

		/* Extension defaults to .RUN */

	n = fnsplit(rf, &fdrive[0], &fdir[0], &ffile[0], &fext[0]);
	if	((n & EXTENSION) == 0){
		fnmerge(&fpath[0], &fdrive[0], &fdir[0], &ffile[0], ".run");
		rf = &fpath[0];
		}

		/* Open the file */

	fd = _open(rf, 0);
	if	(fd < 0){
		printf("Couldn't open file %s\n", rf);
		exit(1);
		}
	i = lseek(fd, 0, 2);
	lseek(fd, 0, 0);
	if	(_read(fd, &Rh, sizeof Rh) != sizeof Rh){
		printf("Couldn't read header for %s\n", rf);
		exit(1);
		}
	if	(Rh.magic != RUN_MAGIC){
		printf("Runfile magic number is not correct in %s\n", rf);
		exit(1);
		}

	lseek(fd, Rh.image, 0);
	cp = readImage(fd, Rh.codeLen, Rh.codeLen, Rh.codeOffset);
	cp2 = readImage(fd, Rh.dataInitLen, Rh.dataTotalLen, Rh.dataOffset);
	Desc = (descriptor *)((char huge *)cp2 + Rh.sp) + 256;
	IDT.base = addrToLong(cp2) + Rh.sp;
	GDT.base = IDT.base + IDT.limit;
	GDT.limit = Rh.dataTotalLen - Rh.sp - 0x801;
	Rh.cs = 8;
	Rh.ds = 0x10;
	Rh.ss = 0x10;
	setMapping(0x08, 0x409A, addrToLong(cp), Rh.codeLen);
	if	(Extended)
		i = (Extended * 1024) + 0x100000L;
	else
		i = 0x100000L;		/* Even if conventional is small,
					   map to the end of the BIOS area
					 */
	i -= addrToLong(cp2);
	addrp = (long *)((char huge *)cp2 + Rh.sp) + 500;
	addrp[0] = Conventional;
	addrp[1] = Extended;
	addrp[2] = Rh.codeOffset;
	addrp[3] = Rh.dataOffset;
	setMapping(0x10, 0x4092, addrToLong(cp2), i);
	_close(fd);
	}
/*
	This function reads a segment from the Run file to a memory segment.
	The totalLen is the size in bytes and can be any size up to the 640K
	real memory limit of the PC.  The adjust factor allows for reserving
	some number of unmapped pages at the low end of the address space.
 */
void	*readImage(int fd, long initLen, long totalLen, long adjust)
	{
	char	huge * addr;
	void	*addr2;
	int	rem;

	totalLen -= adjust;
	initLen -= adjust;
	addr = allocBrklvl(totalLen);
	addr2 = (void *)(addr - adjust);
	while	(initLen){
		if	(initLen > 0x7000)
			rem = 0x7000;
		else
			rem = initLen;
		if	(_read(fd, (void *)addr, rem) != rem){
			printf("Couldn't read image\n");
			exit(1);
			}
		addr += rem;
		initLen -= rem;
		totalLen -= rem;
		}
	while	(totalLen){
		if	(totalLen > 0x7000)
			rem = 0x7000;
		else
			rem = totalLen;
		memset((char *)addr, 0, rem);
		totalLen -= rem;
		addr += rem;
		}
	return(addr2);
	}
/*
	Convert an 8086 real mode far pointer to a long linear address.
 */
long	addrToLong(void *addr)
	{
	long	i;

	i = (int)addr;
	i += ((long)addr >> 16) << 4;
	return i;
	}

unsigned char getCMOSbyte(int addr)
	{
	outportb(CMOS_PORT, addr | 0x80);
	_idle_();
	return inportb(CMOS_PORT + 1);
	}
/*
	This function defines the segment mapping for a selector.
	The selector numbwer is assumed to be a GDT selector.  The
	length is always given in bytes, but the code maps large segments
	appropriately (descriptors have only 20 bits of precision).
 */
void	setMapping(unsigned selector, unsigned short attributes,
					paddr_t offset,
					paddr_t length)
	{
	descriptor	*d;
	unsigned	nd;

	d = Desc + (selector >> 3);
	if	(length){
		length--;		/* The limit, when not zero is the
					   last legal offset.
					 */
		if	(length > 0xfffff)
			attributes |= 0x8000;
		}
	else	{
		attributes &= ~0x80;	/* Clear the present bit for zero
					   length segments */
		}

		/* Round to nearest page size when granularity is PAGE */

	if	(attributes & 0x8000){
		length += 0xfff;
		length >>= 12;
		}
	d->limit = length;
	d->reserved = ((length >> 16) & 0xf) | (attributes >> 8);
	d->base = offset;
	d->base16 = offset >> 16;
	d->attribute = attributes;
	}
