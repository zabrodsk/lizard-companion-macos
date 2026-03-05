import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tom Lizard Companion")
                .font(.title2)
                .bold()
            Text("This app runs from the menu bar.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    ContentView()
}
