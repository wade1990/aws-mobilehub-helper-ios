//
//  AWSMSDynamicsAuthorizationManager.m
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSMSDynamicsAuthorizationManager.h"
#import <AWSCore/AWSCore.h>

static NSString *const AWSMSDynamicsAuthorizationManagerAuthorizeURLString = @"https://login.microsoftonline.com/common/oauth2/authorize";
static NSString *const AWSMSDynamicsAuthorizationManagerTokenURLString = @"https://login.microsoftonline.com/common/oauth2/token";
static NSString *const AWSMSDynamicsAuthorizationManagerLogoutURLString = @"https://login.microsoftonline.com/common/oauth2/logout";

static NSString *const AWSMSDynamicsAuthorizationManagerCodeKey = @"code";
static NSString *const AWSMSDynamicsAuthorizationManagerAccessTokenKey = @"access_token";
static NSString *const AWSMSDynamicsAuthorizationManagerTokenTypeKey = @"token_type";

typedef void (^AWSCompletionBlock)(id result, NSError *error);

@interface AWSAuthorizationManager()

- (void)completeLoginWithResult:(id)result
                          error:(NSError *)error;
- (void)destroyAccessToken;

@end

@interface AWSMSDynamicsAuthorizationManager()

@property (strong, nonatomic) NSString *authorizeURLString;
@property (strong, nonatomic) NSString *clientID;
@property (strong, nonatomic) NSString *redirectURI;
@property (strong, nonatomic, getter=getResourceURL) NSString *resource;

@property (strong, nonatomic) NSDictionary *valuesFromResponse;

@end

@implementation AWSMSDynamicsAuthorizationManager

+ (instancetype)sharedInstance {
    static AWSMSDynamicsAuthorizationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AWSMSDynamicsAuthorizationManager alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSDictionary *config = [[[AWSInfo defaultAWSInfo].rootInfoDictionary objectForKey:@"SaaS"] objectForKey:@"MSDynamics"];
        _clientID = [config objectForKey:@"ClientID"];
        _redirectURI = [config objectForKey:@"RedirectURI"];
        _resource = [config objectForKey:@"ResourceURL"];
        
        return self;
    }
    return nil;
}

- (void)configureWithClientID:(NSString *)clientID
                  redirectURI:(NSString *)redirectURI
                     resource:(NSString *)resource {
    self.clientID = clientID ?: @"";
    self.redirectURI = redirectURI ?: @"";
    self.resource = resource ?: @"";
}

- (NSString *)getTokenType {
    return [self.valuesFromResponse objectForKey:AWSMSDynamicsAuthorizationManagerTokenTypeKey];
}

- (NSString *)getAccessToken {
    return [self.valuesFromResponse objectForKey:AWSMSDynamicsAuthorizationManagerAccessTokenKey];
}

#pragma mark - Override Custom Methods

- (BOOL)usesImplicitGrant {
    return NO;
}

- (NSURL *)generateAuthURL {
    NSDictionary *params = @{@"client_id" : self.clientID,
                             @"response_type" : @"code",
                             @"response_mode" : @"query",
                             @"resource" : [self.resource stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                             @"redirect_uri" : [self.redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                             };
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", AWSMSDynamicsAuthorizationManagerAuthorizeURLString, [AWSAuthorizationManager constructURIWithParameters:params]];
    return [NSURL URLWithString:urlString];
}

- (NSString *)findAccessCode:(NSURL *)url {
    NSString *urlHeadRemoved = [[url absoluteString] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@?", self.redirectURI] withString:@""];
    NSDictionary *returnedValues = [AWSAuthorizationManager constructParametersWithURI:urlHeadRemoved];
    [self getAccessTokenUsingAuthorizationCode:[returnedValues objectForKey:AWSMSDynamicsAuthorizationManagerCodeKey]];
    return nil;
}

- (NSString *)getAccessTokenUsingAuthorizationCode:(NSString *)authorizationCode {
    NSDictionary *params = @{@"grant_type" : @"authorization_code",
                             @"code" : authorizationCode,
                             @"client_id" : self.clientID,
                             @"redirect_uri" : self.redirectURI,
                             };
    
    NSString *post = [AWSAuthorizationManager constructURIWithParameters:params];
    
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:AWSMSDynamicsAuthorizationManagerTokenURLString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    __weak AWSMSDynamicsAuthorizationManager *weakSelf = self;
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [weakSelf completeLoginWithResult:nil error:error];
            return;
        }
        
        weakSelf.valuesFromResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        [weakSelf completeLoginWithResult:[self.valuesFromResponse objectForKey:AWSMSDynamicsAuthorizationManagerAccessTokenKey] error:nil];
    }];
    [task resume];
    
    return nil;
}

- (BOOL)isAcceptedURL:(NSURL *)url {
    return [[url absoluteString] hasPrefix:self.redirectURI];
}

- (NSURL *)generateLogoutURL {
    return [NSURL URLWithString:AWSMSDynamicsAuthorizationManagerLogoutURLString];
}

- (void)destroyAccessToken {
    [super destroyAccessToken];
    self.valuesFromResponse = nil;
}

@end
