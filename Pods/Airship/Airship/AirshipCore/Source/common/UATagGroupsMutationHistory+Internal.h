/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsType+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsTransactionRecord+Internal.h"
#import "UATagGroups.h"
#import "UATagGroupsHistory.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the local history of tag group mutations.
 */
@interface UATagGroupsMutationHistory : NSObject<UATagGroupsHistory>

/**
 * UATagGroupsMutationHistory class factory method.
 *
 * @param dataStore A preference data store to use for persistence.
 */
+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Returns all pending mutations, collapsing both channel and
 * named user tag group mutations into a single array.
 *
 * @return An array of tag group mutations.
 */
- (NSArray<UATagGroupsMutation *> *)pendingMutations;

/**
 * Returns all sent mutations, for both channel and named user
 * tag groups, which are newer than the provided maximum age in seconds.
 *
 * @return An array of tag group mutations.
 */
- (NSArray<UATagGroupsMutation *> *)sentMutationsWithMaxAge:(NSTimeInterval)maxAge;

/**
 * Adds a pending mutation.
 *
 * @param mutation The tag group mutation.
 * @param type The tag groups type.
 */
- (void)addPendingMutation:(UATagGroupsMutation *)mutation type:(UATagGroupsType)type;

/**
 * Adds a sent mutation.
 *
 * @param mutation The tag group mutation.
 * @param date The date the send was completed.
 */
- (void)addSentMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date;

/**
 * Peeks the top-most pending mutation from the queue corresponding to
 * the tag group type under consideration.
 *
 * @param type The tag groups type.
 */
- (UATagGroupsMutation *)peekPendingMutation:(UATagGroupsType)type;

/**
 * Pops the top-most pending mutation from the queue corresponding to
 * the provided tag groups type.
 *
 * @param type The tag groups type.
 */
- (UATagGroupsMutation *)popPendingMutation:(UATagGroupsType)type;

/**
 * Collapses pending mutations for the provided tag groups type.
 */
- (void)collapsePendingMutations:(UATagGroupsType)type;

/**
 * Clears pending mutations for the provided tag groups type.
 */
- (void)clearPendingMutations:(UATagGroupsType)type;

/**
 * Clears sent mutations.
 */
- (void)clearSentMutations;

/**
 * Clears all history.
 */
- (void)clearAll;


@end

NS_ASSUME_NONNULL_END
