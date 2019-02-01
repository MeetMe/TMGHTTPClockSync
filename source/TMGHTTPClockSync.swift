//
//  TMGHTTPClockSync.swift
//  TMGHTTPClockSync
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

import Foundation

/// Sync device time with a server's time
public class TMGClockSyncController: NSObject {
    /// Configuration object
    public struct Config {
        /// The maximum number datapoints to ensure accuracy
        public var maxDataPoints: Int
        /// The number of milliseconds to wait between data points
        public var millisecondsBetweenDataPoints: Int
        /// The maximum number of errors before clock sync stops trying to get MaxDataPoints
        public var maxErrors: Int
        /// The notification center name when a TMGClockSyncController updates its serverTime. object is self
        public var clockSyncDidUpdateNotificationName: NSNotification.Name
        /// Called to get the server time. Send a nil TimeInterval if an error occurs
        public var getServerTime: ((_ completion: @escaping (TimeInterval?) -> Void) -> Void)?
        /// Init
        ///
        /// - Parameters:
        ///   - maxDataPoints: The maximum number datapoints to ensure accuracy
        ///   - millisecondsBetweenDataPoints: The number of seconds to wait between data points
        ///   - maxErrors: The maximum number of errors before clock sync stops trying to get MaxDataPoints
        ///   - clockSyncDidUpdateNotificationName: The notification center name when a TMGClockSyncController updates its serverTime. object is self
        ///   - getServerTime: Called to get the server time. Send a nil TimeInterval if an error occurs
        public init(maxDataPoints: Int = 5,
                    millisecondsBetweenDataPoints: Int = 1000,
                    maxErrors: Int = 2,
                    clockSyncDidUpdateNotificationName: NSNotification.Name = NSNotification.Name("TMGClockSyncController.DidUpdate"),
                    getServerTime: ((_ completion: @escaping (TimeInterval?) -> Void) -> Void)? = nil) {
            self.maxDataPoints = maxDataPoints
            self.millisecondsBetweenDataPoints = millisecondsBetweenDataPoints
            self.maxErrors = maxErrors
            self.clockSyncDidUpdateNotificationName = clockSyncDidUpdateNotificationName
            self.getServerTime = getServerTime
        }
    }

    /// Information about a clock sync data point
    public struct TMGClockSyncDataPoint {
        /// The difference between serverTime and deviceTime
        public let delta: TimeInterval
        /// The round trip latency of the call for this datapoint
        public let roundTripLatency: TimeInterval
    }

    /// The data points we have so far
    fileprivate var dataPoints: [TMGClockSyncDataPoint] = []

    /// The difference between serverTime and deviceTime
    fileprivate var deviceServerDelta: TimeInterval?

    /// Are we currently finding the delta?
    fileprivate var isFindingDelta: Bool = false

    /// The current configuration object
    public var config: Config = Config()

    /// The server's current time calulated by using the device/server delta
    public var serverTime: Date {
        return Date().addingTimeInterval(deviceServerDelta ?? 0)
    }

    /// Init with a configuration object
    ///
    /// - Parameter config: The configuration object
    public convenience init(config: Config) {
        self.init()
        self.config = config
    }

    /// Find the delta between the deviceTime and the serverTime
    public func syncClocks() {
        // Guard accidentally calling this too much
        guard !isFindingDelta else { return }
        findDelta(errorsLeft: config.maxErrors)
    }

    /// Clear the data points
    ///
    /// - Parameter resetDelta: Set to true to nil out the device/server delta
    public func clearDataPoints(resetDelta: Bool = false) {
        dataPoints.removeAll()
        if resetDelta {
            deviceServerDelta = nil
        }
    }

