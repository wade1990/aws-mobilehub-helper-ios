//
//  AWSIdentityManager.m
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSIdentityManager.h"
#import "AWSSignInProvider.h"
#import "AWSFacebookSignInProvider.h"
#import "AWSGoogleSignInProvider.h"
#import "AWSSignInProviderFactory.h"

NSString *const AWSIdentityManagerDidSignInNotification = @"com.amazonaws.AWSIdentityManager.AWSIdentityManagerDidSignInNotification";
NSString *const AWSIdentityManagerDidSignOutNotification = @"com.amazonaws.AWSIdentityManager.AWSIdentityManagerDidSignOutNotification";

typedef void (^AWSIdentityManagerCompletionBlock)(id result, NSError *error);

@interface AWSIdentityManager()

@property (nonatomic, readwrite, strong) AWSCognitoCredentialsProvider *credentialsProvider;
@property (atomic, copy) AWSIdentityManagerCompletionBlock completionHandler;

@property (nonatomic, strong) id<AWSSignInProvider> currentSignInProvider;
@property (nonatomic, strong) id<AWSSignInProvider> potentialSignInProvider;

@end

@interface AWSSignInProviderFactory()

-(NSArray<NSString *>*)getRegisterdSignInProviders;

@end

@implementation AWSIdentityManager

static NSString *const AWSInfoIdentityManager = @"IdentityManager";
static NSString *const AWSInfoRoot = @"AWS";
static NSString *const AWSInfoMobileHub = @"MobileHub";
static NSString *const AWSInfoProjectClientId = @"ProjectClientId";

+ (instancetype)defaultIdentityManager {
    static AWSIdentityManager *_defaultIdentityManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AWSServiceInfo *serviceInfo = [[AWSInfo defaultAWSInfo] defaultServiceInfo:AWSInfoIdentityManager];
        
        if (!serviceInfo) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"The service configuration is `nil`. You need to configure `Info.plist` before using this method."
                                         userInfo:nil];
        }
        _defaultIdentityManager = [[AWSIdentityManager alloc] initWithCredentialProvider:serviceInfo];
    });
    
    return _defaultIdentityManager;
}

- (instancetype)initWithCredentialProvider:(AWSServiceInfo *)serviceInfo {
    if (self = [super init]) {
        
        self.credentialsProvider = serviceInfo.cognitoCredentialsProvider;
        [self.credentialsProvider setIdentityProviderManagerOnce:self];
        
        // Init the ProjectTemplateId
        NSString *projectTemplateId = [[[AWSInfo defaultAWSInfo].rootInfoDictionary objectForKey:AWSInfoMobileHub] objectForKey:AWSInfoProjectClientId];
        if (!projectTemplateId) {
            projectTemplateId = @"MobileHub HelperFramework";
        }
        [AWSServiceConfiguration addGlobalUserAgentProductToken:projectTemplateId];
    }
    return self;
}

#pragma mark - AWSIdentityProviderManager

- (AWSTask<NSDictionary<NSString *, NSString *> *> *)logins {
    if (!self.currentSignInProvider) {
        return [AWSTask taskWithResult:nil];
    }
    return [[self.currentSignInProvider token] continueWithSuccessBlock:^id _Nullable(AWSTask<NSString *> * _Nonnull task) {
        NSString *token = task.result;
        return [AWSTask taskWithResult:@{self.currentSignInProvider.identityProviderName : token}];
    }];
}

#pragma mark -

- (NSString *)identityId {
    return self.credentialsProvider.identityId;
}

- (BOOL)isLoggedIn {
    return self.currentSignInProvider.isLoggedIn;
}

- (NSURL *)imageURL {
    return self.currentSignInProvider.imageURL;
}

- (NSString *)userName {
    return self.currentSignInProvider.userName;
}

- (void)wipeAll {
    [self.credentialsProvider clearKeychain];
}

- (void)logoutWithCompletionHandler:(void (^)(id result, NSError *error))completionHandler {
    if ([self.currentSignInProvider isLoggedIn]) {
        [self.currentSignInProvider logout];
    }
    
    [self wipeAll];
    
    self.currentSignInProvider = nil;
    
    [[self.credentialsProvider getIdentityId] continueWithBlock:^id _Nullable(AWSTask<NSString *> * _Nonnull task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter postNotificationName:AWSIdentityManagerDidSignOutNotification
                                              object:[AWSIdentityManager defaultIdentityManager]
                                            userInfo:nil];
            if (task.exception) {
                AWSLogError(@"Fatal exception: [%@]", task.exception);
                kill(getpid(), SIGKILL);
            }
            completionHandler(task.result, task.error);
        });
        return nil;
    }];
}

- (void)loginWithSignInProvider:(id)signInProvider
              completionHandler:(void (^)(id result, NSError *error))completionHandler {
    self.potentialSignInProvider = signInProvider;
    
    self.completionHandler = completionHandler;
    [self.potentialSignInProvider login:completionHandler];
}

- (void)resumeSessionWithCompletionHandler:(void (^)(id result, NSError *error))completionHandler {
    self.completionHandler = completionHandler;
    
    [self.currentSignInProvider reloadSession];
    
    if (self.currentSignInProvider == nil) {
        [self completeLogin];
    }
}

- (void)completeLogin {
    // Force a refresh of credentials to see if we need to merge
    [self.credentialsProvider invalidateCachedTemporaryCredentials];
    
    if (self.potentialSignInProvider) {
        self.currentSignInProvider = self.potentialSignInProvider;
        self.potentialSignInProvider = nil;
    }
    
    [[self.credentialsProvider credentials] continueWithBlock:^id _Nullable(AWSTask<AWSCredentials *> * _Nonnull task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentSignInProvider) {
                NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                [notificationCenter postNotificationName:AWSIdentityManagerDidSignInNotification
                                                  object:[AWSIdentityManager defaultIdentityManager]
                                                userInfo:nil];
            }
            if (task.exception) {
                AWSLogError(@"Fatal exception: [%@]", task.exception);
                kill(getpid(), SIGKILL);
            }
            self.completionHandler(task.result, task.error);
        });
        return nil;
    }];
}

- (BOOL)interceptApplication:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    for(NSString *key in [[AWSSignInProviderFactory sharedInstance] getRegisterdSignInProviders]) {
        if ([[[AWSSignInProviderFactory sharedInstance] signInProviderForKey:key] isCachedLoginFlagSet]) {
            self.currentSignInProvider = [[AWSSignInProviderFactory sharedInstance] signInProviderForKey:key];
        }
        
    }
    
    if (self.currentSignInProvider) {
        return [self.currentSignInProvider interceptApplication:application
                                  didFinishLaunchingWithOptions:launchOptions];
    } else {
        return YES;
    }
}

- (BOOL)interceptApplication:(UIApplication *)application
                     openURL:(NSURL *)url
           sourceApplication:(NSString *)sourceApplication
                  annotation:(id)annotation {
    if (self.potentialSignInProvider) {
        return [self.potentialSignInProvider interceptApplication:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
    }
    else {
        return YES;
    }
}

@end
