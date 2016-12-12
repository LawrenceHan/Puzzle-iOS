//
//  ViewController.m
//  Puzzle_iOS
//
//  Created by Hanguang on 12/12/2016.
//  Copyright © 2016 Hanguang. All rights reserved.
//

#import "ViewController.h"
#import "Puzzle.h"

@interface ViewController ()
@property (nonatomic, strong) Puzzle *puzzle;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _puzzle = [[Puzzle alloc] initWithBeginFrame:@"wrbbrrbbrrbbrrbb" endFrame:@"wbrbbrbrrbrbbrbr" columns:4 row:4];
    
    CGRect rect = CGRectMake((self.view.bounds.size.width - 200)/2, (self.view.bounds.size.height - 200)/2, 200, 200);
    [self drawFrame:_puzzle.beginFrame withSquareRect:rect];
}

- (void)drawFrame:(NSString *)frame withSquareRect:(CGRect)rect {
    BOOL Not_A_Square = rect.size.width == rect.size.height;
    NSAssert(Not_A_Square, @"Must be draw on a square shape");
    
    CALayer *bgLayer = [CALayer layer];
    bgLayer.frame = rect;
    bgLayer.backgroundColor = [UIColor lightGrayColor].CGColor;
    bgLayer.borderWidth = 2;
    bgLayer.borderColor = [UIColor lightGrayColor].CGColor;
    
    int space = 4;
    int tileWidth = (rect.size.width - (_puzzle.columns + 1) * space) / _puzzle.columns;
    int tileHeight = tileWidth;
    
    for (int y = 0; y < _puzzle.rows; y++) {
        for (int x = 0; x < _puzzle.columns; x++) {
            int originX = x * (space + tileWidth) + space;
            int originY = y * (space + tileHeight) + space;
            int offset = y * _puzzle.rows;
            int beginIndex = offset + x;
            
            CGColorRef color;
            if (frame.UTF8String[beginIndex] == 'w') {
                color = [UIColor whiteColor].CGColor;
            } else if (frame.UTF8String[beginIndex] == 'r') {
                color = [UIColor redColor].CGColor;
            } else {
                color = [UIColor blueColor].CGColor;
            }
            
            CALayer *tile = [CALayer layer];
            tile.frame = CGRectMake(originX, originY, tileWidth, tileHeight);
            tile.backgroundColor = color;
            
            [bgLayer addSublayer:tile];
        }
    }
    
    [self.view.layer addSublayer:bgLayer];
}

- (void)startCalculate {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    [_puzzle calculateSteps];
    CFAbsoluteTime executionTime = (CFAbsoluteTimeGetCurrent() - startTime);
    NSLog(@"Dispatch took %f s", executionTime);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
