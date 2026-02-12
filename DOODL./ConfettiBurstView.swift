import SwiftUI

struct ConfettiBurstView: View {
    struct Particle: Hashable {
        let angle: CGFloat
        let speed: CGFloat
        let size: CGFloat
        let spin: CGFloat
        let xJitter: CGFloat
        let yJitter: CGFloat
        let color: Color
        let shape: Int
    }

    let trigger: Int
    var duration: Double = 1.15

    @State private var burstStart: Date?
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { proxy in
            timeline
                .onChange(of: trigger) { _, newValue in
                    guard newValue > 0 else { return }
                    startBurst(in: proxy.size)
                }
                .onAppear {
                    if trigger > 0 {
                        startBurst(in: proxy.size)
                    }
                }
        }
        .allowsHitTesting(false)
    }

    private var timeline: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            confettiCanvas(now: context.date)
        }
    }

    private func confettiCanvas(now: Date) -> some View {
        Canvas(rendersAsynchronously: true) { (canvasContext: inout GraphicsContext, size: CGSize) in
            draw(into: &canvasContext, size: size, now: now)
        }
    }

    private func draw(into canvasContext: inout GraphicsContext, size: CGSize, now: Date) {
        guard let burstStart else { return }
        let t = now.timeIntervalSince(burstStart)
        let p = max(0, min(1, t / duration))
        if p >= 1 { return }

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
        let fade = 1.0 - p
        let gravity: CGFloat = 520

        for particle in particles {
            let base = particle.speed * CGFloat(p)
            let dx = cos(particle.angle) * base + particle.xJitter * CGFloat(p)
            let dy = sin(particle.angle) * base + (gravity * CGFloat(p) * CGFloat(p) * 0.5) + particle.yJitter * CGFloat(p)

            let x = center.x + dx
            let y = center.y + dy
            if x < -60 || x > size.width + 60 || y < -60 || y > size.height + 60 { continue }

            let rotation = Angle(radians: Double(particle.spin * CGFloat(p) * .pi))
            let rect = CGRect(x: x - particle.size * 0.5, y: y - particle.size * 0.5, width: particle.size, height: particle.size)

            let originalTransform = canvasContext.transform
            canvasContext.opacity = fade
            canvasContext.translateBy(x: rect.midX, y: rect.midY)
            canvasContext.rotate(by: rotation)
            canvasContext.translateBy(x: -rect.midX, y: -rect.midY)

            let cgRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
            let path: Path
            switch particle.shape {
            case 0:
                path = Path(roundedRect: cgRect, cornerRadius: particle.size * 0.24)
            case 1:
                path = Path(ellipseIn: cgRect)
            default:
                path = Path(CGRect(x: cgRect.minX, y: cgRect.minY, width: cgRect.width, height: cgRect.height * 0.65))
            }

            canvasContext.fill(path, with: .color(particle.color))
            canvasContext.transform = originalTransform
        }
    }

    private func startBurst(in size: CGSize) {
        burstStart = Date()
        particles = makeParticles(count: 80)
    }

    private func makeParticles(count: Int) -> [Particle] {
        var generator = SeededGenerator(seed: UInt64(0xC0FFEE) &+ UInt64(trigger))
        let palette: [Color] = [
            Color(hex: "FF3B30"),
            Color(hex: "FFFFFF"),
            Color(hex: "FDF7F2"),
            Color(hex: "B11222"),
            Color(hex: "F6D365")
        ]

        return (0..<count).map { _ in
            let angle = CGFloat.random(in: (-0.95 * .pi)...(-0.05 * .pi), using: &generator)
            let speed = CGFloat.random(in: 220...520, using: &generator)
            let size = CGFloat.random(in: 6...12, using: &generator)
            let spin = CGFloat.random(in: -2.6...2.6, using: &generator)
            let xJitter = CGFloat.random(in: -38...38, using: &generator)
            let yJitter = CGFloat.random(in: -20...20, using: &generator)
            let color = palette[Int.random(in: 0..<palette.count, using: &generator)]
            let shape = Int.random(in: 0...2, using: &generator)
            return Particle(angle: angle, speed: speed, size: size, spin: spin, xJitter: xJitter, yJitter: yJitter, color: color, shape: shape)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
