/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#import "UANativeBridgeDelegate.h"
#import "UAJavaScriptCommandDelegate.h"
#import "UANativeBridgeExtensionDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAirship scheme.
 */
extern NSString *const UANativeBridgeUAirshipScheme;

/**
 * The native bridge will automatically loads the Airship JavaScript environment into whitlelisted sites. The native
 * bridge must be assigned as the navigation delegate on a `WKWebView` in order to function.
 */
@interface UANativeBridge : NSObject <WKNavigationDelegate>


///---------------------------------------------------------------------------------------
/// @name Native Bridge Properties
///---------------------------------------------------------------------------------------

/**
 * Delegate to support additional native bridge features such as `close`.
 */
@property (nonatomic, weak, nullable) id <UANativeBridgeDelegate> nativeBridgeDelegate;

/**
 * Optional delegate to forward any WKNavigationDelegate calls.
 */
@property (nonatomic, weak, nullable) id <WKNavigationDelegate> forwardNavigationDelegate;

/**
 * Optional delegate to support custom JavaScript commands.
 */
@property (nonatomic, weak, nullable) id <UAJavaScriptCommandDelegate> javaScriptCommandDelegate;

/**
 * Optional delegate to extend the native bridge.
 */
@property (nonatomic, weak, nullable) id <UANativeBridgeExtensionDelegate> nativeBridgeExtensionDelegate;


///---------------------------------------------------------------------------------------
/// @name Native Bridge Methods
///---------------------------------------------------------------------------------------

- (instancetype)init NS_UNAVAILABLE;

/**
 * Factory method.
 * @return A native bridge instance.
 */
+ (instancetype)nativeBridge;


@end

NS_ASSUME_NONNULL_END
