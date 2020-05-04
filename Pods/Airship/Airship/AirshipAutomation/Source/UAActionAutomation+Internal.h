/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAActionAutomation.h"
#import "UAAutomationEngine+Internal.h"
#import "UAAirshipAutomationCoreImport.h"


@class UAAutomationStore;
@class UAPreferenceDataStore;

/*
 * SDK-private extensions to UAActionAutomation
 */
@interface UAActionAutomation() <UAAutomationEngineDelegate>

///---------------------------------------------------------------------------------------
/// @name Automation Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *preferenceDataStore;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAAutomationEngine *automationEngine;

///---------------------------------------------------------------------------------------
/// @name Automation Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Automation constructor.
 */
+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                           dataStore:(UAPreferenceDataStore *)dataStore;

@end
