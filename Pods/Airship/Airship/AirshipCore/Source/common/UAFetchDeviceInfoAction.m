/* Copyright Airship and Contributors */


#import "UAFetchDeviceInfoAction.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAChannel.h"
#import "UANamedUser.h"

@implementation UAFetchDeviceInfoAction

NSString *const UAChannelIDKey = @"channel_id";
NSString *const UANamedUserKey = @"named_user";
NSString *const UATagsKey = @"tags";
NSString *const UAPushOptInKey = @"push_opt_in";
NSString *const UALocationEnabledKey = @"location_enabled";

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[UAirship channel].identifier forKey:UAChannelIDKey];
    [dict setValue:[UAirship namedUser].identifier forKey:UANamedUserKey];
    
    NSArray *tags = [[UAirship channel] tags];
    if (tags.count) {
        [dict setValue:tags forKey:UATagsKey];
    }

    BOOL optedIn = [UAirship push].authorizedNotificationSettings != 0;
    [dict setValue:@(optedIn) forKey:UAPushOptInKey];

    BOOL locationEnabled = [UAirship shared].locationProvider.locationUpdatesEnabled;
    [dict setValue:@(locationEnabled) forKey:UALocationEnabledKey];

    completionHandler([UAActionResult resultWithValue:dict]);
}

@end
