/* Copyright Airship and Contributors */

#import "UATagGroupsLookupManager+Internal.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUATagGroupsLookupManagerEnabledKey @"com.urbanairship.tag_groups.FETCH_ENABLED"

#define kUATagGroupsLookupManagerPreferLocalTagDataTimeKey @"com.urbanairship.tag_groups.PREFER_LOCAL_TAG_DATA_TIME"


NSTimeInterval const UATagGroupsLookupManagerDefaultPreferLocalTagDataTimeSeconds = 60 * 10; // 10 minutes

NSString * const UATagGroupsLookupManagerErrorDomain = @"com.urbanairship.tag_groups_lookup_manager";

@interface UATagGroupsLookupManager ()

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id<UATagGroupsHistory> tagGroupsHistory;
@property (nonatomic, strong) UATagGroupsLookupAPIClient *lookupAPIClient;
@property (nonatomic, strong) UATagGroupsLookupResponseCache *cache;
@property (nonatomic, readonly) NSTimeInterval maxSentMutationAge;
@property (nonatomic, strong) UADate *currentTime;
@end

@implementation UATagGroupsLookupManager

- (instancetype)initWithAPIClient:(UATagGroupsLookupAPIClient *)client
                        dataStore:(UAPreferenceDataStore *)dataStore
                            cache:(UATagGroupsLookupResponseCache *)cache
                 tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory
                      currentTime:(UADate *)currentTime {

    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        self.cache = cache;
        self.tagGroupsHistory = tagGroupsHistory;
        self.lookupAPIClient = client;
        self.currentTime = currentTime;

        self.lookupAPIClient.enabled = self.enabled;
        [self updateMaxSentMutationAge];
    }

    return self;
}

