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
@property (nonatomic, assign) CFAbsoluteTime startCalcTime;
@property (nonatomic, assign) BOOL foundResults;
@property (nonatomic, strong) UIButton *calcButton;
@property (nonatomic, strong) NSMutableArray<CALayer *> *tiles;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getResults:) name:PuzzleFinishedNotification object:nil];
    
    _foundResults = NO;
    _puzzle = [[Puzzle alloc] initWithBeginFrame:@"wrbbrrbbrrbbrrbb" endFrame:@"wbrbbrbrrbrbbrbr" columns:4 row:4];
    
    // Draw begin frame
    CGRect rect = CGRectMake((self.view.bounds.size.width - 150)/2, 20, 150, 150);
    [self drawFrame:_puzzle.beginFrame withSquareRect:rect mainFrame:YES];

    _calcButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_calcButton addTarget:self action:@selector(startCalculate:) forControlEvents:UIControlEventTouchUpInside];
    _calcButton.frame = CGRectMake((self.view.bounds.size.width - 150)/2, 20+150+8, 150, 30);
    [_calcButton setTitle:@"START" forState:UIControlStateNormal];
    [_calcButton setTitle:@"Calculating" forState:UIControlStateDisabled];
    [_calcButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _calcButton.backgroundColor = [UIColor colorWithRed:0.46 green:0.7 blue:0.32 alpha:1.0];
    _calcButton.layer.masksToBounds = YES;
    _calcButton.layer.cornerRadius = 4;
    [self.view addSubview:_calcButton];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawFrame:(NSString *)frame withSquareRect:(CGRect)rect {
    [self drawFrame:frame withSquareRect:rect mainFrame:NO];
}

- (void)drawFrame:(NSString *)frame withSquareRect:(CGRect)rect mainFrame:(BOOL)main {
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
                tile.borderWidth = rect.size.width / 150.f;
            } else if (frame.UTF8String[beginIndex] == 'r') {
                color = [UIColor colorWithRed:205.f/255.f green:38.f/255.f blue:38.f/255.f alpha:1].CGColor;
            } else {
                color = [UIColor blueColor].CGColor;
                color = [UIColor colorWithRed:32.f/255.f green:64.f/255.f blue:207.f/255.f alpha:1].CGColor;
            }
            
            tile.frame = CGRectMake(originX, originY, tileWidth, tileHeight);
            tile.backgroundColor = color;
            
            [bgLayer addSublayer:tile];
            
            if (main) {
                [_tiles addObject:tile];
            }
        }
    }
    
    [self.view.layer addSublayer:bgLayer];
}

- (void)startCalculate:(UIButton *)sender {
    if (_foundResults == NO) {
        sender.enabled = NO;
        sender.backgroundColor = [UIColor lightGrayColor];
        _startCalcTime = CFAbsoluteTimeGetCurrent();
        [_puzzle calculateSteps];
    } else {
        // Show animation
        sender.enabled = NO;
        [sender setTitle:@"Animating" forState:UIControlStateNormal];
        
    }
}

- (void)getResults:(NSNotification *)noti {
    CFAbsoluteTime executionTime = (CFAbsoluteTimeGetCurrent() - _startCalcTime);
    NSLog(@"Calculating took %f s", executionTime);
    
    NSArray *results = noti.userInfo[@"resutls"];
    if (results.count > 0) {
        NSString *steps = results.firstObject;
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
            int originY = rows * (heightSpace + tilesHeight) + heightSpace + (20+150+8+30);
            [self drawFrame:beginFrame withSquareRect:CGRectMake(originX, originY, tilesWidth, tilesHeight)];
        }
    }
    
    _foundResults = YES;
    [_calcButton setTitle:@"Show animation" forState:UIControlStateNormal];
    _calcButton.backgroundColor = [UIColor colorWithRed:0.46 green:0.7 blue:0.32 alpha:1.0];
    _calcButton.enabled = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
