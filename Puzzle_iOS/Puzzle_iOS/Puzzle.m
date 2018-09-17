//
//  Puzzle.m
//  HomePwner
//
//  Created by Hanguang on 26/11/2016.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

#import "Puzzle.h"
#import "PUZTimeRecord.h"
#import <libkern/OSAtomic.h>
#import <os/lock.h>
#import <pthread.h>
#import "FastestThreadSafeDictionary.h"
#include <sys/sysctl.h>

//#define RecordTime
NSString * const PuzzleFinishedNotification = @"com.hanguang.app.puzzle.PuzzleFinishedNotification";

@interface PuzzleFrame : NSObject
@property (nonatomic, copy) NSString *steps;
@property (nonatomic, assign) char *frame;
@property (nonatomic, assign) int previousStep;
@property (nonatomic, assign) int currentStep;
@end

@implementation PuzzleFrame

- (NSString *)description {
    return [NSString stringWithFormat:@"frame: %s, steps: %@, previousStep: %ld, currentStep: %ld", _frame, _steps, (long)_previousStep, (long)_currentStep];
}

@end

@interface Puzzle ()
@property (nonatomic, strong) FastestThreadSafeDictionary *frameSnapshot;
@property (nonatomic, strong) NSMutableArray *stepResults;
@property (nonatomic, assign) BOOL foundResults;
@property (nonatomic, assign) int threadCount;
@property (nonatomic, assign) int routesCount;
@property (nonatomic, assign) int routesIndex;
@property (nonatomic, strong) NSArray *routesQueue;
@property (nonatomic, strong) NSMutableArray *routesNextQueue;
@property (nonatomic, strong) NSMutableArray *threads;
@property (nonatomic, assign) BOOL isThreadRunning;
@property (nonatomic, assign) BOOL switchedQueue;

@end

static NSString *getIndexKey = @"getIndex";
static NSString *charKey = @"char";
static NSString *stringKey = @"string";
static NSString *hashKey = @"hash";
static NSString *frameKey = @"frame";
static NSString *routesKey = @"routes";

static NSString * const endIndexKey = @"com.hanguang.app.puzzle.endIndexKey";

@implementation Puzzle {
    pthread_mutex_t _routesQueueMutexLock;
    pthread_mutex_t _routesIndexMutexLock;
    pthread_mutex_t _frameMutexLock;
    pthread_mutex_t _stepResultMutexLock;
    NSMutableDictionary *_moveTileCountDict;
    int _availableThreadCount;
    PUZTimeRecord *_timeRecorder;
    int64_t _calcuatedFramesCount;
}

- (instancetype)initWithBeginFrame:(NSString *)beginFrame endFrame:(NSString *)endFrame columns:(int)columns row:(int)rows {
    self = [super init];
    if (self) {
        _beginFrame = beginFrame;
        _endFrame = endFrame;
        _columns = columns;
        _rows = rows;
        _timeRecorder = [PUZTimeRecord new];
        pthread_mutex_init(&_routesQueueMutexLock, NULL);
        pthread_mutex_init(&_routesIndexMutexLock, NULL);
        pthread_mutex_init(&_frameMutexLock, NULL);
        pthread_mutex_init(&_stepResultMutexLock, NULL);
        _moveTileCountDict = [NSMutableDictionary new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedCalculating:) name:PuzzleFinishedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_routesQueueMutexLock);
    pthread_mutex_destroy(&_routesIndexMutexLock);
    pthread_mutex_destroy(&_frameMutexLock);
    pthread_mutex_destroy(&_stepResultMutexLock);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (int)totalTilesCount {
    return _columns * _rows;
}

- (int)availableThreadCount {
    return _availableThreadCount;
}

- (void)calculateSteps {
    _foundResults = NO;
    _routesQueue = [NSArray new];
    _routesNextQueue = [NSMutableArray new];
    _frameSnapshot = [FastestThreadSafeDictionary new];
    _stepResults = [NSMutableArray new];
    _threadCount = 0;
    _routesIndex = -1;
    
    PuzzleFrame *frame = [PuzzleFrame new];
    frame.previousStep = 0;
    frame.currentStep = 0;
    frame.steps = @"";
    
    const char *beginChar = _beginFrame.UTF8String;
    char *chars = malloc(_beginFrame.length+1);
    memcpy(chars, beginChar, _beginFrame.length+1);
    frame.frame = chars;
    _routesNextQueue = [@[frame] mutableCopy];
    _routesCount = 0;
    _frameSnapshot[[NSString stringWithFormat:@"%s", chars]] = @(frame.steps.length);
    _calcuatedFramesCount += 1;
    
#if TARGET_OS_SIMULATOR
    _availableThreadCount = 2;
#elif TARGET_OS_IPHONE
    _availableThreadCount = cpuCoreCount();
#endif
    
    _isThreadRunning = YES;
    _threads = [NSMutableArray arrayWithCapacity:_availableThreadCount];
    for (int i = 0; i < _availableThreadCount; i++) {
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(startCalcOnThread) object:nil];
        thread.qualityOfService = NSQualityOfServiceUserInitiated;
        thread.name = [NSString stringWithFormat:@"%i", i];
        [_threads addObject:thread];
    }
    
    for (NSThread *thread in _threads) {
        [thread start];
    }
    
    //        NSLog(@"Total MT_Count: %@", _moveTileCountDict[@"total"]);
}

