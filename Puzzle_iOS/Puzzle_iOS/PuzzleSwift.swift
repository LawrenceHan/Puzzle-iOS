//
//  PuzzleSwift.swift
//  Puzzle_iOS
//
//  Created by Hanguang on 14/12/2016.
//  Copyright © 2016 Hanguang. All rights reserved.
//

import UIKit

struct Tile: OptionSet, Hashable {
    var rawValue: UInt8
    
    init(rawValue: Tile.RawValue) {
        self.rawValue = rawValue
    }
    
    typealias RawValue = UInt8
    
    static let white = Tile(rawValue: 1 << 0)
    static let red = Tile(rawValue: 1 << 1)
    static let blue = Tile(rawValue: 1 << 2)
    
    mutating func changeColor(_ color: Tile) {
        rawValue = color.rawValue
    }
}

extension Tile: Equatable {
    static func ==(lhs: Tile, rhs: Tile) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

private struct PuzzleFrame {
    let previousStep: Int8
    let currentStep: Int8
    let frame: [Tile]
    let steps: [Int8]
    let key: Int
    
    init(previousStep: Int8, currentStep: Int8, frame: [Tile], steps: [Int8]) {
        self.previousStep = previousStep;
        self.currentStep = currentStep
        self.frame = frame
        self.steps = steps
        
//        var key = ""
//        for tile in frame {
//            switch tile.rawValue {
//            case 1 << 0:
//                key += "w"
//            case 1 << 1:
//                key += "r"
//            case 1 << 2:
//                key += "b"
//            default :
//                break
//            }
//        }
        
        let bytes: [UInt8] = frame.map { $0.rawValue }
        self.key = Data(bytes: bytes).hashValue // or key.hashValue
        print(key)
    }
}

extension PuzzleFrame: CustomStringConvertible {
    public var description: String {
        return "previous step: \(previousStep), current step: \(currentStep), frame: \(frame), steps: \(steps)"
    }
}

extension PuzzleFrame: Equatable {
    static func ==(lhs: PuzzleFrame, rhs: PuzzleFrame) -> Bool {
        return lhs.previousStep == rhs.previousStep &&
            lhs.currentStep == rhs.currentStep &&
            lhs.frame == rhs.frame &&
            lhs.steps == rhs.steps
    }
}

private struct Puzzle {
    let beginFrame: [Tile]
    let endFrame: [Tile]
    
    init(_ begin: [Tile], end: [Tile]) {
        self.beginFrame = begin
        self.endFrame = end
    }
    
    let columnCount: Int = 4
    let rowCount: Int = 4
    var totalTilesCount: Int {
        return columnCount * rowCount
    }
    
