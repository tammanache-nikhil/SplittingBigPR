/* Copyright Airship and Contributors */

#import "UARemoteDataAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAirshipVersion.h"

@interface UARemoteDataAPIClient()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@end

@implementation UARemoteDataAPIClient

NSString * const kRemoteDataPath = @"api/remote-data/app";

NSString * const kUALastRemoteDataModifiedTime = @"UALastRemoteDataModifiedTime";

- (UARemoteDataAPIClient *)initWithConfig:(UARuntimeConfig *)config
                                dataStore:(UAPreferenceDataStore *)dataStore
                                  session:(UARequestSession *)session {
    self = [super initWithConfig:config session:session];
    
    if (self) {
        self.dataStore = dataStore;
    }
    
    return self;
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                session:[UARequestSession sessionWithConfig:config]];
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                    session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                session:session];
}

- (UADisposable *)fetchRemoteData:(UARemoteDataRefreshSuccessBlock)successBlock
                        onFailure:(UARemoteDataRefreshFailureBlock)failureBlock {

    UARequest *refreshRequest = [self requestToRefreshRemoteData];

    UA_LTRACE(@"Request to refresh remote data: %@", refreshRequest.URL);

    __block UARemoteDataRefreshSuccessBlock refreshRemoteDataSuccessBlock = successBlock;
    __block UARemoteDataRefreshFailureBlock refreshRemoteDataFailureBlock = failureBlock;
    
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        UA_LTRACE(@"Remote data refresh blocks disposed");
        refreshRemoteDataSuccessBlock = nil;
        refreshRemoteDataFailureBlock = nil;
    }];

    [self.session dataTaskWithRequest:refreshRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        
        // Failure
        if (httpResponse.statusCode != 200  && httpResponse.statusCode != 304) {
            [UAUtils logFailedRequest:refreshRequest withMessage:@"Refresh remote data failed" withError:error withResponse:httpResponse];
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }
        
        // 304, no changes
        if (httpResponse.statusCode == 304) {
            if (refreshRemoteDataSuccessBlock) {
                refreshRemoteDataSuccessBlock(httpResponse.statusCode, nil);
            }
            return;
        }
        
        // 200, success
        
        // Missing response body
        if (!data) {
            UA_LTRACE(@"Refresh remote data missing response body.");
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }
        
        // Success
        NSDictionary *headers = httpResponse.allHeaderFields;
        NSString *lastModified = [headers objectForKey:@"Last-Modified"];
        
        // Parse the response
        NSError *parseError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
        
        if (parseError) {
            UA_LERR(@"Unable to parse remote data body: %@ Error: %@", data, parseError);
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }

        UA_LTRACE(@"Retrieved remote data with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);
        
        NSArray *remoteData = [jsonResponse objectForKey:@"payloads"];
        
        [self.dataStore setValue:lastModified forKey:kUALastRemoteDataModifiedTime];
        
        if (refreshRemoteDataSuccessBlock) {
            refreshRemoteDataSuccessBlock(httpResponse.statusCode, remoteData);
        }
    }];
    
    return disposable;

}

- (UARequest *)requestToRefreshRemoteData {
    UA_WEAKIFY(self)
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        UA_STRONGIFY(self)

        builder.URL = [self createRemoteDataURL:[NSLocale autoupdatingCurrentLocale]];
        builder.method = @"GET";
        
        NSString *lastModified = [self.dataStore stringForKey:kUALastRemoteDataModifiedTime];
        
        if (lastModified) {
            [builder setValue:lastModified forHeader:@"If-Modified-Since"];
        }
    }];
    
    return request;
}

- (NSURL *)createRemoteDataURL:(NSLocale *)locale {
    NSURLQueryItem *languageItem = [NSURLQueryItem queryItemWithName:@"language"
                                                               value:[locale objectForKey:NSLocaleLanguageCode]];
    NSURLQueryItem *countryItem = [NSURLQueryItem queryItemWithName:@"country"
                                                              value:[locale objectForKey:NSLocaleCountryCode]];
    NSURLQueryItem *versionItem = [NSURLQueryItem queryItemWithName:@"sdk_version"
                                                              value:[UAirshipVersion get]];

    NSURLComponents *components = [NSURLComponents componentsWithString:self.config.remoteDataAPIURL];

    // api/remote-data/app/{appkey}/{platform}?sdk_version={version}&language={language}&country={country}
    components.path = [NSString stringWithFormat:@"/%@/%@/%@", kRemoteDataPath, self.config.appKey, @"ios"];

    NSMutableArray *queryItems = [NSMutableArray arrayWithObject:versionItem];

    if (languageItem.value != nil && languageItem.value.length != 0) {
        [queryItems addObject:languageItem];
    }

    if (countryItem.value != nil && countryItem.value.length != 0) {
        [queryItems addObject:countryItem];
    }

    components.queryItems = queryItems;

    return [components URL];
}

- (void)clearLastModifiedTime {
    [self.dataStore removeObjectForKey:kUALastRemoteDataModifiedTime];
}

@end