- (void)finishedCalculating:(NSNotification *)noti {
    for (NSThread *thread in _threads) {
#ifdef RecordTime
        NSLog(@"index:%@, char:%@, string:%@, hash:%@, frame:%@, routes:%@, %@",
              [_timeRecorder totalTimeElapsed:getIndexKey thread:thread],
              [_timeRecorder totalTimeElapsed:charKey thread:thread],
              [_timeRecorder totalTimeElapsed:stringKey thread:thread],
              [_timeRecorder totalTimeElapsed:hashKey thread:thread],
              [_timeRecorder totalTimeElapsed:frameKey thread:thread],
              [_timeRecorder totalTimeElapsed:routesKey thread:thread],
              thread.name);
#endif
        [thread cancel];
    }
}

- (void)startCalcOnThread {
    while (_isThreadRunning) { @autoreleasepool {
#ifdef RecordTime
        [_timeRecorder beginTimeRecord:getIndexKey];
#endif
        pthread_mutex_lock(&_routesIndexMutexLock);
        if (_threadCount == 0) {
            // Check if we have a result
            if (_stepResults.count > 0 && _threadCount == 0) {
                _isThreadRunning = NO;
                _foundResults = YES;
                for (NSString *result in _stepResults) {
                    NSLog(@"Steps: %@, steps count: %ld total frame calcuated: %lld == thread: %@", result, result.length, _calcuatedFramesCount, [NSThread currentThread].name);
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PuzzleFinishedNotification object:nil userInfo:@{@"resutls":[_stepResults copy]}];
                });
                pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
                [_timeRecorder continueTimeRecord:getIndexKey];
#endif
                return;
            } else {
                if (_isThreadRunning) {
                    _switchedQueue = YES;
                    _threadCount += 1;
                    _routesQueue = [_routesNextQueue copy];
                    [_routesNextQueue removeAllObjects];
                    for (NSThread *thread in _threads) {
                        thread.threadDictionary[endIndexKey] = @0;
                    }
                } else {
                    pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
                    [_timeRecorder continueTimeRecord:getIndexKey];
#endif
                    return;
                }
            }
        }
        pthread_mutex_unlock(&_routesIndexMutexLock);
        
        BOOL shouldSleep = [[NSThread currentThread].threadDictionary[endIndexKey] integerValue] == -1;
        if (shouldSleep) {
#ifdef RecordTime
            [_timeRecorder continueTimeRecord:getIndexKey];
#endif
            [NSThread sleepForTimeInterval:0];
        } else {
            pthread_mutex_lock(&_routesIndexMutexLock);
            if (_switchedQueue == YES) {
                _switchedQueue = NO;
            } else {
                _threadCount += 1;
            }
            
            int threadIndex = [[NSThread currentThread].name intValue];
            int indexLimit = (int)(_routesQueue.count / _availableThreadCount) + 1;
            int indexOffset = indexLimit * threadIndex;
            int beginIndex = 0 + indexOffset;
            int endIndex = indexOffset + (indexLimit - 1);
            
            pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
            [_timeRecorder continueTimeRecord:getIndexKey];
#endif
            for (int index = beginIndex; index <= endIndex; index++) {
                if (index >= _routesQueue.count) {
                    break;
                }
                
                PuzzleFrame *previousFrame = _routesQueue[index];
                int previousStep = previousFrame.previousStep;
                int currentStep = previousFrame.currentStep;
                int nextStep = 0;
                
                // upward
                nextStep = currentStep - 4;
                if (nextStep >= 0 && nextStep != previousStep) {
                    [self moveTileWithFrame:previousFrame nextStep:nextStep direction:@"U"];
                }
                
                // downward
                nextStep = currentStep + 4;
                if (nextStep < [self totalTilesCount] && nextStep != previousStep) {
                    [self moveTileWithFrame:previousFrame nextStep:nextStep direction:@"D"];
                }
                
                // leftward
                nextStep = currentStep - 1;
                if (currentStep % _columns - 1 >= 0 && nextStep != previousStep) {
                    [self moveTileWithFrame:previousFrame nextStep:nextStep direction:@"L"];
                }
                
                // rightward
                nextStep = currentStep + 1;
                if (currentStep % _columns + 1 < _columns && nextStep != previousStep) {
                    [self moveTileWithFrame:previousFrame nextStep:nextStep direction:@"R"];
                }
            }
            
            // Finished this round, put thread into sleep
            [NSThread currentThread].threadDictionary[endIndexKey] = @(-1);
            pthread_mutex_lock(&_routesIndexMutexLock);
            _threadCount -= 1;
            pthread_mutex_unlock(&_routesIndexMutexLock);
        }
    }}
}

