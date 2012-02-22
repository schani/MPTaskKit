#if __has_feature(objc_arc)

#define MP_RETAIN(x)		(x)
#define MP_RELEASE(x)		(x)
#define MP_RELEASE_STMT(x)	((void)(x))
#define MP_AUTORELEASE(x)	(x)
#define MP_SUPER_DEALLOC

#else

#define MP_RETAIN(x)		[(x) retain]
#define MP_RELEASE(x)		[(x) release]
#define MP_RELEASE_STMT(x)	[(x) release]
#define MP_AUTORELEASE(x)	[(x) autorelease]
#define MP_SUPER_DEALLOC	[super dealloc]

#endif
