/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"

@class UAInAppMessageManager;

/**
 * Client class to connect the Remote Data and the In App Messaging services.
 * This class parses the remote data payloads, and asks the in app scheduler to
 * create, update, or delete in-app messages, as appropriate.
 */
@interface UAInAppRemoteDataClient : NSObject

/**
 * New user cut off time. Any schedules that have
 * a new user condition will be dropped if the schedule create time is after the
 * cut off time.
 */
@property (nonatomic, strong) NSDate *scheduleNewUserCutOffTime;

/**
 * Operation queue. Exposed for testing.
 */
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

/**
 * The last payload's metadata. Mutable for testing purposes.
 */
@property (nonatomic) NSDictionary *lastPayloadMetadata;

/**
 * Create a remote data client for in-app messaging.
 *
 * @param delegate The delegate to be used to schedule in-app messages.
 * @param remoteDataProvider The remote data provider.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param channel The channel.
 */
+ (instancetype)clientWithScheduler:(UAInAppMessageManager *)delegate
                 remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel;

/**
 * Facilitates KVO observation on the lastPayloadMetadata on the remote data client's operation queue
 * if the last stored metadata doesn't match the last payload metadata. Runs the completion
 * handler when check completes.
 *
 * @param completionHandler The completion handler to run when check completes.
 */
- (void)notifyOnMetadataUpdate:(void (^)(void))completionHandler;

@end
