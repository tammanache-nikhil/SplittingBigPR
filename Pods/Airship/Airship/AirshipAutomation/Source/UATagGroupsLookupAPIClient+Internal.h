/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroups.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * API client for performing tag group lookups.
 */
@interface UATagGroupsLookupAPIClient : UAAPIClient

/**
 * UATagGroupsLookupAPIClient class factory method.
 *
 * @param config An instance of UARuntimeConfig.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * UATagGroupsLookupAPIClient class factory method.
 *
 * @param config An instance of UARuntimeConfig.
 * @param session An instance of UARequestSession.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Performs a tag group lookup.
 *
 * @param channelID The channel ID.
 * @param requestedTagGroups The requested tag groups.
 * @param cachedResponse The currently cached response, or nil if none is available
 * @param completionHandler A completion handler taking a lookup response.
 */
- (void)lookupTagGroupsWithChannelID:(NSString *)channelID
                  requestedTagGroups:(UATagGroups *)requestedTagGroups
                      cachedResponse:(nullable UATagGroupsLookupResponse *)cachedResponse
                   completionHandler:(void (^)(UATagGroupsLookupResponse *))completionHandler;

@end

NS_ASSUME_NONNULL_END
