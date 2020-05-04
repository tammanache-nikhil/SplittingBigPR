/* Copyright Airship and Contributors */

#import "UANativeBridge+Internal.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAWhitelist.h"
#import "UAJavaScriptCommand.h"
#import "NSString+UAURLEncoding.h"
#import "UANativeBridgeActionHandler+Internal.h"

NSString *const UANativeBridgeUAirshipScheme = @"uairship";
NSString *const UANativeBridgeCloseCommand = @"close";

@interface UANativeBridge()
@property (nonatomic, strong, nonnull) UANativeBridgeActionHandler *actionHandler;
@property (nonatomic, copy, nonnull) UAJavaScriptEnvironment *(^javaScriptEnvironmentFactoryBlock)(void);
@end

@implementation UANativeBridge

#pragma mark UANavigationDelegate

- (instancetype)initWithActionHandler:(UANativeBridgeActionHandler *)actionHandler
    javaScriptEnvironmentFactoryBlock:(UAJavaScriptEnvironment *(^)(void))javaScriptEnvironmentFactoryBlock {

    self = [super init];
    if (self) {
        self.actionHandler = actionHandler;
        self.javaScriptEnvironmentFactoryBlock = javaScriptEnvironmentFactoryBlock;
    }

    return self;
}

+(instancetype)nativeBridge {
    return [[self alloc] initWithActionHandler:[[UANativeBridgeActionHandler alloc] init]
             javaScriptEnvironmentFactoryBlock:^UAJavaScriptEnvironment *{
        return [UAJavaScriptEnvironment defaultEnvironment];
    }];
}

+ (instancetype)nativeBridgeWithActionHandler:(UANativeBridgeActionHandler *)actionHandler
            javaScriptEnvironmentFactoryBlock:(UAJavaScriptEnvironment * (^)(void))javaScriptEnvironmentFactoryBlock {

    return [[self alloc] initWithActionHandler:actionHandler javaScriptEnvironmentFactoryBlock:javaScriptEnvironmentFactoryBlock];
}

/**
 * Decide whether to allow or cancel a navigation.
 *
 * If a uairship:// URL, process it ourselves
 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    WKNavigationType navigationType = navigationAction.navigationType;
    NSURLRequest *request = navigationAction.request;
    NSURL *originatingURL = webView.URL;

    // Always handle uairship urls
    if ([self isWhiteListedAirshipRequest:request originatingURL:originatingURL]) {
        if ((navigationType == WKNavigationTypeLinkActivated) || (navigationType == WKNavigationTypeOther)) {
            UAJavaScriptCommand *command = [UAJavaScriptCommand commandForURL:request.URL];
            [self handleAirshipCommand:command webView:webView];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    // If the forward delegate responds to the selector, let it decide
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [strongDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:^(WKNavigationActionPolicy policyForThisURL) {
            // Override any special link actions
            if ((policyForThisURL == WKNavigationActionPolicyAllow) && (navigationType == WKNavigationTypeLinkActivated)) {
              policyForThisURL = ([self handleLinkClick:request.URL]) ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow;
            }
            decisionHandler(policyForThisURL);
        }];
        return;
    }

    // Default behavior
    WKNavigationActionPolicy policyForThisURL = ([self handleLinkClick:request.URL]) ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow;
    decisionHandler(policyForThisURL);
}

/**
 * Decide whether to allow or cancel a navigation after its response is known.
 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:)]) {
        [strongDelegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
}

/**
 * Called when the navigation is complete.
 */
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self populateJavascriptEnvironmentIfWhitelisted:webView];
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [strongDelegate webView:webView didFinishNavigation:navigation];
    }
}

/**
 * Called when the web view’s web content process is terminated.
 */
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webViewWebContentProcessDidTerminate:)]) {
        [strongDelegate webViewWebContentProcessDidTerminate:webView];
    }
}

/**
 * Called when the web view begins to receive web content.
 */
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didCommitNavigation:)]) {
        [strongDelegate webView:webView didCommitNavigation:navigation];
    }
}

/**
 * Called when web content begins to load in a web view.
 */
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [strongDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

/**
 * Called when an error occurs during navigation.
 */
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [strongDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}

/**
 * Called when an error occurs while the web view is loading content.
 */
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [strongDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

/**
 * Called when a web view receives a server redirect.
 */
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didReceiveServerRedirectForProvisionalNavigation:)]) {
        [strongDelegate webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
    }
}

