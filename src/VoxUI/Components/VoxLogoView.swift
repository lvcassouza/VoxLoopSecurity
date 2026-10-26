import SwiftUI

/// Desenho vetorial nativo em SwiftUI do símbolo oficial do Vox:
/// Um "V" dentro de um ciclo aberto (conforme `assets/brand/vox-mark.svg`).
public struct VoxLogoView: View {
    public let size: CGFloat
    public let customCycleColor: Color?
    public let customVColor: Color?

    public init(
        size: CGFloat = 64,
        cycleColor: Color? = nil,
        vColor: Color? = nil
    ) {
        self.size = size
        self.customCycleColor = cycleColor
        self.customVColor = vColor
    }

    public var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 96.0
            ZStack {
                // Ciclo aberto
                Path { path in
                    // M69.5 19.6 A 34 34 0 1 0 75.2 66.4
                    // Raio 34, centro aproximado em (48, 48)
                    let center = CGPoint(x: 48 * scale, y: 48 * scale)
                    let radius = 34 * scale
                    let startAngle = Angle(radians: -0.985) // ~ -56 graus (ponto 69.5, 19.6)
                    let endAngle = Angle(radians: 0.57)    // ~ 33 graus (ponto 75.2, 66.4)

                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: true
                    )
                }
                .stroke(
                    customCycleColor ?? VoxColors.ink,
                    style: StrokeStyle(lineWidth: 6.5 * scale, lineCap: .round)
                )

                // V central
                Path { path in
                    // m31.5 34 13.7 27.2 c1.2 2.4 4.4 2.4 5.6 0 L64.5 34
                    path.move(to: CGPoint(x: 31.5 * scale, y: 34.0 * scale))
                    path.addLine(to: CGPoint(x: 45.2 * scale, y: 61.2 * scale))
                    path.addQuadCurve(
                        to: CGPoint(x: 50.8 * scale, y: 61.2 * scale),
                        control: CGPoint(x: 48.0 * scale, y: 64.0 * scale)
                    )
                    path.addLine(to: CGPoint(x: 64.5 * scale, y: 34.0 * scale))
                }
                .stroke(
                    customVColor ?? VoxColors.brand,
                    style: StrokeStyle(lineWidth: 8.0 * scale, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Símbolo Vox: um V dentro de um ciclo aberto")
    }
}
