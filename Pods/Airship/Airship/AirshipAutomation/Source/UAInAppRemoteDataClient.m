/* Copyright Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageScheduleEdits+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "NSObject+AnonymousKVO+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString * const UAInAppMessages = @"in_app_messages";
NSString * const UAInAppMessagesCreatedJSONKey = @"created";
NSString * const UAInAppMessagesUpdatedJSONKey = @"last_updated";

@interface UAInAppRemoteDataClient()
@property (nonatomic,strong) UAInAppMessageManager *inAppMessageManager;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADisposable *remoteDataSubscription;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) id<UARemoteDataProvider> remoteDataProvider;

@end

@implementation UAInAppRemoteDataClient

NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
NSString * const UAInAppMessagesLastPayloadMetadataKey = @"UAInAppRemoteDataClient.LastPayloadMetadata";

NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";
NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";

- (instancetype)initWithScheduler:(UAInAppMessageManager *)scheduler
               remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel {

    self = [super init];

    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        self.remoteDataProvider = remoteDataProvider;
        self.inAppMessageManager = scheduler;
        self.dataStore = dataStore;
        UA_WEAKIFY(self);
        self.remoteDataSubscription = [remoteDataProvider subscribeWithTypes:@[UAInAppMessages]
                                                                       block:^(NSArray<UARemoteDataPayload *> * _Nonnull messagePayloads) {
            UA_STRONGIFY(self);
            [self.operationQueue addOperationWithBlock:^{
                UA_STRONGIFY(self);
                [self processInAppMessageData:[messagePayloads firstObject]];
            }];
        }];
        if (!self.scheduleNewUserCutOffTime) {
            self.scheduleNewUserCutOffTime = (channel.identifier) ? [NSDate distantPast] : [NSDate date];
        }
    }

    return self;
}

+ (instancetype)clientWithScheduler:(UAInAppMessageManager *)scheduler
                 remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel {
    return [[UAInAppRemoteDataClient alloc] initWithScheduler:scheduler
                                           remoteDataProvider:remoteDataProvider
                                                    dataStore:dataStore
                                                      channel:channel];
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)notifyOnMetadataUpdate:(void (^)(void))completionHandler {
    [self.operationQueue addOperationWithBlock:^{
        UA_LTRACE(@"Metadata is out of date, invalidating schedule until metadata update can occur.");
        if ([self.remoteDataProvider isMetadataCurrent:self.lastPayloadMetadata]) {
            completionHandler();
        } else {
            // Otherwise wait until change to lastPayloadMetadata to invalidate
            __block UADisposable *disposable = [self observeAtKeyPath:@"lastPayloadMetadata" withBlock:^(id  _Nonnull value) {
                completionHandler();
                [disposable dispose];
            }];
        }
    }];
}

- (void)processInAppMessageData:(UARemoteDataPayload *)messagePayload {
    NSDate *thisPayloadTimeStamp = messagePayload.timestamp;
    NSDictionary *thisPayloadMetadata = messagePayload.metadata;

    NSDate *lastUpdate = [self.dataStore objectForKey:UAInAppMessagesLastPayloadTimeStampKey] ?: [NSDate distantPast];
    NSDictionary *lastMetadata = self.lastPayloadMetadata ?: @{};
    BOOL isMetadataCurrent = [thisPayloadMetadata isEqualToDictionary:lastMetadata];

    // generate messageId to scheduleId map for existing schedules
    NSMutableDictionary<NSString *, NSString *> *scheduleIDMap = [NSMutableDictionary dictionary];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.inAppMessageManager getAllSchedules:^(NSArray<UASchedule *> *schedules) {
        for (UASchedule *schedule in schedules) {
            UAInAppMessage *message = (UAInAppMessage *)((UAInAppMessageScheduleInfo *)schedule.info).message;
            if (message.source != UAInAppMessageSourceRemoteData) {
                continue;
            }

            NSString *messageID = message.identifier;
            if (!messageID.length) {
                continue;
            }

            scheduleIDMap[messageID] = schedule.identifier;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // cached messageId to scheduleId map is no longer used
    if ([self.dataStore dictionaryForKey:UAInAppMessagesScheduledMessagesKey]) {
        [self.dataStore removeObjectForKey:UAInAppMessagesScheduledMessagesKey];
    }

    // Skip if the payload timestamp is same as the last updated timestamp and metadata is current
    if ([thisPayloadTimeStamp isEqualToDate:lastUpdate] && isMetadataCurrent) {
        return;
    }

    // Get the in-app message data, if it exists
    NSArray *messages;
    NSDictionary *messageData = messagePayload.data;
    if (!messageData || !messageData[UAInAppMessages] || ![messageData[UAInAppMessages] isKindOfClass:[NSArray class]]) {
        messages = @[];
    } else {
        messages = messageData[UAInAppMessages];
    }

    NSMutableArray<NSString *> *messageIDs = [NSMutableArray array];
    NSMutableArray<UAInAppMessageScheduleInfo *> *newSchedules = [NSMutableArray array];

    // Dispatch group
    dispatch_group_t dispatchGroup = dispatch_group_create();

    // Validate messages and create new schedules
    for (NSDictionary *message in messages) {
        NSDate *createdTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesCreatedJSONKey]];
        NSDate *lastUpdatedTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesUpdatedJSONKey]];
        if (!createdTimeStamp || !lastUpdatedTimeStamp) {
            UA_LERR(@"Failed to parse in-app message timestamps: %@", message);
            continue;
        }

        NSString *messageID = [UAInAppMessageScheduleInfo parseMessageID:message];
        if (!messageID.length) {
            UA_LERR("Missing in-app message ID: %@", message);
            continue;
        }

        [messageIDs addObject:messageID];

        // Ignore any messages that have not updated since the last payload
        if (isMetadataCurrent && [lastUpdate compare:lastUpdatedTimeStamp] != NSOrderedAscending) {
            continue;
        }

        if ([createdTimeStamp compare:lastUpdate] == NSOrderedDescending) {
            // New in-app message
            NSError *error;
            UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithJSON:message
                                                                                                 source:UAInAppMessageSourceRemoteData
                                                                                                  error:&error];
            if (!scheduleInfo || error) {
                UA_LERR(@"Failed to parse in-app message: %@ - %@", message, error);
                continue;
            }

            if ([self checkSchedule:scheduleInfo createdTimeStamp:createdTimeStamp]) {
                [newSchedules addObject:scheduleInfo];
            }
        } else if (scheduleIDMap[messageID]) {
            // Edit with new info and/or metadata
            __block NSError *error;

            UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
                [builder applyFromJson:message source:UAInAppMessageSourceRemoteData error:&error];

                builder.metadata = [NSJSONSerialization stringWithObject:thisPayloadMetadata];

                /* Since we cancel a schedule by setting the end time to the payload's last modified timestamp,
                we need to reset it back to distant future if the edits do not define an end time. */
                if (!builder.end) {
                    builder.end = [NSDate distantFuture];
                }
            }];

            if (!edits || error) {
                UA_LERR(@"Failed to parse in-app message edits: %@ - %@", message, error);
                continue;
            }

            dispatch_group_enter(dispatchGroup);
            [self.inAppMessageManager editScheduleWithID:scheduleIDMap[messageID]
                                                   edits:edits
                                       completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
                    UA_LTRACE("Updated in-app message: %@", messageID);
                }
            }];
        }
    }


    // End any messages that are no longer in the listing
    NSMutableArray<NSString *> *deletedMessageIDs = [NSMutableArray arrayWithArray:scheduleIDMap.allKeys];
    [deletedMessageIDs removeObjectsInArray:messageIDs];

    if (deletedMessageIDs.count) {
        /* To cancel, set the end time to the payload's last modified timestamp. To avoid validation errors,
         The start must be equal to or before the end time. If the schedule comes back, we will reset the start and end time
         from the schedule edits. */
        UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
            builder.end = thisPayloadTimeStamp;
            builder.start = thisPayloadTimeStamp;
        }];

        for (NSString *messageID in deletedMessageIDs) {
            dispatch_group_enter(dispatchGroup);
            [self.inAppMessageManager editScheduleWithID:scheduleIDMap[messageID]
                                                   edits:edits
                                       completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
                    UA_LTRACE("Ended in-app message: %@", messageID);
                }
            }];
        }
    }

    // New messages
    if (newSchedules.count) {
        dispatch_group_enter(dispatchGroup);

        [self.inAppMessageManager scheduleMessagesWithScheduleInfo:newSchedules metadata:thisPayloadMetadata completionHandler:^(NSArray<UASchedule *> *schedules) {
            dispatch_group_leave(dispatchGroup);
        }];
    }

    // Wait for everything to finish
    dispatch_group_wait(dispatchGroup,  DISPATCH_TIME_FOREVER);

    // Save state
    self.lastPayloadMetadata = thisPayloadMetadata;
    [self.dataStore setObject:thisPayloadTimeStamp forKey:UAInAppMessagesLastPayloadTimeStampKey];
}

- (NSDictionary *)lastPayloadMetadata {
    return [self.dataStore objectForKey:UAInAppMessagesLastPayloadMetadataKey];
}

- (void)setLastPayloadMetadata:(NSDictionary *)metadata {
    [self willChangeValueForKey:@"lastPayloadMetadata"];
    [self.dataStore setObject:metadata forKey:UAInAppMessagesLastPayloadMetadataKey];
    [self didChangeValueForKey:@"lastPayloadMetadata"];
}

- (BOOL)checkSchedule:(UAInAppMessageScheduleInfo *)scheduleInfo createdTimeStamp:(NSDate *)createdTimeStamp {
    UAInAppMessageAudience *audience = scheduleInfo.message.audience;
    BOOL isNewUser = ([createdTimeStamp compare:self.scheduleNewUserCutOffTime] == NSOrderedAscending);
    return [UAInAppMessageAudienceChecks checkScheduleAudienceConditions:audience isNewUser:isNewUser];
}

- (NSDate *)scheduleNewUserCutOffTime {
    return [self.dataStore objectForKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (void)setScheduleNewUserCutOffTime:(NSDate *)time {
    [self.dataStore setObject:time forKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

@end

