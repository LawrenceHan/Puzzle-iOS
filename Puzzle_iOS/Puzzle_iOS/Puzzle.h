//
//  Puzzle.h
//  HomePwner
//
//  Created by Hanguang on 26/11/2016.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const PuzzleFinishedNotification;

@interface Puzzle : NSObject

@property (nonatomic, readonly) NSString *beginFrame;
@property (nonatomic, readonly) NSString *endFrame;
@property (nonatomic, readonly) int columns;
@property (nonatomic, readonly) int rows;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithBeginFrame:(NSString *)beginFrame endFrame:(NSString *)endFrame columns:(int)columns row:(int)rows;
- (void)calculateSteps;
- (int)availableThreadCount;

@end
