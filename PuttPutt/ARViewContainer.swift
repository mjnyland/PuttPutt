import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import Vision

struct ARViewContainer: UIViewRepresentable {
    var viewModel: ARSetupViewModel
    @Binding var setupStep: Int
    @Binding var isPoseDetectionActive: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        arView.session.run(configuration)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(arView: uiView, setupStep: setupStep, isPoseDetectionActive: isPoseDetectionActive)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSessionDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: ARViewContainer
        var holeMarker: ModelEntity?
        var puttingMarker: ModelEntity?
        var cameraMarker: ModelEntity?
        var captureSession: AVCaptureSession?
        var poseRequest: VNDetectHumanBodyPoseRequest?
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
            self.poseRequest = VNDetectHumanBodyPoseRequest()
        }
        
        func update(arView: ARView, setupStep: Int, isPoseDetectionActive: Bool) {
            if isPoseDetectionActive && !(captureSession?.isRunning ?? false) {
                startUltraWideCameraAndPoseDetection(in: arView)
            } else {
                switch setupStep {
                case 1:
                    if let holePosition = parent.viewModel.holePosition {
                        placeMarker(at: holePosition, color: .red, in: arView)
                    }
                case 2:
                    if let puttingPosition = parent.viewModel.puttingPosition {
                        placeMarker(at: puttingPosition, color: .green, in: arView)
                        placeSuggestedCameraPosition(in: arView)
                    }
                default:
                    break
                }
            }
        }
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let touchLocation = recognizer.location(in: arView)
            
            if let result = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .horizontal).first {
                let worldPosition = simd_make_float3(result.worldTransform.columns.3)
                
                if !self.parent.viewModel.isHoleSet {
                    self.parent.viewModel.setHolePosition(worldPosition)
                    placeMarker(at: worldPosition, color: .red, in: arView)
                } else if !self.parent.viewModel.isPuttingPositionSet {
                    self.parent.viewModel.setPuttingPosition(worldPosition)
                    placeMarker(at: worldPosition, color: .green, in: arView)
                    placeSuggestedCameraPosition(in: arView)
                }
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
            var cameraPosition = midpoint + perpendicular * (distance * 0.866)
            
            let eyeHeight: Float = 1.68
            cameraPosition.y = eyeHeight
            
            let sphereRadius: Float = 0.1
            let sphereMesh = MeshResource.generateSphere(radius: sphereRadius)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            
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
        
        func startUltraWideCameraAndPoseDetection(in arView: ARView) {
            arView.session.pause()
            arView.scene.anchors.removeAll()
            
            captureSession = AVCaptureSession()
            guard let captureSession = captureSession,
                  let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) else {
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: ultraWideCamera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
            } catch {
                return
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            DispatchQueue.main.async {
                self.setupPreviewLayer(for: arView)
                captureSession.startRunning()
            }
        }
        
        func setupPreviewLayer(for arView: ARView) {
            guard let captureSession = captureSession else { return }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = arView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            arView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            arView.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            do {
                try imageRequestHandler.perform([poseRequest!])
                if let observations = poseRequest?.results as? [VNHumanBodyPoseObservation] {
                    DispatchQueue.main.async {
                        self.processObservations(observations)
                    }
                }
            } catch {
                print("Failed to perform Vision request: \(error)")
            }
        }
        
        func processObservations(_ observations: [VNHumanBodyPoseObservation]) {
            guard let observation = observations.first else { return }
            
            if let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
               let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
               let leftHip = try? observation.recognizedPoint(.leftHip),
               let rightHip = try? observation.recognizedPoint(.rightHip) {
                
                let bodyAngle = calculateBodyAngle(leftShoulder, rightShoulder, leftHip, rightHip)
                let stanceWidth = calculateStanceWidth(leftHip, rightHip)
                
                // Here you can use bodyAngle and stanceWidth as needed
                // For example, update your viewModel or trigger some action
            }
        }
        
        func calculateBodyAngle(_ leftShoulder: VNRecognizedPoint, _ rightShoulder: VNRecognizedPoint,
                                _ leftHip: VNRecognizedPoint, _ rightHip: VNRecognizedPoint) -> CGFloat {
            let shoulderMidpoint = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2,
                                           y: (leftShoulder.y + rightShoulder.y) / 2)
            let hipMidpoint = CGPoint(x: (leftHip.x + rightHip.x) / 2,
                                      y: (leftHip.y + rightHip.y) / 2)
            
            return atan2(shoulderMidpoint.y - hipMidpoint.y, shoulderMidpoint.x - hipMidpoint.x)
        }
        
        func calculateStanceWidth(_ leftHip: VNRecognizedPoint, _ rightHip: VNRecognizedPoint) -> CGFloat {
            return abs(leftHip.x - rightHip.x)
        }
    }
}
