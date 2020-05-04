/* Copyright Airship and Contributors */

#import "UAMessageCenterNativeBridgeExtension.h"
#import "UAMessageCenter.h"
#import "UAInboxMessageList.h"
#import "UAUser.h"
#import "UAInboxMessage.h"

#import "UAAirshipMessageCenterCoreImport.h"

@implementation UAMessageCenterNativeBridgeExtension

- (NSDictionary *)actionsMetadataForCommand:(UAJavaScriptCommand *)command webView:(WKWebView *)webView {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    UAInboxMessage *message = [[UAMessageCenter shared].messageList messageForBodyURL:webView.URL];
    [metadata setValue:message.messageID forKey:UAActionMetadataInboxMessageIDKey];
    return [metadata copy];
}

- (void)extendJavaScriptEnvironment:(UAJavaScriptEnvironment *)js webView:(WKWebView *)webView {
    UAInboxMessage *message = [[UAMessageCenter shared].messageList messageForBodyURL:webView.URL];
    if (!message) {
        return;
    }

    UAUserData *userData = [[UAMessageCenter shared].user getUserDataSync];
    NSNumber *messageSentDateMS = nil;
    NSString *messageSentDate = nil;
    if (message.messageSent) {
       messageSentDateMS = [NSNumber numberWithDouble:[message.messageSent timeIntervalSince1970] * 1000];
       messageSentDate = [[UAUtils ISODateFormatterUTC] stringFromDate:message.messageSent];
    }

    // Message data
    [js addStringGetter:@"getMessageId" value:message.messageID];
    [js addStringGetter:@"getMessageTitle" value:message.title];
    [js addNumberGetter:@"getMessageSentDateMS" value:messageSentDateMS];
    [js addStringGetter:@"getMessageSentDate" value:messageSentDate];
    [js addStringGetter:@"getUserId" value:userData.username];
}

@end
