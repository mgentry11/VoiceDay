import SwiftUI

// MARK: - Confetti View

/// Celebratory confetti animation overlay
/// Used for major and epic task completions
struct ConfettiView: View {
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    init(
        particleCount: Int = 50,
        colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    ) {
        self.particleCount = particleCount
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle, isAnimating: isAnimating)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                withAnimation(.easeOut(duration: 3.0)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false) // Don't block touches
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                startX: CGFloat.random(in: 0...size.width),
                startY: -20,
                endX: CGFloat.random(in: -50...size.width + 50),
                endY: size.height + 50,
                color: colors.randomElement() ?? .green,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -720...720),
                scale: CGFloat.random(in: 0.5...1.2),
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle,
                delay: Double.random(in: 0...0.5)
            )
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let color: Color
    let rotation: Double
    let rotationSpeed: Double
    let scale: CGFloat
    let shape: ConfettiShape
    let delay: Double
}

enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case triangle
    case star
}

// MARK: - Confetti Piece

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let isAnimating: Bool

    var body: some View {
        confettiShape
            .frame(width: 8 * particle.scale, height: 12 * particle.scale)
            .rotationEffect(.degrees(isAnimating ? particle.rotation + particle.rotationSpeed : particle.rotation))
            .position(
                x: isAnimating ? particle.endX : particle.startX,
                y: isAnimating ? particle.endY : particle.startY
            )
            .opacity(isAnimating ? 0 : 1)
            .animation(
                .easeOut(duration: 2.5)
                .delay(particle.delay),
                value: isAnimating
            )
    }

    @ViewBuilder
    private var confettiShape: some View {
        switch particle.shape {
        case .rectangle:
            Rectangle().fill(particle.color)
        case .circle:
            Circle().fill(particle.color)
        case .triangle:
            Triangle().fill(particle.color)
        case .star:
            Star(corners: 5, smoothness: 0.45).fill(particle.color)
        }
    }
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    let corners: Int
    let smoothness: Double

    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        var currentAngle = -CGFloat.pi / 2
        let angleAdjustment = .pi * 2 / CGFloat(corners * 2)
        let innerX = center.x * smoothness
        let innerY = center.y * smoothness
        var path = Path()

        path.move(to: CGPoint(
            x: center.x * cos(currentAngle),
            y: center.y * sin(currentAngle)
        ))

        var bottomEdge: CGFloat = 0

        for corner in 0..<corners * 2 {
            let sinAngle = sin(currentAngle)
            let cosAngle = cos(currentAngle)
            let bottom: CGFloat

            if corner.isMultiple(of: 2) {
                bottom = center.y * sinAngle
                path.addLine(to: CGPoint(
                    x: center.x + center.x * cosAngle,
                    y: center.y + bottom
                ))
            } else {
                bottom = innerY * sinAngle
                path.addLine(to: CGPoint(
                    x: center.x + innerX * cosAngle,
                    y: center.y + bottom
                ))
            }

            if bottom > bottomEdge {
                bottomEdge = bottom
            }

            currentAngle += angleAdjustment
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Points Badge View

/// Animated badge showing points earned
struct PointsBadgeView: View {
    let points: Int
    @Binding var isShowing: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        if isShowing && points > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("+\(points)")
                    .fontWeight(.bold)
            }
            .font(.title2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            .onDisappear {
                scale = 0.5
                opacity = 0
            }
        }
    }
}

// MARK: - Celebration Overlay

/// Full-screen celebration overlay combining confetti and points
struct CelebrationOverlay: View {
    @ObservedObject var celebrationService = CelebrationService.shared

    var body: some View {
        ZStack {
            // Confetti layer
            if celebrationService.showConfetti {
                ConfettiView(particleCount: 60)
                    .ignoresSafeArea()
            }

            // Points badge
            VStack {
                Spacer()
                PointsBadgeView(
                    points: celebrationService.pointsEarned,
                    isShowing: $celebrationService.showPointsBadge
                )
                .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("Confetti") {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiView()
    }
}

#Preview("Points Badge") {
    PointsBadgeView(points: 25, isShowing: .constant(true))
}

#Preview("Full Celebration") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        Text("Task List Here")
        CelebrationOverlay()
    }
    .onAppear {
        CelebrationService.shared.celebrate(
            level: .major,
            taskTitle: "Test Task",
            points: 25
        )
    }
}
