import SwiftUI
import RealityKit
import Observation
import ARKit

@Observable class ARSetupViewModel {
    var holePosition: SIMD3<Float>?
    var puttingPosition: SIMD3<Float>?
    var currentCameraPosition: SIMD4<Float>?
    var needsReset = false
    var distanceInFeet: Float = 0
    var isCameraGuideVisible = false
    var isSetupLocked = false
    
    var isHoleSet: Bool { holePosition != nil }
    var isPuttingPositionSet: Bool { puttingPosition != nil }
    
    func setHolePosition(_ position: SIMD3<Float>) {
        holePosition = position
        updateDistance()
    }
    
    func setPuttingPosition(_ position: SIMD3<Float>) {
        puttingPosition = position
        updateDistance()
    }
    
    func updateDistance() {
        guard let holePosition = holePosition, let puttingPosition = puttingPosition else {
            distanceInFeet = 0
            return
        }
        
        let distance = simd_distance(holePosition, puttingPosition)
        distanceInFeet = distance * 3.28084 // Convert meters to feet
    }
    
    func lockSetup() {
        isSetupLocked = true
        isCameraGuideVisible = false
    }
    
    func reset() {
        holePosition = nil
        puttingPosition = nil
        currentCameraPosition = nil
        distanceInFeet = 0
        isCameraGuideVisible = false
        isSetupLocked = false
        needsReset = false
    }
}