    /// Find the delta by calling the api in config.getServerTime
    ///
    /// - Parameter errorsLeft: The number of errors left for retry
    fileprivate func findDelta(errorsLeft: Int) {
        // guard against bad config
        guard config.maxDataPoints > 0 else { return }

        // Make sure we have errors left & we still need more data
        guard errorsLeft > 0, dataPoints.count < config.maxDataPoints else {
            isFindingDelta = false
            computeAverageDelta()
            return
        }

        // Make sure we have an API to call
        guard let getServerTime = config.getServerTime else { return }

        // Store that we're currently working on finding the delta
        isFindingDelta = true

        // Save the start time
        let startTime = Date().timeIntervalSince1970

        // Get server time from the API
        getServerTime { [weak self] (serverTime) in
            guard let sSelf = self  else { return }
            guard let serverTime = serverTime else {
                // There was an error. Wait for a bit then take another sample
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(sSelf.config.millisecondsBetweenDataPoints), execute: { [weak self] in
                    guard let sSelf = self else { return }
                    sSelf.findDelta(errorsLeft: errorsLeft - 1)
                })
                return
            }
            // Get our current device time
            let deviceTime = Date().timeIntervalSince1970
            // Compute round trip time for the API call
            let roundTripLatency = deviceTime - startTime
            // Get the estimated latency from server to device by dividing the round trip time by 2
            let estimatedReturnLatency = roundTripLatency / 2
            // The server time needs to be shifted by the estimated return latency
            let shiftedServerTime = serverTime + estimatedReturnLatency
            // Compute the delta between the shiftedServerTime and our device time to get a delta between the 2
            let delta = shiftedServerTime - deviceTime

            // Add the new delta to the existing array
            sSelf.dataPoints.append(TMGClockSyncDataPoint(delta: delta, roundTripLatency: roundTripLatency))

            if sSelf.dataPoints.count >= sSelf.config.maxDataPoints {
                // We have enough for accuracy
                sSelf.isFindingDelta = false
                sSelf.computeAverageDelta()
            } else {
                // If we don't have a delta yet, just use what we have for now.
                if sSelf.deviceServerDelta == nil {
                    sSelf.computeAverageDelta()
                }
                // We need more data for accuracy. Wait for a bit then take another sample
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(sSelf.config.millisecondsBetweenDataPoints), execute: { [weak self] in
                    guard let sSelf = self else { return }
                    sSelf.findDelta(errorsLeft: errorsLeft)
                })
            }
        }
    }

    /// Compute the average delta between server and device time
    fileprivate func computeAverageDelta() {
        // Guard against empty data
        guard !dataPoints.isEmpty else { return }
        // Get count
        let count = dataPoints.count
        if count == 1 {
            // We only have 1 so just set it to what we have
            deviceServerDelta = dataPoints.first?.delta
        } else {
            // We have more that 1. Get an accurate delta

            // Sort the data points & grab latencies for processing
            let sortedDataPoints = dataPoints.sorted(by: { $0.roundTripLatency < $1.roundTripLatency })
            let sortedLatencies = sortedDataPoints.map({ $0.roundTripLatency })

            // Get the median latency
            var medianLatency: Double
            if count % 2 == 0 {
                medianLatency = (sortedLatencies[(count / 2)] + sortedLatencies[(count / 2) - 1]) / 2
            } else {
                medianLatency = sortedLatencies[(count - 1) / 2]
            }

            // Get the mean latency
            let meanLatency = sortedLatencies.reduce(0, +) / Double(count)

            // Compute the sample standard deviation latency
            let squaredSum = sortedLatencies.map({ pow($0 - meanLatency, 2) }).reduce(0, +)
            let sampleVariance = squaredSum / Double(count - 1)
            let sampleStandardDeviation = sampleVariance.squareRoot()

            // Get the accurate deltas where latency is less than or equal to 1 standard deviation from the median
            let accurateDeltas = sortedDataPoints.filter({ $0.roundTripLatency <= (medianLatency + sampleStandardDeviation) }).map({ $0.delta })

            if accurateDeltas.isEmpty {
                // This code should never be hit, but we want to avoid divide by zero so just use the first datapoint.
                deviceServerDelta = sortedDataPoints.first?.delta
            } else {
                // Set the deviceServerDelta to the mean of the accurate deltas
                deviceServerDelta = accurateDeltas.reduce(0, +) / Double(accurateDeltas.count)
            }
        }
        NotificationCenter.default.post(name: config.clockSyncDidUpdateNotificationName, object: self)
    }
}
