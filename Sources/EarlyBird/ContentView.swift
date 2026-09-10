import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "alarm")
                .font(.system(size: 48))
            Text("EarlyBird")
                .font(.title.bold())
            Text("Real alarms. Real consequences.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
