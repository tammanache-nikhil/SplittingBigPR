/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UASchedule.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageScheduleEdits.h"
#import "UAInAppMessageDisplayCoordinator.h"
#import "UAInAppMessageAssetManager.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving in-app messaging related
 * callbacks.
 */
@protocol UAInAppMessagingDelegate <NSObject>

@optional

///---------------------------------------------------------------------------------------
/// @name In App Messaging Delegate Methods
///---------------------------------------------------------------------------------------

/**
 * Allows the delegate to provide a custom display coordinator for the provided message.
 *
 * @param message The message.
 * @return An object implementing the UAInAppMessageDisplayCoordinator protocol or nil
 * if no suitable display coordinator is available.
 */
- (nullable id<UAInAppMessageDisplayCoordinator>)displayCoordinatorForMessage:(UAInAppMessage *)message;

/**
 * Allows the delegate to extend a message before display.
 *
 * @param message The message.
 * @return An extended instance of the message.
 */
- (UAInAppMessage *)extendMessage:(UAInAppMessage *)message;

/**
 * Indicates that an in-app message will be displayed.
 * @param message The associated in-app message.
 * @param scheduleID The schedule ID.
 */
- (void)messageWillBeDisplayed:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID;

/**
 * Indicates that an in-app message has finished displaying.
 * @param message The associated in-app message.
 * @param scheduleID The schedule ID.
 * @param resolution The resolution info.
 */
- (void)messageFinishedDisplaying:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID resolution:(UAInAppMessageResolution *)resolution;

/**
 * Allows the delegate to override the the choice of window scene for displaying the message.
 *
 * @param message The message.
 * @param defaultScene The window scene chosen for displaying the message, or nil if one could not be found.
 * @return A window scene if the delegate chooses to override the choice of scene, or nil otherwise.
 */
- (UIWindowScene *)sceneForMessage:(UAInAppMessage *)message defaultScene:(nullable UIWindowScene *)defaultScene API_AVAILABLE(ios(13.0));

@end

/**
 * Provides a control interface for creating, canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager : UAComponent

/**
 * In-app message enable flag.
 */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/**
 * In-app message display paused flag.
 */
@property (nonatomic, assign, getter=isPaused) BOOL paused;

/**
 * In-app messaging delegate.
 */
@property (nonatomic, weak) id<UAInAppMessagingDelegate> delegate;

/**
 * Message display interval.
 */
@property(nonatomic, assign) NSTimeInterval displayInterval;

/**
 * In-app messaging asset manager.
 */
@property(nonatomic, strong, readonly) UAInAppMessageAssetManager *assetManager;

/**
 * Allows setting factory blocks that builds InAppMessageAdapters for each given display type.
 *
 * @param displayType The display type.
 * @param factory The adapter factory.
 */
- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(UAInAppMessage* message))factory
         forDisplayType:(UAInAppMessageDisplayType)displayType;


/**
 * Schedules an in-app message.
 *
 * @param scheduleInfo The schedule info for the message.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Schedules an in-app message.
 *
 * @param scheduleInfo The schedule info for the message.
 * @param metadata The schedule optional metadata.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                               metadata:(nullable NSDictionary *)metadata
                      completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Schedules multiple in-app messages.
 *
 * @param scheduleInfos The schedule info for the messages.
 * @param metadata The schedules' optional metadata.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos
                                metadata:(nullable NSDictionary *)metadata
                       completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Cancels an in-app message via its schedule identifier.
 *
 * @param scheduleID The schedule ID for the message to be canceled.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID;

/**
 * Cancels an in-app message via its schedule identifier.
 *
 * @param scheduleID The schedule ID for the message to be canceled.
 * @param completionHandler A completion handler called with the schedule that was canceled, or nil if the schedule was not found.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID completionHandler:(nullable void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Cancels in-app messages with the specified group identifier.
 *
 * @param identifier The message ID.
 */
- (void)cancelMessagesWithID:(NSString *)identifier;

/**
 * Cancels in-app messages with the specified group identifier.
 *
 * @param identifier The message ID.
 * @param completionHandler A completion handler called with an array of message schedules that were canceled.
 * If no messages matching the provided identifier are found, this array will be empty.
 */
- (void)cancelMessagesWithID:(NSString *)identifier completionHandler:(nullable void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Gets schedules with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be fetched.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Gets schedules whose group is the provided message ID.
 *
 * @param messageID The message ID.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedulesWithMessageID:(NSString *)messageID completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules, including schedules that have ended.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getAllSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAInAppMessageScheduleEdits *)edits
         completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

/**
 * Check display audience conditions.
 *
 * @param audience The specified audience
 * @param completionHandler Passed `YES` if the current user is a member of the specified audience,
 *                                 `NO` if the current user is not a member of the specified audience.
 *                                 Error is non-nil if there was an error evaluating the audience.
 */
- (void)checkAudience:(UAInAppMessageAudience *)audience completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
