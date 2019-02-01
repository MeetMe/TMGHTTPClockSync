//
//  TMGHTTPClockSyncTests.swift
//  TMGHTTPClockSyncTests
//
//  Copyright 2018 - 2019 The Meet Group Inc. (https://www.themeetgroup.com)
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//   1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//   2. Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//   3. Neither the name of the copyright holder nor the names of its contributors
//  may be used to endorse or promote products derived from this software without
//  specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import XCTest
@testable import TMGHTTPClockSync

class TMGHTTPClockSyncTests: XCTestCase {

    func waitForNotificationNamed(_ notificationName: NSNotification.Name) -> Bool {
        let expectation = XCTNSNotificationExpectation(name: notificationName)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        return result == .completed
    }

    /// Try out a clock sync test
    ///
    /// - Parameters:
    ///   - maxSendTimeMs: max time in milliseconds to simulate send latency
    ///   - maxRecieveTimeMs: max time in milliseconds to simulate recieve latency
    ///   - serverTimeDelta: the delta between deviceTime and server time
    ///   - maxDataPoints: the max number of data points for accuracy
    func tryClockSync(maxSendTimeMs: UInt32, maxRecieveTimeMs: UInt32, serverTimeDelta: TimeInterval, maxDataPoints: Int) {
        let sendTimeMs = Int(arc4random_uniform(maxSendTimeMs))
        let recieveTimeMs = Int(arc4random_uniform(maxRecieveTimeMs))
        var serverTime: TimeInterval = 0

        let config = TMGClockSyncController.Config(maxDataPoints: maxDataPoints, millisecondsBetweenDataPoints: 0) { (completion) in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(sendTimeMs)) {
                serverTime = Date().timeIntervalSince1970 + serverTimeDelta
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(recieveTimeMs)) {
                    completion(serverTime)
                }
            }
        }
        let controller = TMGClockSyncController(config: config)
        controller.syncClocks()
        if maxDataPoints > 1 {
            XCTAssertTrue(waitForNotificationNamed(config.clockSyncDidUpdateNotificationName))
        }
        XCTAssertTrue(waitForNotificationNamed(config.clockSyncDidUpdateNotificationName))
        // 100 milliseconds of drift is considered human imperceptible
        let allowedDrift: Double = Double(maxSendTimeMs + maxRecieveTimeMs + 100) / 1000
        XCTAssertTrue(controller.serverTime.timeIntervalSince1970 < (serverTime + allowedDrift) && controller.serverTime.timeIntervalSince1970 > (serverTime - allowedDrift))
    }

    func testGoodConnectionSimilarClockSync() {
        tryClockSync(maxSendTimeMs: 50, maxRecieveTimeMs: 75, serverTimeDelta: 5, maxDataPoints: 5)
    }

    func testGoodConnectionVeryDifferentClockSync() {
        tryClockSync(maxSendTimeMs: 50, maxRecieveTimeMs: 75, serverTimeDelta: 1000, maxDataPoints: 5)
    }

    func testGoodConnectionVeryDifferentNegativeClockSync() {
        tryClockSync(maxSendTimeMs: 50, maxRecieveTimeMs: 75, serverTimeDelta: -2000, maxDataPoints: 5)
    }

    func testBadConnectionSimilarClockSync() {
        tryClockSync(maxSendTimeMs: 500, maxRecieveTimeMs: 750, serverTimeDelta: 5, maxDataPoints: 5)
    }

    func testBadConnectionVeryDifferentClockSync() {
        tryClockSync(maxSendTimeMs: 500, maxRecieveTimeMs: 750, serverTimeDelta: 1000, maxDataPoints: 5)
    }

    func testBadConnectionVeryDifferentNegativeClockSync() {
        tryClockSync(maxSendTimeMs: 500, maxRecieveTimeMs: 750, serverTimeDelta: -2000, maxDataPoints: 5)
    }

    func test1DataPointClockSync() {
        tryClockSync(maxSendTimeMs: 100, maxRecieveTimeMs: 100, serverTimeDelta: 3, maxDataPoints: 1)
    }
}
