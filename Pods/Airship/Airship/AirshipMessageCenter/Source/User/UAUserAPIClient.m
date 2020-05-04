/* Copyright Airship and Contributors */

#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

@implementation UAUserAPIClient

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [UAUserAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

- (void)createUserWithChannelID:(NSString *)channelID
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [payload setObject:@[channelID] forKey:@"ios_channels"];
    }

    UARequest *request = [self requestToCreateUserWithPayload:payload];

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 201) {
            UA_LTRACE(@"User creation failed with status: %ld error: %@", (unsigned long)status, error);
            failureBlock(status);
            return;
        }

        // Success
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

        NSString *username = [jsonResponse objectForKey:@"user_id"];
        NSString *password = [jsonResponse objectForKey:@"password"];

        if (!username || !password) {
            UA_LTRACE(@"User creation failed. Missing ID or password");
            failureBlock(status);
            return;
        }

        UA_LTRACE(@"Created user: %@", username);
        UAUserData *userData = [UAUserData dataWithUsername:username password:password];
        successBlock(userData);
    }];
}

- (void)updateUserWithData:(UAUserData *)userData
                 channelID:(NSString *)channelID
                 onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
                 onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [payload setValue:@{@"add": @[channelID]} forKey:@"ios_channels"];
    }

    UARequest *request = [self requestToUpdateUser:userData payload:payload];
    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 200 && status != 201) {
            UA_LTRACE(@"User update failed with status: %ld error: %@", (unsigned long)status, error);
            failureBlock(status);

            return;
        }

        // Success
        UA_LTRACE(@"Successfully updated user: %@", userData.username);
        successBlock();
    }];
}

- (UARequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *createURLString = [NSString stringWithFormat:@"%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/"];

        builder.URL = [NSURL URLWithString:createURLString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [UAJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LTRACE(@"Request to create user with body: %@", builder.body);
    }];

    return request;
}

- (UARequest *)requestToUpdateUser:(UAUserData *)userData payload:(NSDictionary *)payload {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *updateURLString = [NSString stringWithFormat:@"%@%@%@/",
                                     self.config.deviceAPIURL,
                                     @"/api/user/",
                                     userData.username];

        builder.URL = [NSURL URLWithString:updateURLString];
        builder.method = @"POST";
        builder.username = userData.username;
        builder.password = userData.password;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [UAJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LTRACE(@"Request to update user with body: %@", builder.body);
    }];

    return request;
}

@end
