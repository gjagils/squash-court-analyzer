import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("SQUASH ANALYZER")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2)

                // Court view
                CourtView()
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
        }
    }
}

#Preview {
    ContentView()
}
