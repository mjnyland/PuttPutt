import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    var viewModel: ARSetupViewModel
    @Binding var debugMessage: String
    @Binding var setupStep: Int
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure ARKit session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        // Run the session
        arView.session.run(configuration)
        
        // Add a tap gesture recognizer to the AR view
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if let holePosition = viewModel.holePosition {
            context.coordinator.placeMarker(at: holePosition, color: .red, in: uiView)
        }
        if let puttingPosition = viewModel.puttingPosition {
            context.coordinator.placeMarker(at: puttingPosition, color: .green, in: uiView)
        }
        if setupStep == 2 {
            context.coordinator.placeSuggestedCameraPosition(in: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARViewContainer
        var holeMarker: ModelEntity?
        var puttingMarker: ModelEntity?
        var cameraMarker: ModelEntity?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
        }
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let touchLocation = recognizer.location(in: arView)
            
            if let result = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .horizontal).first {
                let worldPosition = simd_make_float3(result.worldTransform.columns.3)
                
                if !self.parent.viewModel.isHoleSet {
                    self.parent.viewModel.setHolePosition(worldPosition)
                    self.parent.debugMessage = "Hole position set"
                    placeMarker(at: worldPosition, color: .red, in: arView)
                } else if !self.parent.viewModel.isPuttingPositionSet {
                    self.parent.viewModel.setPuttingPosition(worldPosition)
                    self.parent.debugMessage = "Putting position set"
                    placeMarker(at: worldPosition, color: .green, in: arView)
                    placeSuggestedCameraPosition(in: arView)
                }
            } else {
                self.parent.debugMessage = "Couldn't find a surface. Try again."
            }
        }
        
        func placeMarker(at position: SIMD3<Float>, color: UIColor, in arView: ARView) {
            let markerEntity = ModelEntity(mesh: .generateSphere(radius: 0.05),
                                           materials: [SimpleMaterial(color: color, isMetallic: true)])
            markerEntity.position = position
            
            let anchorEntity = AnchorEntity(world: position)
            anchorEntity.addChild(markerEntity)
            
            arView.scene.addAnchor(anchorEntity)
            
            if color == .red {
                if let oldMarker = holeMarker {
                    oldMarker.removeFromParent()
                }
                holeMarker = markerEntity
            } else if color == .green {
                if let oldMarker = puttingMarker {
                    oldMarker.removeFromParent()
                }
                puttingMarker = markerEntity
            }
        }
        
        func placeSuggestedCameraPosition(in arView: ARView) {
            guard let holePosition = parent.viewModel.holePosition,
                  let puttingPosition = parent.viewModel.puttingPosition else {
                return
            }
            
            let midpoint = (holePosition + puttingPosition) / 2
            let direction = normalize(puttingPosition - holePosition)
            let perpendicular = simd_float3(-direction.z, 0, direction.x)
            
            let distance = simd_distance(holePosition, puttingPosition)
            var cameraPosition = midpoint + perpendicular * (distance * 0.866) // sqrt(3)/2 for equilateral triangle
            
            // Set the camera height to 5.5 feet (about 1.68 meters)
            let eyeHeight: Float = 1.68
            cameraPosition.y = eyeHeight
            
            // Create a floating sphere to represent the camera position
            let sphereRadius: Float = 0.1
            let sphereMesh = MeshResource.generateSphere(radius: sphereRadius)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            
            // Position the sphere at eye level
            sphereEntity.position = cameraPosition
            
            let anchorEntity = AnchorEntity(world: cameraPosition)
            anchorEntity.addChild(sphereEntity)
            
            arView.scene.addAnchor(anchorEntity)
            
            if let oldMarker = cameraMarker {
                oldMarker.removeFromParent()
            }
            cameraMarker = sphereEntity
            
            parent.viewModel.currentCameraPosition = simd_make_float4(cameraPosition, 1)
        }
    }
}
