//
//  PUZTimeRecord.h
//  Puzzle
//
//  Created by Hanguang on 05/12/2016.
//  Copyright © 2016 Hanguang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PUZTimeRecord : NSObject

- (void)beginTimeRecord:(NSString *)key;
- (void)continueTimeRecord:(NSString *)key;
- (NSString *)totalTimeElapsed:(NSString *)key thread:(NSThread *)thread;

@end
