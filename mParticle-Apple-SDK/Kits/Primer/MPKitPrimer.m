//
//  MPKitPrimer.m
//
//  Copyright 2016 mParticle, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if defined(MP_KIT_PRIMER)

#import "MPKitPrimer.h"

#import <Primer/Primer.h>

#import "MPCommerceEvent.h"
#import "MPCommerceEvent+Dictionary.h"
#import "MPEvent.h"

@interface MPKitPrimer ()

@property (nonatomic, unsafe_unretained) BOOL automaticPresentation;

@end

@implementation MPKitPrimer

#pragma mark - Initialization

- (instancetype)initWithConfiguration:(NSDictionary *)configuration {
    
    self = [super initWithConfiguration:configuration];
    if (!self) {
        return nil;
    }

    NSString *token = configuration[@"apiKey"];
    if (token.length > 0) {
        return nil;
    }

    [Primer startWithToken:token];
    
    self.automaticPresentation = [configuration[@"autoPresent"] boolValue];
    if (self.automaticPresentation) {
        [Primer presentExperience];
    }
    
    self.active = YES;
    self.forwardedEvents = YES;
    frameworkAvailable = YES;
    started = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{mParticleKitInstanceKey: @(MPKitInstancePrimer), mParticleEmbeddedSDKInstanceKey: @(MPKitInstancePrimer)};
        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification object:nil userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleEmbeddedSDKDidBecomeActiveNotification object:nil userInfo:userInfo];
    });

    return self;
}

#pragma mark - User Attributes

- (MPKitExecStatus *)setUserAttribute:(NSString *)key value:(nullable NSString *)value {
    
    if (!value) {
        return [self statusWithCode:MPKitReturnCodeFail];
    }
    
    NSString *prefixedKey = [NSString stringWithFormat:@"mParticle.%@", key];
    [Primer appendUserProperties:@{prefixedKey: value}];
    
    return [self statusWithCode:MPKitReturnCodeSuccess];
}

#pragma mark - Events

- (MPKitExecStatus *)logEvent:(MPEvent *)event {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@"mParticle" forKey:@"pmr_event_api"];
    
    if (event.info) {
        [parameters addEntriesFromDictionary:event.info];
    }
    
    [Primer trackEventWithName:event.name parameters:parameters];
    
    return [self statusWithCode:MPKitReturnCodeSuccess];
}

- (MPKitExecStatus *)logScreen:(MPEvent *)event {
    
    MPKitExecStatus *status = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstancePrimer) returnCode:MPKitReturnCodeSuccess forwardCount:0];
    
    [self logEvent:event];
    [status incrementForwardCount];
    
    return status;
}

- (MPKitExecStatus *)logCommerceEvent:(MPCommerceEvent *)commerceEvent {
    
    MPKitExecStatus *status = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstancePrimer) returnCode:MPKitReturnCodeSuccess forwardCount:0];
    
    NSArray *expandedInstructions = [commerceEvent expandedInstructions];
    for (MPCommerceEventInstruction *commerceEventInstruction in expandedInstructions) {
        [self logEvent:commerceEventInstruction.event];
        [status incrementForwardCount];
    }
    
    return status;
}

#pragma mark - Application

- (MPKitExecStatus *)continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void(^)(NSArray * _Nullable restorableObjects))restorationHandler {
    
    [Primer continueUserActivity:userActivity];
    
    return [self statusWithCode:MPKitReturnCodeSuccess];
}

#pragma mark - Assorted

- (MPKitExecStatus *)setDebugMode:(BOOL)debugMode {
    
    PMRLoggingLevel loggingLevel = debugMode ? PMRLoggingLevelWarning : PMRLoggingLevelNone;
    [Primer setLoggingLevel:loggingLevel];
    
    return [self statusWithCode:MPKitReturnCodeSuccess];
}

#pragma mark - Utilities

- (MPKitExecStatus *)statusWithCode:(MPKitReturnCode)code {
    
    return [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstancePrimer) returnCode:code];
}

@end

#endif