+ (instancetype)lookupManagerWithConfig:(UARuntimeConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                       tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory {

    return [[self alloc] initWithAPIClient:[UATagGroupsLookupAPIClient clientWithConfig:config]
                                 dataStore:dataStore
                                     cache:[UATagGroupsLookupResponseCache cacheWithDataStore:dataStore]
                          tagGroupsHistory:tagGroupsHistory
                               currentTime:[[UADate alloc] init]];
}

+ (instancetype)lookupManagerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                     cache:(UATagGroupsLookupResponseCache *)cache
                          tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory
                               currentTime:(UADate *)currentTime {

    return [[self alloc] initWithAPIClient:client dataStore:dataStore cache:cache tagGroupsHistory:tagGroupsHistory currentTime:currentTime];
}

- (BOOL)enabled {
    return [self.dataStore boolForKey:kUATagGroupsLookupManagerEnabledKey defaultValue:YES];
}

- (void)setEnabled:(BOOL)enabled {
    [self.dataStore setBool:enabled forKey:kUATagGroupsLookupManagerEnabledKey];
    self.lookupAPIClient.enabled = self.enabled;
}

- (NSTimeInterval)preferLocalTagDataTime {
    return [self.dataStore doubleForKey:kUATagGroupsLookupManagerPreferLocalTagDataTimeKey
                           defaultValue:UATagGroupsLookupManagerDefaultPreferLocalTagDataTimeSeconds];
}

- (void)setPreferLocalTagDataTime:(NSTimeInterval)preferLocalTagDataTime {
    [self.dataStore setDouble:preferLocalTagDataTime forKey:kUATagGroupsLookupManagerPreferLocalTagDataTimeKey];
    [self updateMaxSentMutationAge];
}

- (NSTimeInterval)cacheMaxAgeTime {
    return self.cache.maxAgeTime;
}

- (void)setCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime {
    self.cache.maxAgeTime = cacheMaxAgeTime;
}

- (NSTimeInterval)cacheStaleReadTime {
    return self.cache.staleReadTime;
}

- (void)setCacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime {
    self.cache.staleReadTime = cacheStaleReadTime;
    [self updateMaxSentMutationAge];
}

- (void)updateMaxSentMutationAge {
    self.tagGroupsHistory.maxSentMutationAge = self.cache.staleReadTime + self.preferLocalTagDataTime;
}

- (NSTimeInterval)maxSentMutationAge {
    return self.tagGroupsHistory.maxSentMutationAge;
    return self.cache.staleReadTime + self.preferLocalTagDataTime;
}

- (NSError *)errorWithCode:(UATagGroupsLookupManagerErrorCode)code message:(NSString *)message {
    return [NSError errorWithDomain:UATagGroupsLookupManagerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}

- (UATagGroups *)overrideDeviceTags:(UATagGroups *)tagGroups {
    NSMutableDictionary *newTags = [tagGroups.tags mutableCopy];
    [newTags setObject:[UAirship channel].tags forKey:@"device"];
    return [UATagGroups tagGroupsWithTags:newTags];
}

- (UATagGroups *)generateTagGroups:(UATagGroups *)requestedTagGroups
                    cachedResponse:(UATagGroupsLookupResponse *)cachedResponse
                       refreshDate:(NSDate *)refreshDate {

    UATagGroups *cachedTagGroups = cachedResponse.tagGroups;

    // Apply local history
    NSTimeInterval maxAge = [[self.currentTime now] timeIntervalSinceDate:refreshDate] + self.preferLocalTagDataTime;
    UATagGroups *locallyModifiedTagGroups = [self.tagGroupsHistory applyHistory:cachedTagGroups maxAge:maxAge];

    // Override the device tags if needed
    if ([UAirship channel].isChannelTagRegistrationEnabled) {
        locallyModifiedTagGroups = [self overrideDeviceTags:locallyModifiedTagGroups];
    }

    // Only return the requested tags if available
    return [requestedTagGroups intersect:locallyModifiedTagGroups];
}

- (void)refreshCacheWithRequestedTagGroups:(UATagGroups *)requestedTagGroups
                         completionHandler:(void(^)(void))completionHandler {

    [self.delegate gatherTagGroupsWithCompletionHandler:^(UATagGroups *tagGroups) {
        tagGroups = [requestedTagGroups merge:tagGroups];
        [self.lookupAPIClient lookupTagGroupsWithChannelID:[UAirship channel].identifier
                                        requestedTagGroups:tagGroups
                                            cachedResponse:self.cache.response
                                         completionHandler:^(UATagGroupsLookupResponse *response) {
            if (response.status != 200) {
                UA_LTRACE(@"Failed to refresh the cache. Status: %lu", (unsigned long)response.status);
            } else {
                self.cache.response = response;
                self.cache.requestedTagGroups = tagGroups;
            }
            completionHandler();
        }];
    }];
}

- (void)getTagGroups:(UATagGroups *)requestedTagGroups completionHandler:(void(^)(UATagGroups  * _Nullable tagGroups, NSError *error)) completionHandler {
    __block NSError *error;

    if (!self.enabled) {
        error = [self errorWithCode:UATagGroupsLookupManagerErrorCodeComponentDisabled message:@"Tag group lookup is disabled"];
        return completionHandler(nil, error);
    }

    // Requesting only device tag groups when channel tag registration is enabled
    if ([requestedTagGroups containsOnlyDeviceTags] && [UAirship channel].isChannelTagRegistrationEnabled) {
        return completionHandler([self overrideDeviceTags:requestedTagGroups], error);
    }

    if (![UAirship channel].identifier) {
        error = [self errorWithCode:UATagGroupsLookupManagerErrorCodeChannelRequired message:@"Channel ID is required"];
        return completionHandler(nil, error);
    }

    __block NSDate *cacheRefreshDate = self.cache.refreshDate;
    __block UATagGroupsLookupResponse *cachedResponse;

    if ([self.cache.requestedTagGroups containsAllTags:requestedTagGroups]) {
        cachedResponse = self.cache.response;
    }

    if (cachedResponse && ![self.cache needsRefresh]) {
        return completionHandler([self generateTagGroups:requestedTagGroups
                                          cachedResponse:cachedResponse
                                             refreshDate:cacheRefreshDate], error);
    }

    [self refreshCacheWithRequestedTagGroups:requestedTagGroups completionHandler:^{
        cachedResponse = self.cache.response;
        cacheRefreshDate = self.cache.refreshDate;

        if (!cachedResponse) {
            error = [self errorWithCode:UATagGroupsLookupManagerErrorCodeCacheRefresh message:@"Unable to refresh cache, missing response"];
            return completionHandler(nil, error);
        }

        if ([self.cache isStale]) {
            error = [self errorWithCode:UATagGroupsLookupManagerErrorCodeCacheRefresh message:@"Unable to refresh cache, read is stale"];
            return completionHandler(nil, error);
        }

        completionHandler([self generateTagGroups:requestedTagGroups
                                   cachedResponse:cachedResponse
                                      refreshDate:cacheRefreshDate], error);
    }];
}

@end

