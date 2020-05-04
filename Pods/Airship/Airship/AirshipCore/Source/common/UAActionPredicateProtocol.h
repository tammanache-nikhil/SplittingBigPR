/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An protocol that defines the minimal functionality of a valid action predicate when loading a actions from a plist.
 */
@protocol UAActionPredicateProtocol <NSObject>

///---------------------------------------------------------------------------------------
/// @name Action Predicate Core Methods
///---------------------------------------------------------------------------------------

@required

/**
 * Applies predicate to action arguments to define the action's runnable
 * scope.
 *
 * @param args Action arguments.
 *
 * @return `YES` if action should run in the scope outlined by the action arguments, `NO` otherwise.
 */
- (BOOL)applyActionArguments:(UAActionArguments *)args;

/**
 * Factory method when loading the predicate from a plist.
 * @return The predicate.
 */
+ (instancetype)predicate;

@end

NS_ASSUME_NONNULL_END
