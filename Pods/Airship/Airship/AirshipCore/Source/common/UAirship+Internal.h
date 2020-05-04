/* Copyright Airship and Contributors */

#import "UAirship.h"

@class UABaseAppDelegateSurrogate;
@class UAJavaScriptDelegate;
@class UAPreferenceDataStore;
@class UAChannelCapture;
@class UAInAppMessageManager;
@class UARemoteConfigManager;

@interface UAirship()

NS_ASSUME_NONNULL_BEGIN


///---------------------------------------------------------------------------------------
/// @name Airship Internal Properties
///---------------------------------------------------------------------------------------

// Setters for public readonly-getters
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAActionRegistry *actionRegistry;
@property (nonatomic, assign) BOOL remoteNotificationBackgroundModeEnabled;
@property (nonatomic, strong) UAApplicationMetrics *applicationMetrics;
@property (nonatomic, strong) UAWhitelist *whitelist;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannelCapture *channelCapture;
@property (nonatomic, copy) NSArray<UAComponent *> *components;
@property (nonatomic, copy) NSDictionary<NSString *, UAComponent *> *componentClassMap;
@property (nonatomic, strong) id<UALocationProvider> locationProvider;


/**
 * The channel
 */
@property (nonatomic, strong) UAChannel *sharedChannel;

/**
 * The push manager.
 */
@property (nonatomic, strong) UAPush *sharedPush;

/**
 * The named user.
 */
@property (nonatomic, strong) UANamedUser *sharedNamedUser;

/**
 * The shared analytics manager.
 */
@property (nonatomic, strong) UAAnalytics *sharedAnalytics;

/**
 * Shared remoteDataManager.
 */
@property (nonatomic, strong) UARemoteDataManager *sharedRemoteDataManager;

/**
 * Shared remoteConfigManager.
 */
@property (nonatomic, strong) UARemoteConfigManager *sharedRemoteConfigManager;

/**
 * Returns the `UARemoteDataManager` instance.
 */
+ (null_unspecified UARemoteDataManager *)remoteDataManager;

///---------------------------------------------------------------------------------------
/// @name Airship Internal Methods
///---------------------------------------------------------------------------------------
///
/**
 * Perform teardown on the shared instance. This will automatically be called when an application
 * terminates.
 */
+ (void)land;

/**
 * Sets the shared airship.
 * @param airship The shared airship instance.
 */
+ (void)setSharedAirship:(UAirship * __nullable)airship;

NS_ASSUME_NONNULL_END

@end
