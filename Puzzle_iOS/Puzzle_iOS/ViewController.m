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
    
    // Draw begin frame
    CGRect rect = CGRectMake((self.view.bounds.size.width - 150)/2, 20, 150, 150);
    [self drawFrame:_puzzle.beginFrame withSquareRect:rect];

    UIButton *calcButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [calcButton addTarget:self action:@selector(startCalculate:) forControlEvents:UIControlEventTouchUpInside];
    calcButton.frame = CGRectMake((self.view.bounds.size.width - 150)/2, 20+150+8, 150, 30);
    [calcButton setTitle:@"START" forState:UIControlStateNormal];
    [calcButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    calcButton.backgroundColor = [UIColor colorWithRed:0.46 green:0.7 blue:0.32 alpha:1.0];
    calcButton.layer.masksToBounds = YES;
    calcButton.layer.cornerRadius = 4;
    [self.view addSubview:calcButton];
}

- (void)drawFrame:(NSString *)frame withSquareRect:(CGRect)rect {
    BOOL Not_A_Square = rect.size.width == rect.size.height;
    NSAssert(Not_A_Square, @"Must be draw on a square shape");
    
    int space = 1;
    CALayer *bgLayer = [CALayer layer];
    bgLayer.frame = rect;
    
    int tileWidth = (rect.size.width - (_puzzle.columns + 1) * space) / _puzzle.columns;
    int tileHeight = tileWidth;
    
    for (int y = 0; y < _puzzle.rows; y++) {
        for (int x = 0; x < _puzzle.columns; x++) {
            int originX = x * (space + tileWidth) + space;
            int originY = y * (space + tileHeight) + space;
            int offset = y * _puzzle.rows;
            int beginIndex = offset + x;
            
            CALayer *tile = [CALayer layer];
            CGColorRef color;
            
            if (frame.UTF8String[beginIndex] == 'w') {
                color = [UIColor whiteColor].CGColor;
                tile.borderColor = [UIColor blackColor].CGColor;
                tile.borderWidth = 1;
            } else if (frame.UTF8String[beginIndex] == 'r') {
                color = [UIColor colorWithRed:205.f/255.f green:38.f/255.f blue:38.f/255.f alpha:1].CGColor;
            } else {
                color = [UIColor blueColor].CGColor;
                color = [UIColor colorWithRed:70.f/255.f green:130.f/255.f blue:180.f/255.f alpha:1].CGColor;
            }
            
            tile.frame = CGRectMake(originX, originY, tileWidth, tileHeight);
            tile.backgroundColor = color;
            
            [bgLayer addSublayer:tile];
        }
    }
    
    [self.view.layer addSublayer:bgLayer];
}

- (void)startCalculate:(UIButton *)sender {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    NSArray *resuts = [_puzzle calculateSteps];
    CFAbsoluteTime executionTime = (CFAbsoluteTimeGetCurrent() - startTime);
    NSLog(@"Dispatch took %f s", executionTime);
    
    if (resuts.count > 0) {
        NSString *steps = resuts.firstObject;
        NSString *beginFrame = _puzzle.beginFrame;
        int lastStep = 0;
        int itemsInRow = 6;
        int widthSpace = 8;
        int heightSpace = 6;
        int tilesWidth = (self.view.bounds.size.width - (itemsInRow + 1) * widthSpace) / itemsInRow;
        int tilesHeight = tilesWidth;
        int rows = -1;
        
        for (int idx = 0; idx < (int)steps.length; idx++) {
            char *chars = malloc(_puzzle.beginFrame.length+1);
            memcpy(chars, beginFrame.UTF8String, _puzzle.beginFrame.length+1);
            
            int nextStep = 0;
            if (steps.UTF8String[idx] == 'U') {
                nextStep = lastStep - 4;
            } else if (steps.UTF8String[idx] == 'D') {
                nextStep = lastStep + 4;
            } else if (steps.UTF8String[idx] == 'L') {
                nextStep = lastStep - 1;
            } else {
                nextStep = lastStep + 1;
            }
            
            char temp = chars[lastStep];
            chars[lastStep] = chars[nextStep];
            chars[nextStep] = temp;
            lastStep = nextStep;
            beginFrame = [NSString stringWithFormat:@"%s", chars];
            
            int column = idx % itemsInRow;
            if (column == 0) rows += 1;
            
            int originX = column * (widthSpace + tilesWidth) + widthSpace;
            int originY = rows * (heightSpace + tilesHeight) + heightSpace + 20+150+8+30;
            [self drawFrame:beginFrame withSquareRect:CGRectMake(originX, originY, tilesWidth, tilesHeight)];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
