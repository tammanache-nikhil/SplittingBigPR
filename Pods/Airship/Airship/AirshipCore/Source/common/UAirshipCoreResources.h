/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Interface for accessing AirshipCore resources.
 */
@interface UAirshipCoreResources : NSObject

/**
 * The resource bundle.
 * @return The resource bundle.
 */
+ (NSBundle *)bundle;

@end

NS_ASSUME_NONNULL_END
