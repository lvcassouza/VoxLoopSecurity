import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Componente de padrão de pontos (grade 3x3) interativo com ligação contínua de linhas.
/// Utilizado para criação e desbloqueio do cofre por meio de desenho com linhas entre pontos.
public struct VoxPatternLockView: View {
    public let isError: Bool
    public let isEnabled: Bool
    public let onPatternCompleted: ([Int]) -> Void

    @State private var visitedDots: [Int] = []
    @State private var currentTouchPosition: CGPoint?
    @State private var isDragging: Bool = false

    public init(
        isError: Bool = false,
        isEnabled: Bool = true,
        onPatternCompleted: @escaping ([Int]) -> Void
    ) {
        self.isError = isError
        self.isEnabled = isEnabled
        self.onPatternCompleted = onPatternCompleted
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let originX = (geometry.size.width - size) / 2
            let originY = (geometry.size.height - size) / 2

            ZStack {
                // Fundo da área de toque
                RoundedRectangle(cornerRadius: 24)
                    .fill(VoxColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isError ? VoxColors.danger : VoxColors.border, lineWidth: 1.5)
                    )

                // 1. Linhas desenhadas entre os pontos visitados
                Canvas { context, _ in
                    guard !visitedDots.isEmpty else { return }

                    var path = Path()
                    let firstCenter = pontoCentro(indice: visitedDots[0], noTamanho: size, originX: originX, originY: originY)
                    path.move(to: firstCenter)

                    for index in visitedDots.dropFirst() {
                        let center = pontoCentro(indice: index, noTamanho: size, originX: originX, originY: originY)
                        path.addLine(to: center)
                    }

                    if let currentTouch = currentTouchPosition, isDragging {
                        path.addLine(to: currentTouch)
                    }

                    let corLinha = isError ? VoxColors.danger : VoxColors.brand
                    context.stroke(
                        path,
                        with: .color(corLinha),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
                }

                // 2. Os 9 pontos da grade 3x3
                ForEach(0..<9, id: \.self) { index in
                    let center = pontoCentro(indice: index, noTamanho: size, originX: originX, originY: originY)
                    let visitado = visitedDots.contains(index)

                    ZStack {
                        // Halo de destaque para pontos visitados
                        if visitado {
                            Circle()
                                .fill(isError ? VoxColors.danger.opacity(0.18) : VoxColors.brandSoft)
                                .frame(width: 44, height: 44)
                        }

                        // Ponto central
                        Circle()
                            .fill(visitado ? (isError ? VoxColors.danger : VoxColors.brand) : VoxColors.inkSecondary.opacity(0.35))
                            .frame(width: visitado ? 16 : 12, height: visitado ? 16 : 12)
                    }
                    .position(center)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: visitado)
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isDragging {
                            isDragging = true
                            visitedDots.removeAll(keepingCapacity: true)
                        }
                        currentTouchPosition = value.location

                        // Verificar colisão com algum ponto
                        let threshold = (size / 3) * 0.40
                        for index in 0..<9 {
                            let center = pontoCentro(indice: index, noTamanho: size, originX: originX, originY: originY)
                            let distancia = hypot(value.location.x - center.x, value.location.y - center.y)

                            if distancia <= threshold && !visitedDots.contains(index) {
                                // Adicionar ponto intermediário se a linha pular sobre um ponto central
                                if let last = visitedDots.last,
                                   let mid = pontoIntermediario(de: last, para: index),
                                   !visitedDots.contains(mid) {
                                    visitedDots.append(mid)
                                }
                                visitedDots.append(index)
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                        }
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        isDragging = false
                        currentTouchPosition = nil
                        guard !visitedDots.isEmpty else { return }
                        let finalPattern = visitedDots
                        onPatternCompleted(finalPattern)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grade de padrão de pontos 3 por 3. Arraste para ligar os pontos e desbloquear.")
    }

    /// Calcula o centro de cada ponto (0 a 8) na grade 3x3.
    private func pontoCentro(indice: Int, noTamanho size: CGFloat, originX: CGFloat, originY: CGFloat) -> CGPoint {
        let col = CGFloat(indice % 3)
        let row = CGFloat(indice / 3)
        let step = size / 3
        let x = originX + col * step + step / 2
        let y = originY + row * step + step / 2
        return CGPoint(x: x, y: y)
    }

    /// Determina se há um ponto intermediário não visitado na reta entre dois pontos.
    private func pontoIntermediario(de a: Int, para b: Int) -> Int? {
        let rowA = a / 3, colA = a % 3
        let rowB = b / 3, colB = b % 3
        let dRow = rowB - rowA
        let dCol = colB - colA
        if abs(dRow) % 2 == 0 && abs(dCol) % 2 == 0 {
            let midRow = rowA + dRow / 2
            let midCol = colA + dCol / 2
            return midRow * 3 + midCol
        }
        return nil
    }
}
