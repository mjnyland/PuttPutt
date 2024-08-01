import SwiftUI
import ARKit
import RealityKit
import Observation

struct HomeScreenView: View {
    @State private var isNewGamePresented = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("AR Golf")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Image(systemName: "figure.golf")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                
                Button(action: {
                    isNewGamePresented = true
                }) {
                    Text("New Game")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                
                NavigationLink(destination: Text("Leaderboard")) {
                    Text("Leaderboard")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                NavigationLink(destination: Text("Settings")) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $isNewGamePresented) {
            ARSetupView()
        }
    }
}
