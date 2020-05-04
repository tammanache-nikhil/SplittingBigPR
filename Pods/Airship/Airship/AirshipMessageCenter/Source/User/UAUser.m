/* Copyright Airship and Contributors */

#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAUserAPIClient+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

NSString * const UAUserRegisteredChannelIDKey= @"UAUserRegisteredChannelID";
NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

@interface UAUser()
@property (nonatomic, strong) UAChannel<UAExtendableChannelRegistration> *channel;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, strong) UAUserAPIClient *apiClient;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADispatcher *backgroundDispatcher;
@property (copy) NSString *registeredChannelID;
@property (assign) BOOL registrationInProgress;
@end

@implementation UAUser

- (instancetype)initWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                  dataStore:(UAPreferenceDataStore *)dataStore
                     client:(UAUserAPIClient *)client
         notificationCenter:(NSNotificationCenter *)notificationCenter
                application:(UIApplication *)application
       backgroundDispatcher:(UADispatcher *)backgroundDispatcher
                userDataDAO:(UAUserDataDAO *)userDataDAO {
    self = [super init];

    if (self) {
        self.channel = channel;
        self.dataStore = dataStore;
        self.apiClient = client;
        self.notificationCenter = notificationCenter;
        self.application = application;
        self.backgroundDispatcher = backgroundDispatcher;
        self.userDataDAO = userDataDAO;

        [self.notificationCenter addObserver:self
                                    selector:@selector(performUserRegistration)
                                        name:UAChannelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(didBecomeActive)
                                        name:UAApplicationDidBecomeActiveNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(enterForeground)
                                        name:UAApplicationWillEnterForegroundNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(resetUser)
                                        name:UADeviceIDChangedNotification
                                      object:nil];

        UA_WEAKIFY(self)
        [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self)
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];
    }

    return self;
}

+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel config:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithChannel:channel
                                 dataStore:dataStore
                                    client:[UAUserAPIClient clientWithConfig:config]
                        notificationCenter:[NSNotificationCenter defaultCenter]
                               application:[UIApplication sharedApplication]
                      backgroundDispatcher:[UADispatcher backgroundDispatcher]
                               userDataDAO:[UAUserDataDAO userDataDAOWithConfig:config]];
}

+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                      dataStore:(UAPreferenceDataStore *)dataStore
                         client:(UAUserAPIClient *)client
             notificationCenter:(NSNotificationCenter *)notificationCenter
                    application:(UIApplication *)application
           backgroundDispatcher:(UADispatcher *)backgroundDispatcher
                    userDataDAO:(UAUserDataDAO *)userDataDAO {

    return [[UAUser alloc] initWithChannel:channel
                                 dataStore:dataStore
                                    client:client
                        notificationCenter:notificationCenter
                               application:application
                      backgroundDispatcher:backgroundDispatcher
                               userDataDAO:userDataDAO];
}

- (nullable UAUserData *)getUserDataSync {
    return [self.userDataDAO getUserDataSync];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    return [self.userDataDAO getUserData:completionHandler dispatcher:dispatcher];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler {
    return [self.userDataDAO getUserData:completionHandler];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue {
    return [self.userDataDAO getUserData:completionHandler queue:queue];
}

- (NSString *)registeredChannelID {
    return [self.dataStore stringForKey:UAUserRegisteredChannelIDKey];
}

- (void)setRegisteredChannelID:(NSString *)registeredChannelID {
    [self.dataStore setValue:registeredChannelID forKey:UAUserRegisteredChannelIDKey];
}

- (void)enterForeground {
    [self ensureUserUpToDate];
}

- (void)didBecomeActive {
    [self ensureUserUpToDate];
    [self.notificationCenter removeObserver:self
                                       name:UAApplicationDidBecomeActiveNotification
                                     object:nil];
}

- (void)ensureUserUpToDate {
    if (!self.channel.identifier) {
        return;
    }

    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *data) {
        UA_STRONGIFY(self)
        if (self.registrationInProgress) {
            return;
        }

        if (!data || ![self.registeredChannelID isEqualToString:self.channel.identifier]) {
            [self performUserRegistration];
        }
    } dispatcher:self.backgroundDispatcher];
}

