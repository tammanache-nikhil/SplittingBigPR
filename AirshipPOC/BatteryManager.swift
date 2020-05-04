//
//  BatteryMonitor.swift
//  SWAPilot

import Foundation

final class BatteryMonitor {

    static func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    static func stopMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}
