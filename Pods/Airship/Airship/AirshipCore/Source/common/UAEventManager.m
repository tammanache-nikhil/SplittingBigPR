
/* Copyright Airship and Contributors */

#import "UAEventManager+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAEventStore+Internal.h"
#import "UAEventData+Internal.h"
#import "UAAsyncOperation.h"
#import "UAEventAPIClient+Internal.h"
#import "UAEvent+Internal.h"
#import "UARuntimeConfig.h"
#import "UAChannel.h"
#import "UAirship.h"
#import "NSOperationQueue+UAAdditions.h"
#import "UADispatcher.h"
#import "UAAppStateTracker.h"

@interface UAEventManager()

@property (nonatomic, strong, nonnull) UARuntimeConfig *config;
@property (nonatomic, strong, nonnull) UAEventStore *eventStore;
@property (nonatomic, strong, nonnull) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong, nonnull) UAEventAPIClient *client;
@property (nonatomic, strong, nonnull) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong, nonnull) UAAppStateTracker *appStateTracker;
@property (nonatomic, strong, nonnull) UAChannel *channel;

@property (nonatomic, assign) NSUInteger maxTotalDBSize;
@property (nonatomic, assign) NSUInteger maxBatchSize;
@property (nonatomic, assign) NSUInteger minBatchInterval;

@property (atomic, strong) NSDate *earliestForegroundSendTime;
@property (atomic, strong, nonnull) NSDate *lastSendTime;
@property (nonatomic, strong, nonnull) NSOperationQueue *queue;
@property (atomic, strong, nullable) NSDate *nextUploadDate;

@end

const NSTimeInterval FailedUploadRetryDelay = 60;
const NSTimeInterval InitialForegroundUploadDelay = 15;
const NSTimeInterval HighPriorityUploadDelay = 1;
const NSTimeInterval BackgroundUploadDelay = 5;
const NSTimeInterval BackgroundLowPriorityEventUploadInterval = 900;

@implementation UAEventManager

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel *)channel
                    eventStore:(UAEventStore *)eventStore
                        client:(UAEventAPIClient *)client
                         queue:(NSOperationQueue *)queue
            notificationCenter:(NSNotificationCenter *)notificationCenter
               appStateTracker:(UAAppStateTracker *)appStateTracker {

    self = [super init];

    if (self) {
        self.config = config;
        self.eventStore = eventStore;
        self.dataStore = dataStore;
        self.channel = channel;
        self.client = client;
        self.queue = queue;
        self.notificationCenter = notificationCenter;
        self.appStateTracker = appStateTracker;

        _uploadsEnabled = YES;

        // Set the intial delay
        self.earliestForegroundSendTime = [NSDate dateWithTimeIntervalSinceNow:InitialForegroundUploadDelay];


        // Schedule upload on channel creation
        [self.notificationCenter addObserver:self
                                    selector:@selector(scheduleUpload)
                                        name:UAChannelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationWillEnterForeground)
                                        name:UAApplicationWillEnterForegroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidEnterBackground)
                                        name:UAApplicationDidEnterBackgroundNotification
                                      object:nil];
    }

    return self;
}


- (void)dealloc {
    [self cancelUpload];
}

+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel {
    UAEventStore *eventStore = [UAEventStore eventStoreWithConfig:config];
    UAEventAPIClient *client = [UAEventAPIClient clientWithConfig:config];

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                             eventStore:eventStore
                                 client:client
                                  queue:queue
                     notificationCenter:[NSNotificationCenter defaultCenter]
                        appStateTracker:[UAAppStateTracker shared]];

}

+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                            eventStore:(UAEventStore *)eventStore
                                client:(UAEventAPIClient *)client
                                 queue:(NSOperationQueue *)queue
                    notificationCenter:(NSNotificationCenter *)notificationCenter
                       appStateTracker:(UAAppStateTracker *)appStateTracker {

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                             eventStore:eventStore
                                 client:client
                                  queue:queue
                     notificationCenter:notificationCenter
                        appStateTracker:appStateTracker];
}

- (void)setUploadsEnabled:(BOOL)uploadsEnabled {
    if (_uploadsEnabled != uploadsEnabled) {
        _uploadsEnabled = uploadsEnabled;
        if (uploadsEnabled) {
            [self scheduleUpload];
        } else {
            [self cancelUpload];
        }
    }
}

#pragma mark -
#pragma mark App foreground

- (void)applicationWillEnterForeground {
    [self cancelUpload];

    // Reset the initial delay
    self.earliestForegroundSendTime = [NSDate dateWithTimeIntervalSinceNow:InitialForegroundUploadDelay];
}