- (void)resetUser {
    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *data) {
        if (!data) {
            return;
        }

        UA_STRONGIFY(self)
        self.registeredChannelID = nil;
        self.registrationInProgress = NO;
        [self.userDataDAO clearUser];
        [self performUserRegistration];
    } dispatcher:self.backgroundDispatcher];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    self.apiClient.enabled = enabled;
    if (enabled) {
        [self ensureUserUpToDate];
    }
}

/**
 * Performs either a create or update on the user depending on if the user data is available in the DAO. Perform registration
 * will no-op if the user is disabled, channelID is unavailable, or if a background task fails to create.
 */
- (void)performUserRegistration {
    if (!self.enabled) {
        UA_LDEBUG(@"Skipping user registration, user disabled.");
        return;
    }

    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        UA_LDEBUG(@"Skipping user registration, no channel.");
        return;
    }

    UA_WEAKIFY(self)

    __block UIBackgroundTaskIdentifier backgroundTask = [self.application beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self)
        [self.apiClient cancelAllRequests];
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [self.application endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
        self.registrationInProgress = NO;
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LDEBUG(@"Skipping user registration, unable to create background task.");
        return;
    }

    void (^completionHandler)(BOOL) = ^(BOOL success) {
        UA_STRONGIFY(self)
        [self.backgroundDispatcher dispatchAsync:^{
            UA_STRONGIFY(self)
            self.registrationInProgress = NO;
            if (success) {
                self.registeredChannelID = channelID;
            }
            if (backgroundTask != UIBackgroundTaskInvalid) {
                [self.application endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
    };

    [self getUserData:^(UAUserData *data) {
        UA_STRONGIFY(self)

        // Checking for registrationInProgress here instead of above so its only
        // accessed on the background queue.
        if (self.registrationInProgress) {
            UA_LDEBUG(@"Skipping user registration, already in progress");
            completionHandler(NO);
            return;
        }

        self.registrationInProgress = YES;
        if (data) {
            [self updateUserWithUserData:data channelID:channelID completionHandler:completionHandler];
        } else {
            [self createUserWithChannelID:channelID completionHandler:completionHandler];
        }
    } dispatcher:self.backgroundDispatcher];
}

/**
 *  Updates the user with the latest channel. Called from `performUserRegistration`.
 *  @param userData The current user's data.
 *  @param channelID The Airship channel ID.
 *  @param completionHandler Completion handler.
 */
- (void)updateUserWithUserData:(UAUserData *)userData channelID:(NSString *)channelID completionHandler:(void(^)(BOOL))completionHandler {
    UA_LTRACE(@"Updating user");
    [self.apiClient updateUserWithData:userData
                             channelID:channelID
                             onSuccess:^{
                                 UA_LINFO(@"Updated user %@ successfully.", userData.username);
                                 completionHandler(YES);
                             }
                             onFailure:^(NSUInteger statusCode) {
                                 UA_LDEBUG(@"Failed to update user.");
                                 completionHandler(NO);
                             }];
}

/**
 *  Creates the user with the latest channel and saves the user data to the DAO. Called from `performUserRegistration`.
 *  @param channelID The Airship channel ID.
 *  @param completionHandler Completion handler.
 */
- (void)createUserWithChannelID:(NSString *)channelID completionHandler:(void(^)(BOOL))completionHandler {
    UA_LTRACE(@"Creating user");
    UA_WEAKIFY(self)
    [self.apiClient createUserWithChannelID:channelID
                                  onSuccess:^(UAUserData *data) {
                                      UA_STRONGIFY(self)
                                      UA_LINFO(@"Created user %@.", data.username);
                                      [self.userDataDAO saveUserData:data completionHandler:^(BOOL success) {
                                          UA_STRONGIFY(self)
                                          if (success) {
                                              [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
                                          } else {
                                              UA_LINFO(@"Failed to save user");
                                          }
                                          completionHandler(success);
                                      }];
                                  }
                                  onFailure:^(NSUInteger statusCode) {
                                      UA_LINFO(@"Failed to create user");
                                      completionHandler(NO);
                                  }];
}

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {
    [self.userDataDAO getUserData:^(UAUserData *userData) {
        payload.userID = userData.username;
        completionHandler(payload);
    }];
}


@end