/*
- (int)getShareIndex {
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:getIndexKey];
#endif
    pthread_mutex_lock(&_routesIndexMutexLock);
    if (_routesIndex < _routesCount - 1) {
        _routesIndex += 1;
        _threadCount += 1;
    } else {
        if (_threadCount == 0) {
            if (_stepResults.count > 0) {
                _isThreadRunning = NO;
                _foundResults = YES;
                for (NSString *result in _stepResults) {
                    NSLog(@"Steps: %@, steps count: %ld == thread: %@", result, (long)result.length, [NSThread currentThread].name);
                }
                _stepResults = nil;
                pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
                [_timeRecorder continueTimeRecord:getIndexKey];
#endif
                return -1;
            } else {
                _routesIndex = 0;
                _threadCount += 1;
                _routesQueue = [_routesNextQueue copy];
                [_routesNextQueue removeAllObjects];
                _routesCount = (int)_routesQueue.count;
            }
        } else {
            pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
            [_timeRecorder continueTimeRecord:getIndexKey];
#endif
            return -1;
        }
    }
    pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:getIndexKey];
#endif
    return _routesIndex;
}
*/

- (void)moveTileWithFrame:(PuzzleFrame *)puzzleFrame nextStep:(int)nextStep direction:(NSString *)direction {
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:charKey];
#endif
    /*
        NSNumber *totalCount;
        if ([_moveTileCountDict objectForKey:@"total"] == nil) {
            totalCount = @1;
        } else {
            int total = [[_moveTileCountDict objectForKey:@"total"] intValue];
            total +=1;
            totalCount = @(total);
        }
        _moveTileCountDict[@"total"] = totalCount;
    
        NSNumber *moveTileCount;
        if ([_moveTileCountDict objectForKey:[NSThread currentThread].name] == nil) {
            moveTileCount = @1;
        } else {
            int count = [[_moveTileCountDict objectForKey:[NSThread currentThread].name] intValue];
            count +=1;
            moveTileCount = @(count);
        }
        _moveTileCountDict[[NSThread currentThread].name] = moveTileCount;
    */
    
    char *chars = malloc(_endFrame.length+1);
    memcpy(chars, puzzleFrame.frame, _endFrame.length+1);
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:charKey];
#endif
    
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:stringKey];
#endif
    NSString *steps = [puzzleFrame.steps stringByAppendingString:direction];
    NSInteger stepsLength = steps.length;
    int currentStep = puzzleFrame.currentStep;
    
    char temp = chars[currentStep];
    chars[currentStep] = chars[nextStep];
    chars[nextStep] = temp;
    NSString *newFrame = [NSString stringWithFormat:@"%s", chars];
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:stringKey];
#endif
    
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:hashKey];
#endif
    if (newFrame.hash == _endFrame.hash) {
        pthread_mutex_lock(&_stepResultMutexLock);
        [_stepResults addObject:steps];
        pthread_mutex_unlock(&_stepResultMutexLock);
    }
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:hashKey];
#endif
    
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:frameKey];
#endif
    NSInteger length = [[_frameSnapshot objectForKey:newFrame] integerValue];
    if (length != 0) {
//        return;
        if (length < stepsLength) {
            return;
        }
    } else {
        [_frameSnapshot setObject:@(stepsLength) forKey:newFrame];
    }
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:frameKey];
#endif
    
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:routesKey];
#endif
    PuzzleFrame *newPuzzleFrame = [PuzzleFrame new];
    newPuzzleFrame.frame = chars;
    newPuzzleFrame.steps = steps;
    newPuzzleFrame.previousStep = currentStep;
    newPuzzleFrame.currentStep = nextStep;

    pthread_mutex_lock(&_routesQueueMutexLock);
    [_routesNextQueue addObject:newPuzzleFrame];
    _calcuatedFramesCount += 1;
    pthread_mutex_unlock(&_routesQueueMutexLock);
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:routesKey];
#endif
}

int cpuCoreCount() {
    static int count = 0;
    if (count == 0) {
        size_t len;
        unsigned int ncpu;
        
        len = sizeof(ncpu);
        sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
        count = ncpu;
    }
    
    return count;
}

@end