/**
 * Called when the web view needs to respond to an authentication challenge.
 */
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didReceiveAuthenticationChallenge:completionHandler:)]) {
        [strongDelegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)closeWindowAnimated:(BOOL)animated {
    id strongDelegate = self.forwardNavigationDelegate;
    if ([strongDelegate respondsToSelector:@selector(closeWindowAnimated:)]) {
        [strongDelegate closeWindowAnimated:animated];
    }
}

- (void)populateJavascriptEnvironmentIfWhitelisted:(WKWebView *)webView  {
    NSURL *url = webView.URL;
    if (![[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeJavaScriptInterface]) {
        // Don't log in the special case of about:blank URLs
        if (![url.absoluteString isEqualToString:@"about:blank"]) {
            UA_LDEBUG(@"URL %@ is not whitelisted, not populating JS interface", url);
        }
        return;
    }

    UAJavaScriptEnvironment *js = self.javaScriptEnvironmentFactoryBlock();
    id nativeBridgeExtensionDelegate = self.nativeBridgeExtensionDelegate;
    if ([nativeBridgeExtensionDelegate respondsToSelector:@selector(extendJavaScriptEnvironment:webView:)]) {
        [nativeBridgeExtensionDelegate extendJavaScriptEnvironment:js webView:webView];
    }

    [webView evaluateJavaScript:[js build] completionHandler:nil];
}

- (void)handleAirshipCommand:(UAJavaScriptCommand *)command webView:(WKWebView *)webView {
    // Close
    if ([command.name isEqualToString:UANativeBridgeCloseCommand]) {
        [self.nativeBridgeDelegate close];
        return;
    }

    // Actions
    if ([UANativeBridgeActionHandler isActionCommand:command]) {
        NSDictionary *metadata;
        id nativeBridgeExtensionDelegate = self.nativeBridgeExtensionDelegate;
        if ([nativeBridgeExtensionDelegate respondsToSelector:@selector(actionsMetadataForCommand:webView:)]) {
            metadata = [nativeBridgeExtensionDelegate actionsMetadataForCommand:command webView:webView];
        } else {
            metadata = @{};
        }

        __weak WKWebView *weakWebView = webView;
        [self.actionHandler runActionsForCommand:command
                                        metadata:metadata
                               completionHandler:^(NSString *script) {
            if (script) {
                [weakWebView evaluateJavaScript:script completionHandler:nil];
            }
        }];
        return;
    }

    // Local JavaScript command delegate
    if ([self.javaScriptCommandDelegate performCommand:command webView:webView]) {
        return;
    }

    // App defined JavaScript command delegate
    if ([[UAirship shared].javaScriptCommandDelegate performCommand:command webView:webView]) {
        return;
    }

    UA_LDEBUG(@"Unhandled JavaScript command: %@", command);
}

- (nullable NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url {
    NSString *decodedURLString = [url.absoluteString stringByRemovingPercentEncoding];
    NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
    NSString *strippedNumber = [[decodedURLString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];
    if (!strippedNumber) {
        return nil;
    }

    NSString *scheme = [decodedURLString hasPrefix:@"sms"] ? @"sms:" : @"tel:";
    return [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
}

/**
 * Handles a link click.
 *
 * @param url The link's URL.
 * @returns YES if the link was handled, otherwise NO.
 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (BOOL)handleLinkClick:(NSURL *)url {
    // Send iTunes/Phobos urls to AppStore.app
    if ([[url host] isEqualToString:@"phobos.apple.com"] || [[url host] isEqualToString:@"itunes.apple.com"]) {
        // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
        NSString *stringURL = [NSString stringWithFormat:@"http://%@%@", url.host, url.path];
        return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:stringURL]];
    }

    // Send maps.google.com url or maps: to GoogleMaps.app
    if ([[url host] isEqualToString:@"maps.google.com"] || [[url scheme] isEqualToString:@"maps"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send www.youtube.com url to YouTube.app
    if ([[url host] isEqualToString:@"www.youtube.com"]) {
         return [[UIApplication sharedApplication] openURL:url];
    }

    // Send mailto: to Mail.app
    if ([[url scheme] isEqualToString:@"mailto"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send tel: to Phone.app
    if ([[url scheme] isEqualToString:@"tel"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    // Send sms: to Messages.app
    if ([[url scheme] isEqualToString:@"sms"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    return NO;
}
#pragma GCC diagnostic pop

- (BOOL)isAirshipRequest:(NSURLRequest *)request {
    return [[request.URL scheme] isEqualToString:UANativeBridgeUAirshipScheme];
}

- (BOOL)isWhitelisted:(NSURL *)url {
    return [[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeJavaScriptInterface];
}

- (BOOL)isWhiteListedAirshipRequest:(NSURLRequest *)request originatingURL:(NSURL *)originatingURL {
    // uairship://command/[<arguments>][?<options>]
    return [self isAirshipRequest:request] && [self isWhitelisted:originatingURL];
}

@end