    func calcuateTheShortestWay(_ completion: @escaping ([Int8]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var result: [Int8] = []
            var calcuatedFramesCount: UInt = 0
            var snapshots: [AnyHashable: Int] = [:]
            
            let puzzleFrame = PuzzleFrame(previousStep: 0, currentStep: 0, frame: self.beginFrame, steps: [])
            var currentFramesQueue: [PuzzleFrame] = [puzzleFrame]
            var nextFramesQueue: [PuzzleFrame] = []
            snapshots[puzzleFrame.key] = puzzleFrame.steps.count
            calcuatedFramesCount += 1
            
            var found = false
            
            while found == false {
                for index in 0..<currentFramesQueue.count {
                    let currentFrame: PuzzleFrame = currentFramesQueue[index]
                    let currentStep: Int8 = currentFrame.currentStep
                    let previousStep: Int8 = currentFrame.previousStep
                    
                    var nextStep: Int8 = currentStep - 4 // upward
                    if nextStep >= 0 && nextStep != previousStep {
                        self.switchTiles(currentFrame, nextStep, -4, &nextFramesQueue, frameCount: &calcuatedFramesCount, snapshots: &snapshots, result: &result)
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "U",
//                                       routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep + 4 // downward
                    if nextStep < self.totalTilesCount && nextStep != previousStep {
                        self.switchTiles(currentFrame, nextStep, 4, &nextFramesQueue, frameCount: &calcuatedFramesCount, snapshots: &snapshots, result: &result)
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "D", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep - 1 // leftward
                    if Int(currentStep) % self.columnCount - 1 >= 0 && nextStep != previousStep {
                        self.switchTiles(currentFrame, nextStep, -1, &nextFramesQueue, frameCount: &calcuatedFramesCount, snapshots: &snapshots, result: &result)
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "L", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep + 1 // rightward
                    if Int(currentStep) % self.columnCount + 1 < self.columnCount && nextStep != previousStep {
                        self.switchTiles(currentFrame, nextStep, 1, &nextFramesQueue, frameCount: &calcuatedFramesCount, snapshots: &snapshots, result: &result)
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "R", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                }
                
                if !result.isEmpty {
                    print("Result: \(result), total frame calcuated: \(calcuatedFramesCount)")
                    found = true
                    completion(result)
                }
                
                currentFramesQueue = nextFramesQueue
                nextFramesQueue.removeAll()
            }
        }
    }
    
    private func switchTiles(_ currentFrame: PuzzleFrame, _ nextStep: Int8, _ direction: Int8, _ nextFramesQueue: inout [PuzzleFrame], frameCount: inout UInt, snapshots: inout [AnyHashable: Int], result: inout [Int8]) {
        
        var frame: [Tile] = currentFrame.frame
        let temp: Tile = frame[Int(currentFrame.currentStep)]
        frame[Int(currentFrame.currentStep)].changeColor(frame[Int(nextStep)])
        frame[Int(nextStep)].changeColor(temp)
        
        let nextPuzzleFrame: PuzzleFrame = PuzzleFrame(previousStep: currentFrame.currentStep, currentStep: nextStep, frame: frame, steps: currentFrame.steps+[direction])
        
        if nextPuzzleFrame.frame == endFrame {
            result = nextPuzzleFrame.steps
        }
        
        if snapshots[nextPuzzleFrame.key] != nil {
            if snapshots[nextPuzzleFrame.key]! < nextPuzzleFrame.steps.count {
                return
            }
        } else {
            snapshots[nextPuzzleFrame.key] = nextPuzzleFrame.steps.count
        }
        
        nextFramesQueue.append(nextPuzzleFrame)
        frameCount += 1
    }
}

@objc
public final class PuzzleSwift: NSObject {
//    let puzzleBegin = "wrbbrrbbrrbbrrbb"
//    let puzzleEnd = "wbrbbrbrrbrbbrbr"
//
//    let stepBegin: Int = 0
//    let stepEnd: Int = 0
//    let columnCount: Int = 4
//    let rowCount: Int = 4
//    var totalBlockCount: Int {
//        return columnCount * rowCount
//    }
//
//    var stepResults = [String]()
//    fileprivate var routeList = [Route]()
//    var routeCount: Int = 0
//    var snapshots = [String : Int]()
    
    fileprivate let puzzle: Puzzle = Puzzle(
        [
            .white, .red, .blue, .blue,
            .red, .red, .blue, .blue,
            .red, .red, .blue, .blue,
            .red, .red, .blue, .blue
        ], end:
        [
            .white, .blue, .red, .blue,
            .blue, .red, .blue, .red,
            .red, .blue, .red, .blue,
            .blue, .red, .blue, .red
        ])

    @objc public func calcuateShortestWay() {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
//            let route = Route(previousStep: self.stepBegin, nextStep: self.stepBegin, frame: self.puzzleBegin)
//
//            self.routeList = [Route]()
//            self.stepResults = [String]()
//            self.routeCount = 0
//            self.snapshots = [String : Int]()
//
//            self.routeList.append(route)
//            self.routeCount = 1
//            self.snapshots[route.frame] = route.stepsList.characters.count
//
//            var found = false
//
//            while found == false {
//                var routesNext = [Route]()
//                var routeIndexNext = 0;
//
//                for index in 0..<self.routeCount {
//                    let routeOld = self.routeList[index]
//                    let currentStep = routeOld.nextStep
//                    let previousStep = routeOld.previousStep
//
//                    var nextStep = currentStep - 4 // upward
//                    if nextStep >= 0 && nextStep != previousStep {
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "U",
//                                  routesNext: &routesNext, routeIndexNext: &routeIndexNext)
//                    }
//
//                    nextStep = currentStep + 4 // downward
//                    if nextStep < self.totalBlockCount && nextStep != previousStep {
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "D", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
//                    }
//
//                    nextStep = currentStep - 1 // leftward
//                    if currentStep % self.columnCount - 1 >= 0 && nextStep != previousStep {
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "L", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
//                    }
//
//                    nextStep = currentStep + 1 // rightward
//                    if currentStep % self.columnCount + 1 < self.columnCount && nextStep != previousStep {
//                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "R", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
//                    }
//                }
//
//                if self.stepResults.count > 0 {
//                    for steps in self.stepResults {
//                        print("Result: \(steps), total steps count: \(steps.characters.count)")
//                    }
//                    found = true
//                    DispatchQueue.main.async {
//                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.hanguang.app.puzzle.PuzzleFinishedNotification"),
//                                                        object: nil, userInfo: ["resutls":self.stepResults])
//                    }
//                }
//
//                self.routeList = routesNext
//                self.routeCount = routeIndexNext
//            }
            self.puzzle.calcuateTheShortestWay({ (result) in
                DispatchQueue.main.async {
                    let stringResult: String = result.reduce("", { (result, value) -> String in
                        switch value {
                        case -4:
                            return result + "U"
                        case 4:
                            return result + "D"
                        case -1:
                            return result + "L"
                        case 1:
                            return result + "R"
                        default:
                            return ""
                        }
                    })
                    
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.hanguang.app.puzzle.PuzzleFinishedNotification"),
                                                    object: nil, userInfo: ["resutls": [stringResult as NSString]])
                }
            })
        }
    }

//    private func moveBlock(routeOld: Route, nextStep: Int, direction: String, routesNext: inout [Route], routeIndexNext: inout Int) {
//        let routeNew = Route(previousStep: routeOld.nextStep, nextStep: nextStep, frame: "")
//        routeNew.stepsList = routeOld.stepsList.appending(direction)
//        var frame = routeOld.frame
//        let previousIndex = frame.index(frame.startIndex, offsetBy: routeNew.previousStep)
//        let nextIndex = frame.index(frame.startIndex, offsetBy: routeNew.nextStep)
//        let previousBlock = frame[previousIndex]
//        let nextBlock = frame[nextIndex]
//        frame = frame.replacingCharacters(in: previousIndex..<frame.index(after: previousIndex), with: String(nextBlock))
//        frame = frame.replacingCharacters(in: nextIndex..<frame.index(after: nextIndex), with: String(previousBlock))
//        routeNew.frame = frame
//
//        if routeNew.frame.hashValue == puzzleEnd.hashValue {
//            stepResults.append(routeNew.stepsList)
//        }
//
//        if snapshots[routeNew.frame] != nil {
//            if snapshots[routeNew.frame]! < routeNew.stepsList.characters.count {
//                return
//            }
//        } else {
//            snapshots[routeNew.frame] = routeNew.stepsList.characters.count
//        }
//        routesNext.append(routeNew)
//        routeIndexNext += 1
//    }
}

private class Route: CustomStringConvertible {
    
    var previousStep: Int = 0
    var nextStep: Int = 0
    var frame: String
    var stepsList: String
    
    init(previousStep: Int, nextStep: Int, frame: String) {
        self.previousStep = previousStep;
        self.nextStep = nextStep
        self.frame = frame
        self.stepsList = ""
    }
    
    open var description: String {
        return "previous step: \(previousStep), current step: \(nextStep), frame: \(frame), steps: \(stepsList)"
    }
}
