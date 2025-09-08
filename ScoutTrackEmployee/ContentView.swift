import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("👋 Hello SwiftUI!")
                .font(.largeTitle)
                .foregroundColor(.blue)
            Text("Welcome to your first native iOS app.")
                .foregroundColor(.gray)
        }
        .padding()
    }
}
