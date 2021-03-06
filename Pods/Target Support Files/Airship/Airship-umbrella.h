#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AirshipAutomationLib.h"
#import "NSObject+AnonymousKVO+Internal.h"
#import "UAActionAutomation+Internal.h"
#import "UAActionAutomation.h"
#import "UAActionScheduleEdits.h"
#import "UAActionScheduleInfo+Internal.h"
#import "UAActionScheduleInfo.h"
#import "UAActiveTimer+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationEngine+Internal.h"
#import "UAAutomationModuleLoader.h"
#import "UAAutomationResources.h"
#import "UAAutomationStore+Internal.h"
#import "UACancelSchedulesAction.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageAssetManager.h"
#import "UAInAppMessageAssets+Internal.h"
#import "UAInAppMessageAssets.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageAudience.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageBannerStyle.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageButton+Internal.h"
#import "UAInAppMessageButtonInfo+Internal.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UAInAppMessageCustomDisplayContent.h"
#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageDisplayCoordinator.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageFullScreenStyle.h"
#import "UAInAppMessageFullScreenViewController+Internal.h"
#import "UAInAppMessageHTMLAdapter.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAInAppMessageHTMLStyle.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageImmediateDisplayCoordinator.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageMediaInfo+Internal.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageMediaStyle.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageModalAdapter.h"
#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageModalStyle.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAInAppMessageResolution+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessageSceneManager+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAInAppMessageScheduleEdits+Internal.h"
#import "UAInAppMessageScheduleEdits.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageStyleProtocol.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAInAppMessageTextInfo+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UAInAppMessagingTagGroupsConfig+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UALandingPageAction+Internal.h"
#import "UALandingPageAction.h"
#import "UALandingPageActionPredicate+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UALegacyInAppMessaging.h"
#import "UARetriable+Internal.h"
#import "UARetriablePipeline+Internal.h"
#import "UASchedule+Internal.h"
#import "UASchedule.h"
#import "UAScheduleAction.h"
#import "UAScheduleData+Internal.h"
#import "UAScheduleDataMigrator+Internal.h"
#import "UAScheduleDelay.h"
#import "UAScheduleDelayData+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "UAScheduleEdits.h"
#import "UAScheduleInfo+Internal.h"
#import "UAScheduleInfo.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAScheduleTrigger.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UATimerScheduler+Internal.h"
#import "AirshipLib.h"
#import "UAActivityViewController.h"
#import "UAChannelCapture.h"
#import "UAChannelCaptureAction.h"
#import "UAJavaScriptCommand.h"
#import "UAJavaScriptCommandDelegate.h"
#import "UAJavaScriptEnvironment.h"
#import "UANativeBridge.h"
#import "UANativeBridgeDelegate.h"
#import "UANativeBridgeExtensionDelegate.h"
#import "UAPasteboardAction.h"
#import "UAShareAction.h"
#import "UAWalletAction.h"
#import "UAWebView.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSManagedObjectContext+UAAdditions.h"
#import "NSOperationQueue+UAAdditions.h"
#import "NSString+UALocalizationAdditions.h"
#import "NSString+UAURLEncoding.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAAccountEventTemplate.h"
#import "UAAction+Operators.h"
#import "UAAction.h"
#import "UAActionArguments.h"
#import "UAActionPredicateProtocol.h"
#import "UAActionRegistry.h"
#import "UAActionRegistryEntry.h"
#import "UAActionResult.h"
#import "UAActionRunner.h"
#import "UAAddCustomEventAction.h"
#import "UAAddTagsAction.h"
#import "UAAggregateActionResult.h"
#import "UAAnalytics.h"
#import "UAAnalyticsEventConsumerProtocol.h"
#import "UAAPIClient.h"
#import "UAAppIntegration.h"
#import "UAApplicationMetrics.h"
#import "UAApplicationState.h"
#import "UAAppStateTracker.h"
#import "UAAssociatedIdentifiers.h"
#import "UAAsyncOperation.h"
#import "UAAttributeMutations.h"
#import "UAAutomationModuleLoaderFactory.h"
#import "UABespokeCloseView.h"
#import "UABeveledLoadingIndicator.h"
#import "UAChannel.h"
#import "UAChannelNotificationCenterEvents.h"
#import "UAChannelRegistrationPayload.h"
#import "UACircularRegion.h"
#import "UAColorUtils.h"
#import "UAComponent.h"
#import "UAConfig.h"
#import "UACustomEvent.h"
#import "UADate.h"
#import "UADeepLinkAction.h"
#import "UADispatcher.h"
#import "UADisposable.h"
#import "UAEnableFeatureAction.h"
#import "UAEvent.h"
#import "UAExtendableAnalyticsHeaders.h"
#import "UAExtendableChannelRegistration.h"
#import "UAExtendedActionsModuleLoaderFactory.h"
#import "UAFetchDeviceInfoAction.h"
#import "UAGlobal.h"
#import "UAInstallAttributionEvent.h"
#import "UAirship.h"
#import "UAirshipCoreResources.h"
#import "UAirshipVersion.h"
#import "UAJSONMatcher.h"
#import "UAJSONPredicate.h"
#import "UAJSONSerialization.h"
#import "UAJSONValueMatcher.h"
#import "UAKeychainUtils.h"
#import "UALocationModuleLoaderFactory.h"
#import "UALocationProvider.h"
#import "UAMediaEventTemplate.h"
#import "UAMessageCenterModuleLoaderFactory.h"
#import "UAModifyTagsAction.h"
#import "UAModuleLoader.h"
#import "UANamedUser.h"
#import "UANotificationAction.h"
#import "UANotificationCategories.h"
#import "UANotificationCategory.h"
#import "UANotificationContent.h"
#import "UANotificationResponse.h"
#import "UANSDictionaryValueTransformer.h"
#import "UANSURLValueTransformer.h"
#import "UAOpenExternalURLAction.h"
#import "UAPadding.h"
#import "UAPreferenceDataStore.h"
#import "UAProximityRegion.h"
#import "UAPush.h"
#import "UAPushableComponent.h"
#import "UAPushProviderDelegate.h"
#import "UARegionEvent.h"
#import "UARemoteDataPayload.h"
#import "UARemoteDataProvider.h"
#import "UARemoveTagsAction.h"
#import "UARequest.h"
#import "UARequestSession.h"
#import "UARetailEventTemplate.h"
#import "UARuntimeConfig.h"
#import "UASystemVersion.h"
#import "UATagGroups.h"
#import "UATagGroupsHistory.h"
#import "UATextInputNotificationAction.h"
#import "UAUtils.h"
#import "UAVersionMatcher.h"
#import "UAViewUtils.h"
#import "UAWhitelist.h"
#import "UA_Base64.h"
#import "AirshipExtendedActionsLib.h"
#import "UARateAppAction.h"
#import "UAExtendedActionsCoreImport.h"
#import "UAExtendedActionsModuleLoader.h"
#import "UAExtendedActionsResources.h"
#import "UAMessageCenterAction.h"
#import "AirshipMessageCenterLib.h"
#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenterDateUtils.h"
#import "UAMessageCenterListCell.h"
#import "UAMessageCenterListViewController.h"
#import "UAMessageCenterLocalization.h"
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenterMessageViewProtocol.h"
#import "UAMessageCenterSplitViewController.h"
#import "UAMessageCenterStyle.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInboxUtils.h"
#import "UAMessageCenterNativeBridgeExtension.h"
#import "UAAirshipMessageCenterCoreImport.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterModuleLoader.h"
#import "UAMessageCenterResources.h"
#import "UAUser.h"
#import "UAUserData.h"

FOUNDATION_EXPORT double AirshipVersionNumber;
FOUNDATION_EXPORT const unsigned char AirshipVersionString[];