- (void)applicationDidEnterBackground {
    [self scheduleUploadWithDelay:BackgroundUploadDelay];
}

#pragma mark -
#pragma mark Preferences

- (NSDate *)lastSendTime {
    return [self.dataStore objectForKey:@"X-UA-Last-Send-Time"] ?: [NSDate distantPast];
}

- (void)setLastSendTime:(NSDate *)lastSendTime {
    if (lastSendTime) {
        [self.dataStore setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
    }
}

- (void)updateAnalyticsParametersWithResponse:(NSHTTPURLResponse *)response {
    if (response.statusCode != 200 || ![response allHeaderFields].count) {
        return;
    }

    id maxTotalValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Total"];
    if (maxTotalValue) {
        self.maxTotalDBSize = (NSUInteger)[maxTotalValue integerValue] * 1024; //value returned in KB;
    }

    id maxBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Batch"];
    if (maxBatchValue) {
        self.maxBatchSize = (NSUInteger)[maxBatchValue integerValue] * 1024; //value return in KB
    }

    id minBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Min-Batch-Interval"];
    if (minBatchValue) {
        self.minBatchInterval = (NSUInteger)[minBatchValue integerValue];
    }
}

- (void)setMaxTotalDBSize:(NSUInteger)maxTotalDBSize {
    [self.dataStore setInteger:maxTotalDBSize forKey:kMaxTotalDBSizeUserDefaultsKey];
}

- (NSUInteger)maxTotalDBSize {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMaxTotalDBSizeUserDefaultsKey];
    return [UAEventManager clampValue:value min:kMinTotalDBSizeBytes max:kMaxTotalDBSizeBytes];
}

- (void)setMaxBatchSize:(NSUInteger)maxBatchSize {
    [self.dataStore setInteger:maxBatchSize forKey:kMaxBatchSizeUserDefaultsKey];
}

- (NSUInteger)maxBatchSize {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMaxBatchSizeUserDefaultsKey];
    return [UAEventManager clampValue:value min:kMinBatchSizeBytes max:kMaxBatchSizeBytes];
}

- (void)setMinBatchInterval:(NSUInteger)minBatchInterval {
    [self.dataStore setInteger:minBatchInterval forKey:kMinBatchIntervalUserDefaultsKey];
}

- (NSUInteger)minBatchInterval {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMinBatchIntervalUserDefaultsKey];
    return [UAEventManager clampValue:value min:kMinBatchIntervalSeconds max:kMaxBatchIntervalSeconds];
}

#pragma mark -
#pragma mark Events

- (void)addEvent:(UAEvent *)event sessionID:(NSString *)sessionID {
    [self.eventStore saveEvent:event sessionID:sessionID];

    if (!self.uploadsEnabled) {
        return;
    }

    switch (event.priority) {
        case UAEventPriorityHigh:
            [self scheduleUploadWithDelay:HighPriorityUploadDelay];
            break;

        case UAEventPriorityNormal:
            [self scheduleUpload];
            break;

        case UAEventPriorityLow:
            if (self.appStateTracker.state == UAApplicationStateBackground) {
                NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
                if (timeSinceLastSend < BackgroundLowPriorityEventUploadInterval) {
                    UA_LTRACE("Skipping low priority background event send.");
                    break;
                }
            }

            [self scheduleUpload];
            break;
    }
}

- (void)deleteAllEvents {
    [self.eventStore deleteAllEvents];
    [self cancelUpload];
}

#pragma mark -
#pragma mark Event upload

- (void)cancelUpload {
    [self.queue cancelAllOperations];
    [self.client cancelAllRequests];
    self.nextUploadDate = nil;
}

- (void)scheduleUpload {
    if (!self.uploadsEnabled) {
        return;
    }

    // Background time is limited, so bypass other time delays
    if (self.appStateTracker.state == UAApplicationStateBackground) {
        [self scheduleUploadWithDelay:BackgroundUploadDelay];
        return;
    }

    NSTimeInterval delay = 0;
    NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
    if (timeSinceLastSend < self.minBatchInterval) {
        delay = self.minBatchInterval - timeSinceLastSend;
    }

    // Now worry about initial delay
    NSTimeInterval initialDelayRemaining = [self.earliestForegroundSendTime timeIntervalSinceNow];

    delay = MAX(delay, initialDelayRemaining);

    [self scheduleUploadWithDelay:delay];
}

