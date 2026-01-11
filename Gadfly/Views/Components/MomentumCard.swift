
import SwiftUI

struct MomentumCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Momentum Tracking")
                .font(.headline)
            Text("Track your task completion streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
