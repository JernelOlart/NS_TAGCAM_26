#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "ns21r" asset catalog image resource.
static NSString * const ACImageNameNs21R AC_SWIFT_PRIVATE = @"ns21r";

#undef AC_SWIFT_PRIVATE
