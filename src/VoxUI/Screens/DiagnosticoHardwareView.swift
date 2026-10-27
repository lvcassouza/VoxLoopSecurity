import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela de Diagnóstico de Hardware e Desempenho Criptográfico (Gate da Fase 3 / Issue #1).
/// Permite medir em hardware físico o tempo de derivação Argon2id, consumo de RAM e taxa de IO cifrada.
public struct DiagnosticoHardwareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var executando: Bool = false
    @State private var resultado: BenchmarkHardwareResult?
    @State private var mensagemErro: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header explicativo
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "cpu")
                                .font(.system(size: 24))
                                .foregroundColor(VoxColors.brand)
                            Text("Diagnóstico de Hardware")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(VoxColors.ink)
                        }

                        Text("Mede a latência real do Argon2id (3 ops, 64 MiB), a alocação de memória residente e a taxa de criptografia AES-256-GCM no aparelho atual.")
                            .font(.system(size: 14))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(VoxColors.surface)
                    .cornerRadius(16)

                    // Resultados
                    if let resultado {
                        VStack(spacing: 14) {
                            cartaoMetrica(
                                titulo: "Latência Argon2id",
                                valor: String(format: "%.0f ms", resultado.tempoDerivacaoArgon2idMs),
                                subtitulo: "Meta: < 1.800 ms em iPhone físico",
                                icone: "timer",
                                aprovado: resultado.tempoDerivacaoArgon2idMs <= 1800
                            )

                            cartaoMetrica(
                                titulo: "Memória Residente (Pico)",
                                valor: String(format: "%.1f MB", resultado.memoriaResidenteMB),
                                subtitulo: "Teto alocado pelo processo durante o cálculo",
                                icone: "memorychip",
                                aprovado: resultado.memoriaResidenteMB <= 150
                            )

                            cartaoMetrica(
                                titulo: "Taxa Criptográfica AES-GCM",
                                valor: String(format: "%.1f MB/s", resultado.taxaCriptografiaAESMBs),
                                subtitulo: "Vazão de streaming em blocos de 1 MiB",
                                icone: "lock.shield",
                                aprovado: true
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(VoxColors.success)
                                    Text("Avaliação do Gate da Fase 3")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(VoxColors.ink)
                                }
                                Text(resultado.statusHardware)
                                    .font(.system(size: 13))
                                    .foregroundColor(VoxColors.inkSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(VoxColors.surfaceMuted)
                            .cornerRadius(12)
                        }
                    } else if let erro = mensagemErro {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(VoxColors.danger)
                            Text(erro)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(VoxColors.danger)
                        }
                        .padding(20)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 44))
                                .foregroundColor(VoxColors.inkSecondary)
                            Text("Toque abaixo para executar a bateria de testes de desempenho criptográfico no aparelho.")
                                .font(.system(size: 14))
                                .foregroundColor(VoxColors.inkSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                    }

                    Spacer(minLength: 20)

                    VoxButton(
                        resultado == nil ? "Executar Diagnóstico" : "Repetir Diagnóstico",
                        icone: "play.circle",
                        isLoading: executando
                    ) {
                        Task { await rodarDiagnostico() }
                    }
                }
                .padding(20)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Diagnóstico")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }

    private func cartaoMetrica(
        titulo: String,
        valor: String,
        subtitulo: String,
        icone: String,
        aprovado: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icone)
                .font(.system(size: 22))
                .foregroundColor(aprovado ? VoxColors.brand : VoxColors.warning)
                .frame(width: 36, height: 36)
                .background(VoxColors.surfaceMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VoxColors.inkSecondary)
                Text(valor)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)
                Text(subtitulo)
                    .font(.system(size: 11))
                    .foregroundColor(VoxColors.inkSecondary)
            }

            Spacer()

            Image(systemName: aprovado ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(aprovado ? VoxColors.success : VoxColors.warning)
        }
        .padding(16)
        .background(VoxColors.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VoxColors.border, lineWidth: 1)
        )
    }

    @MainActor
    private func rodarDiagnostico() async {
        guard !executando else { return }
        executando = true
        mensagemErro = nil
        do {
            let res = try await HardwareBenchmarkService.shared.executarDiagnosticoCompleto()
            self.resultado = res
        } catch {
            self.mensagemErro = "Falha ao executar o diagnóstico: \(error.localizedDescription)"
        }
        executando = false
    }
}
