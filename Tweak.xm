#define LD_DEBUG NO
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <notify.h>
#import "FLEXManager.h"
#import <rootless.h>

static BOOL tweakEnabled = YES;
static NSUserDefaults *preferences = nil;
NSString *dylibPath = ROOT_PATH_NS(@"/Library/MobileSubstrate/DynamicLibraries/libFLEX.dylib");

@interface SBApplication
- (NSString *)bundleIdentifier;
@end

@interface SpringBoard
- (SBApplication *)_accessibilityFrontMostApplication;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

// Function to handle preferences changed
static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
}

%hook SpringBoard

- (BOOL)_handlePhysicalButtonEvent:(UIPressesEvent *)event {
    if (tweakEnabled) {
        BOOL upPressed = NO;
        BOOL downPressed = NO;
        
        for (UIPress *press in event.allPresses.allObjects) {
            if (press.type == 102 && press.force == 1) {
                upPressed = YES;
            }
            if (press.type == 103 && press.force == 1) {
                downPressed = YES;
            }
        }
        
        SBApplication *frontmostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
        SBLockScreenManager *lockscreenManager = [objc_getClass("SBLockScreenManager") sharedInstance];
        
        // Only proceed if the user is holding down both buttons
        if (upPressed && downPressed && !lockscreenManager.isUILocked) {
            
            // Vibrate and play tune :D
            AudioServicesPlaySystemSound(1328);
            
            SBApplication *frontmostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
            SBLockScreenManager *lockscreenManager = [objc_getClass("SBLockScreenManager") sharedInstance];
            // if frontmostApp is true and the phone is not locked
            if (frontmostApp && !lockscreenManager.isUILocked) {
                notify_post([[NSString stringWithFormat:@"com.joshua.volumeflex/%@", frontmostApp.bundleIdentifier] UTF8String]);
            } else {
                void *libraryHandle = dlopen(dylibPath.UTF8String, RTLD_NOW);
                [[objc_getClass("FLEXManager") sharedManager] showExplorer];
            }
        }
    }
    return %orig;
}

%end

%ctor {
    NSString *currentID = NSBundle.mainBundle.bundleIdentifier;
    if ([currentID isEqualToString:@"com.apple.springboard"]) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, CFSTR("com.joshua.VFPB.preferences.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        preferences = [[NSUserDefaults alloc] initWithSuiteName:@"com.joshua.VFPB.plist"];

        [preferences registerDefaults:@{
            @"Enabled": @(tweakEnabled)
        }];

        tweakEnabled = [[preferences objectForKey:@"Enabled"] boolValue];

        %init
    } else {
        int regToken;
        NSString *notifForBundle = [NSString stringWithFormat:@"com.joshua.volumeflex/%@", currentID];
        notify_register_dispatch(notifForBundle.UTF8String, &regToken, dispatch_get_main_queue(), ^(int token) {
            void *libraryHandle = dlopen(dylibPath.UTF8String, RTLD_NOW);
            [[objc_getClass("FLEXManager") sharedManager] showExplorer];
        });
    }
}

