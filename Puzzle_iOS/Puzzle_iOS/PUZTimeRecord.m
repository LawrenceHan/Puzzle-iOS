//
//  PUZTimeRecord.m
//  Puzzle
//
//  Created by Hanguang on 05/12/2016.
//  Copyright © 2016 Hanguang. All rights reserved.
//

#import "PUZTimeRecord.h"

@interface Record : NSObject
@property (nonatomic, assign) CFAbsoluteTime lastUpdateTime;
@property (nonatomic, assign) CFAbsoluteTime executionTime;

@end

@implementation Record

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastUpdateTime = 0.0;
        _executionTime = 0.0;
    }
    return self;
}

@end

@interface PUZTimeRecord ()
@property (nonatomic, readonly) NSMutableDictionary *records;

@end

@implementation PUZTimeRecord

- (NSMutableDictionary *)records {
    return [NSThread currentThread].threadDictionary;
}

- (void)beginTimeRecord:(NSString *)key {
    Record *record = nil;
    if ([[self records] objectForKey:key] != nil) {
        record = [self records][key];
    } else {
        record = [Record new];
        [self records][key] = record;
    }
    record.lastUpdateTime = CFAbsoluteTimeGetCurrent();
}

- (void)continueTimeRecord:(NSString *)key {
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    Record *record = [self records][key];
    record.executionTime += (currentTime - record.lastUpdateTime);
    record.lastUpdateTime = currentTime;
}

- (NSString *)totalTimeElapsed:(NSString *)key thread:(NSThread *)thread {
    return [NSString stringWithFormat:@"%f s", [(Record *)thread.threadDictionary[key] executionTime]];
}

@end
