import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela da aba Backup (seção 6.7 de ui-visual-spec.md).
public struct BackupView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onNavegarParaRestauracao: () -> Void

    @State private var emProgressoCriacao: Bool = false
    @State private var mostrarFolhaVerificacao: Bool = false
    @State private var resultadoVerificacao: ResultadoVerificacaoBackup?
    @State private var modoVerificacaoSimulada: ModoSimulacaoBackup = .integro

    public init(
        accessManager: VaultAccessManager,
        onNavegarParaRestauracao: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onNavegarParaRestauracao = onNavegarParaRestauracao
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Demonstração de backup")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("Os botões abaixo alteram estados de exemplo. Nenhum arquivo de backup é criado ou criptografado.")
                            .font(.system(size: 15))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    // Card de Estado Principal (1 de 3 estados)
                    cardEstadoPrincipal

                    // Bloco fixo de esclarecimento
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(VoxColors.inkSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sobre as cópias")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VoxColors.ink)
                            Text("Esta versão não cria arquivos de backup e não lê destinos no app Arquivos.")
                                .font(.system(size: 13))
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                    }
                    .padding(14)
                    .background(VoxColors.surfaceMuted)
                    .cornerRadius(14)

                    // Ação de Verificação de Backup
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Demonstração de verificação")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VoxColors.ink)

                        VoxButton("Simular verificação de backup", icone: "checkmark.seal", variante: .secondary) {
                            mostrarFolhaVerificacao = true
                        }
                    }
                    .padding(.top, 8)

                    // Card informativo para Restaurar
                    Button(action: onNavegarParaRestauracao) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(VoxColors.brandSoft)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(VoxColors.brand)
                                    .font(.system(size: 18, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                            Text("Simular restauração")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(VoxColors.ink)
                                Text("O fluxo adiciona apenas itens sintéticos; não abre um arquivo real.")
                                    .font(.system(size: 13))
                                    .foregroundColor(VoxColors.inkSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(VoxColors.inkSecondary)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(16)
                        .background(VoxColors.surface)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VoxColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Backup")
            .sheet(isPresented: $mostrarFolhaVerificacao) {
                FolhaVerificarBackupView(accessManager: accessManager)
            }
        }
    }

    // MARK: - Subviews de Estado

    @ViewBuilder
    private var cardEstadoPrincipal: some View {
        switch accessManager.estadoBackup {
        case .nuncaCriado:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VoxColors.brandSoft)
                            .frame(width: 40, height: 40)
                        Image(systemName: "externaldrive.badge.plus")
                            .foregroundColor(VoxColors.brand)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nenhuma simulação de backup executada")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                        Text("Os cartões exibidos existem apenas nesta demonstração.")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                }

                VoxButton(
                    "Simular criação de backup",
                    variante: .primary,
                    isLoading: emProgressoCriacao
                ) {
                    criarBackup()
                }
            }
            .padding(18)
            .background(VoxColors.surface)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoxColors.border, lineWidth: 1))

        case .atualizado(let data, let contagem):
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VoxColors.success.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "checkmark")
                            .foregroundColor(VoxColors.success)
                            .font(.system(size: 18, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulação de backup concluída")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                        Text("Último backup: \(formatarData(data)) · \(contagem) itens")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                }

                VoxButton("Simular novo backup", variante: .secondary, isLoading: emProgressoCriacao) {
                    criarBackup()
                }
            }
            .padding(18)
            .background(VoxColors.surface)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoxColors.border, lineWidth: 1))

        case .desatualizado(let dataUltimo, let pendentes):
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VoxColors.warning.opacity(0.14))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(VoxColors.warning)
                            .font(.system(size: 18, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulação desatualizada")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                        Text("Há \(pendentes) item(ns) ainda não incluídos.")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)
                        if let ultimo = dataUltimo {
                            Text("Último backup: \(formatarData(ultimo))")
                                .font(.system(size: 12))
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                    }
                }

                VoxButton("Simular novo backup", variante: .primary, isLoading: emProgressoCriacao) {
                    criarBackup()
                }
            }
            .padding(18)
            .background(VoxColors.surface)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoxColors.border, lineWidth: 1))
        }
    }

    private func criarBackup() {
        emProgressoCriacao = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            _ = try? accessManager.criarBackup()
            emProgressoCriacao = false
        }
    }

    private func formatarData(_ data: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMM, HH:mm"
        return f.string(from: data)
    }
}

/// Folha para demonstrar e testar a verificação de integridade de um arquivo de backup.
struct FolhaVerificarBackupView: View {
    @ObservedObject var accessManager: VaultAccessManager
    @Environment(\.dismiss) private var dismiss

    @State private var modoSimulacao: ModoSimulacaoBackup = .integro
    @State private var resultado: ResultadoVerificacaoBackup?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VoxPrototypeDisclosureView()

                Text("Simular verificação de backup")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Escolha um cenário fictício. Esta tela não seleciona nem verifica arquivos.")
                    .font(.system(size: 14))
                    .foregroundColor(VoxColors.inkSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Cenário demonstrativo:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VoxColors.inkSecondary)

                    Picker("Modo de teste", selection: $modoSimulacao) {
                        Text("Exemplo íntegro").tag(ModoSimulacaoBackup.integro)
                        Text("Exemplo alterado").tag(ModoSimulacaoBackup.adulterado)
                        Text("Formato Incompatível").tag(ModoSimulacaoBackup.versaoIncompativel)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(VoxColors.surfaceMuted)
                .cornerRadius(14)

                VoxButton("Exibir resultado demonstrativo", variante: .primary) {
                    resultado = accessManager.verificarBackup(modo: modoSimulacao)
                }

                if let res = resultado {
                    exibirResultado(res)
                }

                Spacer()
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }

    @ViewBuilder
    private func exibirResultado(_ res: ResultadoVerificacaoBackup) -> some View {
        switch res {
        case .legivel(let data, let contagem):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VoxColors.success)
                    Text("Exemplo marcado como legível")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VoxColors.ink)
                }
                Text("\(contagem) itens sintéticos no estado demonstrativo desde \(data.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
                Text("Nenhum arquivo foi aberto ou validado.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VoxColors.inkSecondary)
            }
            .padding(14)
            .background(VoxColors.success.opacity(0.1))
            .cornerRadius(14)

        case .impossivelVerificar(let motivo):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VoxColors.danger)
                    Text("Cenário demonstrativo inválido")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VoxColors.ink)
                }
                Text(motivo)
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
                Text("Nenhum arquivo real foi lido ou alterado.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VoxColors.inkSecondary)
            }
            .padding(14)
            .background(VoxColors.danger.opacity(0.1))
            .cornerRadius(14)

        case .formatoIncompativel(let versao):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(VoxColors.warning)
                    Text("Cenário de formato incompatível")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VoxColors.ink)
                }
                Text("O exemplo usa o rótulo de versão \(versao). Nenhum backup real foi lido.")
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
            }
            .padding(14)
            .background(VoxColors.warning.opacity(0.12))
            .cornerRadius(14)
        }
    }
}
