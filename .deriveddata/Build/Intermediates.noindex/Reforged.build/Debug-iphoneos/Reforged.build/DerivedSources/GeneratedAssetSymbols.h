#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.reforged.app";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "LaunchScreenBackground" asset catalog color resource.
static NSString * const ACColorNameLaunchScreenBackground AC_SWIFT_PRIVATE = @"LaunchScreenBackground";

/// The "AppIconImage" asset catalog image resource.
static NSString * const ACImageNameAppIconImage AC_SWIFT_PRIVATE = @"AppIconImage";

/// The "sticky-note" asset catalog image resource.
static NSString * const ACImageNameStickyNote AC_SWIFT_PRIVATE = @"sticky-note";

/// The "verse-bg-field" asset catalog image resource.
static NSString * const ACImageNameVerseBgField AC_SWIFT_PRIVATE = @"verse-bg-field";

/// The "verse-bg-forest" asset catalog image resource.
static NSString * const ACImageNameVerseBgForest AC_SWIFT_PRIVATE = @"verse-bg-forest";

/// The "verse-bg-mountains" asset catalog image resource.
static NSString * const ACImageNameVerseBgMountains AC_SWIFT_PRIVATE = @"verse-bg-mountains";

/// The "verse-bg-ocean" asset catalog image resource.
static NSString * const ACImageNameVerseBgOcean AC_SWIFT_PRIVATE = @"verse-bg-ocean";

/// The "verse-bg-sky" asset catalog image resource.
static NSString * const ACImageNameVerseBgSky AC_SWIFT_PRIVATE = @"verse-bg-sky";

/// The "verse-bg-sunset" asset catalog image resource.
static NSString * const ACImageNameVerseBgSunset AC_SWIFT_PRIVATE = @"verse-bg-sunset";

#undef AC_SWIFT_PRIVATE
