//
//  MPSegment.m
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

#import "MPSegment.h"
#import "MPSegmentMembership.h"

NSString *const kMPSegmentListKey = @"m";
NSString *const kMPSegmentIdKey = @"id";
NSString *const kMPSegmentNameKey = @"n";
NSString *const kMPSegmentEndpointIds = @"s";
NSString *const kMPSegmentMembershipListKey = @"c";

@implementation MPSegment

@synthesize expiration = _expiration;

- (instancetype)initWithSegmentId:(NSNumber *)segmentId UUID:(NSString *)uuid name:(NSString *)name memberships:(NSArray<MPSegmentMembership *> *)memberships endpointIds:(NSArray *)endpointIds {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    [self addObserver:self
           forKeyPath:@"memberships"
              options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
              context:NULL];
    
    _segmentId = segmentId;
    _endpointIds = endpointIds;
    _uuid = uuid;
    _name = name;
    _memberships = memberships;
    
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)segmentDictionary {
    NSArray *membershipArray = segmentDictionary[kMPSegmentMembershipListKey];
    NSMutableArray<MPSegmentMembership *> *memberships = nil;
    int segmentId = [segmentDictionary[kMPSegmentIdKey] intValue];
    if (membershipArray.count > 0) {
        memberships = [[NSMutableArray alloc] initWithCapacity:membershipArray.count];
        
        MPSegmentMembership *segmentMembership;
        for (NSDictionary *membershipDictionary in membershipArray) {
            segmentMembership = [[MPSegmentMembership alloc] initWithSegmentId:segmentId membershipDictionary:membershipDictionary];
            [memberships addObject:segmentMembership];
        }
        
        NSSortDescriptor *sortDesciptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES];
        [memberships sortUsingDescriptors:@[sortDesciptor]];
    }

    return [self initWithSegmentId:@(segmentId)
                              UUID:[self newUUID]
                              name:segmentDictionary[kMPSegmentNameKey]
                       memberships:[memberships copy]
                       endpointIds:segmentDictionary[kMPSegmentEndpointIds]];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"memberships"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"MPSegment\n Id: %@\n Name: %@\n Memberships: %@\n", self.segmentId, self.name, self.memberships];
}

- (BOOL)isEqual:(MPSegment *)object {
//    unsigned int numberOfProperties;
//    class_copyPropertyList([self class], &numberOfProperties);
//    
//    if (numberOfProperties != 6) {
//        return NO;
//    }
    
    BOOL isEqual = [_segmentId isEqualToNumber:object.segmentId] &&
                   [_name isEqualToString:object.name] &&
                   [_memberships isEqualToArray:object.memberships];
    
    return isEqual;
}

#pragma mark KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"memberships"]) {
        _expiration = nil;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    MPSegment *copyObject = [[[self class] alloc] init];
    
    if (copyObject) {
        copyObject.segmentId = [_segmentId copy];
        copyObject.name = [_name copy];
        copyObject.memberships = [_memberships copy];
    }
    
    return copyObject;
}

#pragma mark Public Accessors
- (NSDate *)expiration {
    if (_expiration && [_expiration compare:[NSDate date]] != NSOrderedDescending) {
        return _expiration;
    }
    
    if (!_memberships) {
        _expiration = [NSDate distantFuture];
        return _expiration;
    } else {
        _expiration = [NSDate dateWithTimeIntervalSince1970:0];
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSUInteger numberOfMemberships = _memberships.count;
    NSInteger nextIdx = 1;
    MPSegmentMembership *nextSegmentMembership = nil;
    for (MPSegmentMembership *segmentMembership in _memberships) {
        nextSegmentMembership = (nextIdx < numberOfMemberships) ? _memberships[nextIdx] : nil;
        
        if (now >= segmentMembership.timestamp &&
            segmentMembership.action == MPSegmentMembershipActionAdd &&
            (now < nextSegmentMembership.timestamp || !nextSegmentMembership))
        {
            _expiration = nextSegmentMembership ? [NSDate dateWithTimeIntervalSince1970:nextSegmentMembership.timestamp] : [NSDate distantFuture];
            break;
        }
        
        ++nextIdx;
    }

    return _expiration;
}

- (BOOL)expired {
    if (!_memberships) {
        return NO;
    }
    
    NSDate *now = [NSDate date];
    BOOL expired = [now compare:self.expiration] == NSOrderedDescending;
    return expired;
}

@end
