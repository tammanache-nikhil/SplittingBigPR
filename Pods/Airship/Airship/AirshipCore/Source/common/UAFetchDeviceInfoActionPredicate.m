/* Copyright Airship and Contributors */

#import "UAFetchDeviceInfoActionPredicate+Internal.h"

@implementation UAFetchDeviceInfoActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return args.situation == UASituationManualInvocation || args.situation == UASituationWebViewInvocation;
}

@end
