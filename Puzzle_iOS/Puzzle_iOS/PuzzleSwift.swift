//
//  PuzzleSwift.swift
//  Puzzle_iOS
//
//  Created by Hanguang on 14/12/2016.
//  Copyright © 2016 Hanguang. All rights reserved.
//

import Foundation

@objc
public final class PuzzleSwift: NSObject {
    let puzzleBegin = "wrbbrrbbrrbbrrbb"
    let puzzleEnd = "wbrbbrbrrbrbbrbr"
    
    let stepBegin: Int = 0
    let stepEnd: Int = 0
    let columnCount: Int = 4
    let rowCount: Int = 4
    var totalBlockCount: Int {
        return columnCount * rowCount
    }
    
    var stepResults = [String]()
    fileprivate var routeList = [Route]()
    var routeCount: Int = 0
    var snapshots = [String : Int]()
    
    public func drawTable() {
        if stepResults.count > 0 {
            var results = ""
            for steps in stepResults {
                results = results.appending("Total routes count: \(routeCount), result: \(steps), total steps count: \(steps.characters.count)\n")
            }
        } else {
            print("No results")
        }
    }
    
    @objc public func calcuateShortestWay() {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            let route = Route(previousStep: self.stepBegin, nextStep: self.stepBegin, frame: self.puzzleBegin)
            
            self.routeList = [Route]()
            self.stepResults = [String]()
            self.routeCount = 0
            self.snapshots = [String : Int]()
            
            self.routeList.append(route)
            self.routeCount = 1
            self.snapshots[route.frame] = route.stepsList.characters.count
            
            var found = false
            
            while found == false {
                var routesNext = [Route]()
                var routeIndexNext = 0;
                
                for index in 0..<self.routeCount {
                    let routeOld = self.routeList[index]
                    let currentStep = routeOld.nextStep
                    let previousStep = routeOld.previousStep
                    
                    var nextStep = currentStep - 4 // upward
                    if nextStep >= 0 && nextStep != previousStep {
                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "U",
                                  routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep + 4 // downward
                    if nextStep < self.totalBlockCount && nextStep != previousStep {
                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "D", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep - 1 // leftward
                    if currentStep % self.columnCount - 1 >= 0 && nextStep != previousStep {
                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "L", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                    
                    nextStep = currentStep + 1 // rightward
                    if currentStep % self.columnCount + 1 < self.columnCount && nextStep != previousStep {
                        self.moveBlock(routeOld: routeOld, nextStep: nextStep, direction: "R", routesNext: &routesNext, routeIndexNext: &routeIndexNext)
                    }
                }
                
                if self.stepResults.count > 0 {
                    for steps in self.stepResults {
                        print("Result: \(steps), total steps count: \(steps.characters.count)")
                    }
                    found = true
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "com.hanguang.app.puzzle.PuzzleFinishedNotification"),
                                                        object: nil, userInfo: ["resutls":self.stepResults])
                    }
                }
                
                self.routeList = routesNext
                self.routeCount = routeIndexNext
            }
        }
    }
    
    private func moveBlock(routeOld: Route, nextStep: Int, direction: String, routesNext: inout [Route], routeIndexNext: inout Int) {
        let routeNew = Route(previousStep: routeOld.nextStep, nextStep: nextStep, frame: "")
        routeNew.stepsList = routeOld.stepsList.appending(direction)
        var frame = routeOld.frame
        let previousIndex = frame.index(frame.startIndex, offsetBy: routeNew.previousStep)
        let nextIndex = frame.index(frame.startIndex, offsetBy: routeNew.nextStep)
        let previousBlock = frame[previousIndex]
        let nextBlock = frame[nextIndex]
        frame = frame.replacingCharacters(in: previousIndex..<frame.index(after: previousIndex), with: String(nextBlock))
        frame = frame.replacingCharacters(in: nextIndex..<frame.index(after: nextIndex), with: String(previousBlock))
        routeNew.frame = frame
        
        if routeNew.frame.hashValue == puzzleEnd.hashValue {
            stepResults.append(routeNew.stepsList)
        }
        
        if snapshots[routeNew.frame] != nil {
            if snapshots[routeNew.frame]! < routeNew.stepsList.characters.count {
                return
            }
        } else {
            snapshots[routeNew.frame] = routeNew.stepsList.characters.count
        }
        routesNext.append(routeNew)
        routeIndexNext += 1
    }
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
