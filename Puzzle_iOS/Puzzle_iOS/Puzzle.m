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

#define RecordTime

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
@property (nonatomic, assign) NSUInteger totalStepCounts;
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
    NSLock * _routesQueueLock;
    NSLock * _routesIndexLock;
    NSLock * _frameLock;
    NSLock * _stepResultLock;
    int32_t volatile _frameLockFlag;
    int32_t volatile _routesIndexFlag;
    os_unfair_lock _routesIndexSpinLock;
    os_unfair_lock _routesQueueSpinLock;
    os_unfair_lock _frameSpinLock;
    pthread_mutex_t _routesQueueMutexLock;
    pthread_mutex_t _routesIndexMutexLock;
    pthread_mutex_t _frameMutexLock;
    pthread_mutex_t _stepResultMutexLock;
    NSMutableDictionary *_moveTileCountDict;
    int _availableThreadCount;
    PUZTimeRecord *_timeRecorder;
}

- (instancetype)initWithBeginFrame:(NSString *)beginFrame endFrame:(NSString *)endFrame columns:(int)columns row:(int)rows {
    self = [super init];
    if (self) {
        _beginFrame = beginFrame;
        _endFrame = endFrame;
        _columns = columns;
        _rows = rows;
        
        _routesQueueLock = [[NSLock alloc] init];
        _routesIndexLock = [[NSLock alloc] init];
        _frameLock = [[NSLock alloc] init];
        _stepResultLock = [[NSLock alloc] init];
        _timeRecorder = [PUZTimeRecord new];
        _frameLockFlag = 0;
        _routesIndexFlag = 0;
        _routesIndexSpinLock = OS_UNFAIR_LOCK_INIT;
        _routesQueueSpinLock = OS_UNFAIR_LOCK_INIT;
        _frameSpinLock = OS_UNFAIR_LOCK_INIT;
        pthread_mutex_init(&_routesQueueMutexLock, NULL);
        pthread_mutex_init(&_routesIndexMutexLock, NULL);
        pthread_mutex_init(&_frameMutexLock, NULL);
        pthread_mutex_init(&_stepResultMutexLock, NULL);
        _moveTileCountDict = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_routesQueueMutexLock);
    pthread_mutex_destroy(&_routesIndexMutexLock);
    pthread_mutex_destroy(&_frameMutexLock);
    pthread_mutex_destroy(&_stepResultMutexLock);
}

- (int)totalTilesCount {
    return _columns * _rows;
}

- (NSArray <NSString *>*)calculateSteps {
    _routesQueue = [NSArray new];
    _routesNextQueue = [NSMutableArray new];
    _frameSnapshot = [FastestThreadSafeDictionary new];
    _stepResults = [NSMutableArray new];
    _totalStepCounts = 0;
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
    
    _isThreadRunning = YES;
    _availableThreadCount = 4;//cpuCoreCount();
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
    
    _foundResults = NO;
    while (_foundResults == NO) {
        [NSThread sleepForTimeInterval:0];
    }
    
    //        NSLog(@"Total MT_Count: %@", _moveTileCountDict[@"total"]);
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
    
    return [_stepResults copy];
}

- (void)startCalcOnThread {
    while (_isThreadRunning) { @autoreleasepool {
#ifdef RecordTime
        [_timeRecorder beginTimeRecord:getIndexKey];
#endif
        //    [_routesIndexLock lock];
        //    os_unfair_lock_lock(&_routesIndexSpinLock);
        //        pthread_mutex_lock(&_routesIndexMutexLock);
        
        pthread_mutex_lock(&_routesIndexMutexLock);
        if (_threadCount == 0) {
            // Check if we have a result
            if (_stepResults.count > 0) {
                _isThreadRunning = NO;
                _foundResults = YES;
                for (NSString *result in _stepResults) {
                    NSLog(@"Steps: %@, steps count: %ld == thread: %@", result, (long)result.length, [NSThread currentThread].name);
                }
//                _stepResults = nil;
                pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
                [_timeRecorder continueTimeRecord:getIndexKey];
#endif
                return;
                //                [_routesIndexLock unlock];
                //                os_unfair_lock_unlock(&_routesIndexSpinLock);
                
                
                //                    return -1;
            } else {
                if (_isThreadRunning) {
//                    _routesIndex = 0;
                    _switchedQueue = YES;
                    _threadCount += 1;
                    _routesQueue = [_routesNextQueue copy];
                    [_routesNextQueue removeAllObjects];
//                    _routesCount = (int)_routesQueue.count;
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
        
//        NSLog(@"before: %@", _routesQueue);
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
            
//            NSLog(@"thread: %i, limit: %i, offset: %i, begin: %i, end: %i", threadIndex, indexLimit, indexOffset, beginIndex, endIndex);
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
//            NSLog(@"after: %@", _routesQueue);
            pthread_mutex_unlock(&_routesIndexMutexLock);
            
            //        [_routesIndexLock lock];
            //            os_unfair_lock_lock(&_routesIndexSpinLock);
            //            os_unfair_lock_unlock(&_routesIndexSpinLock);
            //        [_routesIndexLock unlock];
        }
    }}
}

- (int)getShareIndex {
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:getIndexKey];
#endif
    //    [_routesIndexLock lock];
    //    os_unfair_lock_lock(&_routesIndexSpinLock);
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
                //                [_routesIndexLock unlock];
                //                os_unfair_lock_unlock(&_routesIndexSpinLock);
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
            //            [_routesIndexLock unlock];
            //            os_unfair_lock_unlock(&_routesIndexSpinLock);
            pthread_mutex_unlock(&_routesIndexMutexLock);
#ifdef RecordTime
            [_timeRecorder continueTimeRecord:getIndexKey];
#endif
            return -1;
        }
    }
    //    os_unfair_lock_unlock(&_routesIndexSpinLock);
    //    [_routesIndexLock unlock];
    pthread_mutex_unlock(&_routesIndexMutexLock);
    
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:getIndexKey];
#endif
    
    return _routesIndex;
}