- (void)scheduleUploadWithDelay:(NSTimeInterval)delay {
    if (!self.uploadsEnabled) {
        return;
    }

    UA_LTRACE(@"Enqueuing attempt to schedule event upload with delay on main queue.");

    UA_WEAKIFY(self);
    [[UADispatcher mainDispatcher] dispatchAsync:^{
        UA_STRONGIFY(self);
        if (!self.uploadsEnabled) {
            return;
        }

        UA_LTRACE(@"Attempting to schedule event upload with delay: %f seconds.", delay);

        NSDate *uploadDate = [NSDate dateWithTimeIntervalSinceNow:delay];
        NSTimeInterval timeDifference = [self.nextUploadDate timeIntervalSinceDate:uploadDate];
        if (self.nextUploadDate && timeDifference >= 0 && timeDifference <= 1) {
            UA_LTRACE("Upload already scheduled for an earlier time.");
            return;
        }

        if (self.nextUploadDate) {
            [self.queue cancelAllOperations];
            self.nextUploadDate = nil;
        }

        UA_LTRACE(@"Scheduling upload.");
        if ([self enqueueUploadOperationWithDelay:delay]) {
            self.nextUploadDate = uploadDate;
        }
    }];
}

- (BOOL)enqueueUploadOperationWithDelay:(NSTimeInterval)delay {

    UA_WEAKIFY(self);

    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        UA_STRONGIFY(self);
        if (!self.uploadsEnabled) {
            return;
        }

        self.nextUploadDate = nil;

        UA_LTRACE("Preparing events for upload");

        if (!self.channel.identifier) {
            UA_LTRACE("No Channel ID. Skipping analytic upload.");
            [operation finish];
            return;
        }

        // Clean up store
        [self.eventStore trimEventsToStoreSize:self.maxTotalDBSize];

        // Fetch events
        [self.eventStore fetchEventsWithMaxBatchSize:self.maxBatchSize completionHandler:^(NSArray<UAEventData *> *result) {

            // Make sure we are not cancelled
            if (operation.isCancelled) {
                [operation finish];
                return;
            }

            if (!result.count) {
                [operation finish];
                return;
            }

            NSMutableArray *preparedEvents = [NSMutableArray arrayWithCapacity:result.count];

            for (UAEventData *eventData in result) {
                NSMutableDictionary *eventBody = [NSMutableDictionary dictionary];
                [eventBody setValue:eventData.identifier forKey:@"event_id"];
                [eventBody setValue:eventData.time forKey:@"time"];
                [eventBody setValue:eventData.type forKey:@"type"];

                NSError *error = nil;
                NSMutableDictionary *data = [[NSJSONSerialization JSONObjectWithData:eventData.data options:0 error:&error] mutableCopy];
                if (error) {
                    UA_LERR(@"Failed to deserialize event %@: %@", eventData, error);
                    [[eventData managedObjectContext] deleteObject:eventData];
                }

                [data setValue:eventData.sessionID forKey:@"session_id"];
                [eventBody setValue:data forKey:@"data"];

                [preparedEvents addObject:eventBody];
            }

            // Make sure we are not cancelled
            if (operation.isCancelled) {
                [operation finish];
                return;
            }

            UA_LTRACE("Uploading events.");

            // Make sure the event upload request is queueed and on the main thread as it needs to access application state
            [[UADispatcher mainDispatcher] dispatchAsync: ^{
                // Make sure we are still not cancelled
                if (operation.isCancelled) {
                    [operation finish];
                    return;
                }

                NSDictionary *headers = [self.delegate analyticsHeaders] ?: @{};

                UA_STRONGIFY(self);
                [self.client uploadEvents:preparedEvents headers:headers completionHandler:^(NSHTTPURLResponse *response) {

                    UA_STRONGIFY(self);
                    self.lastSendTime = [NSDate date];

                    if (response.statusCode == 200) {
                        UA_LTRACE(@"Analytic upload success");
                        UA_LTRACE(@"Response: %@", response);
                        [self.eventStore deleteEventsWithIDs:[preparedEvents valueForKey:@"event_id"]];
                        [self updateAnalyticsParametersWithResponse:response];
                    } else {
                        UA_LTRACE(@"Analytics upload request failed: %ld", (unsigned long)response.statusCode);
                        [self scheduleUploadWithDelay:FailedUploadRetryDelay];
                    }

                    [operation finish];
                }];
            }];
        }];
    }];

    return [self.queue addBackgroundOperation:operation delay:delay];
}

#pragma mark -
#pragma mark Helper methods

+ (NSUInteger)clampValue:(NSUInteger)value min:(NSUInteger)min max:(NSUInteger)max {
    if (value < min) {
        return min;
    }

    if (value > max) {
        return max;
    }

    return value;
}

@end
