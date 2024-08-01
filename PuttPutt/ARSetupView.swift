import SwiftUI
import RealityKit
import ARKit

struct ARSetupView: View {
    @State private var viewModel = ARSetupViewModel()
    @State private var setupStep = 0
    @State private var debugMessage = "Tap to begin setup"
    @State private var isPoseDetectionActive = false

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel, debugMessage: $debugMessage, setupStep: $setupStep, isPoseDetectionActive: $isPoseDetectionActive)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text(debugMessage)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)

                Spacer()

                if !isPoseDetectionActive {
                    switch setupStep {
                    case 0:
                        instructionView(text: "Tap to select hole position")
                    case 1:
                        instructionView(text: "Tap to select putting area")
                    case 2:
                        instructionView(text: "Move to suggested camera position")
                    default:
                        EmptyView()
                    }

                    if setupStep == 2 {
                        Button("Start Pose Detection") {
                            startPoseDetection()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onChange(of: viewModel.isHoleSet) { _, isSet in
            if isSet {
                setupStep = 1
                debugMessage = "Hole position set"
            }
        }
        .onChange(of: viewModel.isPuttingPositionSet) { _, isSet in
            if isSet {
                setupStep = 2
                viewModel.isCameraGuideVisible = true
                debugMessage = "Putting position set. Move to suggested camera position."
            }
        }
    }

    private func instructionView(text: String) -> some View {
        Text(text)
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.bottom, 20)
    }

    private func startPoseDetection() {
        isPoseDetectionActive = true
        setupStep = 3
        debugMessage = "Pose detection starting..."
    }
}