- (void)moveTileWithFrame:(PuzzleFrame *)puzzleFrame nextStep:(int)nextStep direction:(NSString *)direction/* tempLog:(NSString *)tempLog tempIndex:(int)tempIndex */ {
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:charKey];
#endif
    //    NSNumber *totalCount;
    //    if ([_moveTileCountDict objectForKey:@"total"] == nil) {
    //        totalCount = @1;
    //    } else {
    //        int total = [[_moveTileCountDict objectForKey:@"total"] intValue];
    //        total +=1;
    //        totalCount = @(total);
    //    }
    //    _moveTileCountDict[@"total"] = totalCount;
    //
    //    NSNumber *moveTileCount;
    //    if ([_moveTileCountDict objectForKey:[NSThread currentThread].name] == nil) {
    //        moveTileCount = @1;
    //    } else {
    //        int count = [[_moveTileCountDict objectForKey:[NSThread currentThread].name] intValue];
    //        count +=1;
    //        moveTileCount = @(count);
    //    }
    //    _moveTileCountDict[[NSThread currentThread].name] = moveTileCount;
    
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
        //        [_stepResultLock lock];
        pthread_mutex_lock(&_stepResultMutexLock);
        [_stepResults addObject:steps];
        //        [_stepResultLock unlock];
#ifdef RecordTime
        NSLog(@"%@ + step:%@ = %@, %@", puzzleFrame.steps, direction, steps, [NSThread currentThread].name);
#endif
        pthread_mutex_unlock(&_stepResultMutexLock);
    }
#ifdef RecordTime
    [_timeRecorder continueTimeRecord:hashKey];
#endif
    
#ifdef RecordTime
    [_timeRecorder beginTimeRecord:frameKey];
#endif
    
    //    while(!OSAtomicCompareAndSwap32(0, 1, &_frameLockFlag));
    //    os_unfair_lock_lock(&_frameSpinLock);
    //    pthread_mutex_lock(&_frameMutexLock);
    NSInteger length = [[_frameSnapshot objectForKey:newFrame] integerValue];
    //    pthread_mutex_unlock(&_frameMutexLock);
    //    os_unfair_lock_unlock(&_frameSpinLock);
    //    OSAtomicCompareAndSwap32(1, 0, &_frameLockFlag);
    
    if (length != 0) {
        if (length < stepsLength) {
            return;
        }
    } else {
        //        while(!OSAtomicCompareAndSwap32(0, 1, &_frameLockFlag));
        //        os_unfair_lock_lock(&_frameSpinLock);
        //        pthread_mutex_lock(&_frameMutexLock);
        [_frameSnapshot setObject:@(stepsLength) forKey:newFrame];
        //        pthread_mutex_unlock(&_frameMutexLock);
        //        os_unfair_lock_unlock(&_frameSpinLock);
        //        OSAtomicCompareAndSwap32(1, 0, &_frameLockFlag);
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
    
    //    [_routesQueueLock lock];
    //    os_unfair_lock_lock(&_routesQueueSpinLock);
    pthread_mutex_lock(&_routesQueueMutexLock);
    [_routesNextQueue addObject:newPuzzleFrame];
    pthread_mutex_unlock(&_routesQueueMutexLock);
    //    os_unfair_lock_unlock(&_routesQueueSpinLock);
    //    [_routesQueueLock unlock];
    
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
