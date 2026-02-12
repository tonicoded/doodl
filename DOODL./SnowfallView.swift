import SwiftUI

struct SnowfallView: View {
    struct Flake: Hashable {
        let x: CGFloat       // 0...1
        let size: CGFloat    // px
        let speed: CGFloat   // px/sec
        let sway: CGFloat    // radians/sec
        let phase: CGFloat   // 0...1
        let opacity: CGFloat
    }

    let color: Color
    var flakeCount: Int = 60

    @State private var flakes: [Flake] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvasContext, size in
                if flakes.isEmpty {
                    return
                }

                let t = CGFloat(context.date.timeIntervalSinceReferenceDate)
                for flake in flakes {
                    let baseX = flake.x * size.width
                    let drift = sin((t * flake.sway) + (flake.phase * 10)) * 14
                    let x = baseX + drift

                    let travel = t * flake.speed + (flake.phase * (size.height + flake.size))
                    let y = travel.truncatingRemainder(dividingBy: size.height + flake.size) - flake.size

                    var resolved = canvasContext.resolve(
                        Text("•")
                            .font(.system(size: flake.size, weight: .heavy))
                    )
                    resolved.shading = .color(color.opacity(Double(flake.opacity)))
                    canvasContext.draw(resolved, at: CGPoint(x: x, y: y))
                }
            }
        }
        .onAppear {
            if flakes.isEmpty {
                flakes = makeFlakes(count: flakeCount)
            }
        }
    }

    private func makeFlakes(count: Int) -> [Flake] {
        var generator = SeededGenerator(seed: 20251225)
        return (0..<count).map { _ in
            let x = CGFloat.random(in: 0...1, using: &generator)
            let size = CGFloat.random(in: 6...13, using: &generator)
            let speed = CGFloat.random(in: 22...58, using: &generator)
            let sway = CGFloat.random(in: 0.6...1.6, using: &generator)
            let phase = CGFloat.random(in: 0...1, using: &generator)
            let opacity = CGFloat.random(in: 0.25...0.85, using: &generator)
            return Flake(x: x, size: size, speed: speed, sway: sway, phase: phase, opacity: opacity)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        // xorshift64*
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

