import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case overview
    case channels
    case settings
    case tools
}

struct ContentView: View {
    @EnvironmentObject private var store: RadioStore
    @State private var selectedTab: RootTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-OpenSettings") { return .settings }
        if arguments.contains("-OpenMore") { return .tools }
        return .overview
    }()
    @State private var hasEnteredHome = ProcessInfo.processInfo.arguments.contains("-SkipConnectionGate")

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if hasEnteredHome {
                    mainTabs
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                } else {
                    StartupConnectScreen {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            hasEnteredHome = true
                        }
                    }
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }

            if let progress = store.operationProgress {
                GlobalProgressBanner(state: progress)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: hasEnteredHome)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: store.operationProgress?.id)
        .onChange(of: store.linkState.isConnected) { _, isConnected in
            if isConnected {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    hasEnteredHome = true
                }
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            OverviewScreen(selectedTab: $selectedTab)
                .tabItem {
                    Label("总览", systemImage: "gauge.with.needle")
                }
                .tag(RootTab.overview)

            ChannelsScreen()
                .tabItem {
                    Label("信道", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(RootTab.channels)

            SettingsScreen()
                .tabItem {
                    Label("功能", systemImage: "slider.horizontal.3")
                }
                .tag(RootTab.settings)

            ToolsScreen()
                .tabItem {
                    Label("更多", systemImage: "square.grid.2x2")
                }
                .tag(RootTab.tools)
        }
        .tint(AppTheme.primary)
    }
}

private struct StartupConnectScreen: View {
    @EnvironmentObject private var store: RadioStore
    let onSkip: () -> Void
    @State private var ringsActive = false
    @State private var contentVisible = false
    @State private var scanPhase = false

    private var isConnecting: Bool {
        switch store.linkState {
        case .scanning, .connecting, .discovering:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            AppTheme.surfaceBackground.ignoresSafeArea()

            AnimatedRadioGrid(isActive: ringsActive)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 18) {
                    AnimatedSignalMark(isConnecting: isConnecting, isActive: ringsActive)

                    VStack(spacing: 10) {
                        Text("连接 8800Pro")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .contentTransition(.numericText())

                        Text("连接成功后进入主页")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .offset(y: contentVisible ? 0 : 18)
                .opacity(contentVisible ? 1 : 0)

                VStack(spacing: 14) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            scanPhase.toggle()
                            store.connectBluetooth()
                        }
                    } label: {
                        ConnectButtonLabel(isConnecting: isConnecting, scanPhase: scanPhase)
                    }
                    .disabled(isConnecting)
                    .buttonStyle(PressableButtonStyle(scale: 0.97))

                    ConnectionStatePill(title: store.linkState.title, isConnected: store.linkState.isConnected, isConnecting: isConnecting)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.linkState.title)

                    if let notice = store.notice {
                        Text(notice.text)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: contentVisible ? 0 : 24)
                .opacity(contentVisible ? 1 : 0)

                Spacer()

                Text("首次进入不会预置任何信道，读频后会显示设备里的真实配置")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .opacity(contentVisible ? 1 : 0)

                Button {
                    onSkip()
                } label: {
                    Text("我要跳过连接")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .padding(.bottom, 28)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .onAppear {
            ringsActive = true
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.08)) {
                contentVisible = true
            }
        }
    }
}

private struct AnimatedRadioGrid: View {
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppTheme.primary.opacity((row + column).isMultiple(of: 4) ? 0.045 : 0.018))
                            .frame(width: 1, height: 22)
                            .frame(maxWidth: .infinity)
                            .opacity(isActive ? 1 : 0.2)
                            .animation(
                                .easeInOut(duration: 2.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(row + column) * 0.06),
                                value: isActive
                            )
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 26)
        .opacity(0.55)
    }
}

private struct AnimatedSignalMark: View {
    let isConnecting: Bool
    let isActive: Bool
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(AppTheme.primary.opacity(0.18 - Double(index) * 0.035), lineWidth: 1.5)
                    .frame(width: 116 + CGFloat(index * 42), height: 116 + CGFloat(index * 42))
                    .scaleEffect(isActive ? 1.16 : 0.72)
                    .opacity(isActive ? 0 : 0.65)
                    .animation(
                        .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.42),
                        value: isActive
                    )
            }

            Circle()
                .trim(from: 0.05, to: 0.34)
                .stroke(
                    AngularGradient(colors: [AppTheme.primary.opacity(0.1), AppTheme.primary, AppTheme.primary.opacity(0.12)], center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(isConnecting ? 1 : 0.45)
                .animation(.linear(duration: isConnecting ? 1.1 : 3.4).repeatForever(autoreverses: false), value: spin)

            Circle()
                .fill(AppTheme.primary.opacity(0.12))
                .frame(width: 104, height: 104)
                .shadow(color: AppTheme.primary.opacity(isConnecting ? 0.26 : 0.14), radius: isConnecting ? 24 : 12, x: 0, y: 8)
                .scaleEffect(isConnecting ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isConnecting)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .symbolEffect(.variableColor.iterative, options: .repeating, value: isConnecting)
        }
        .frame(height: 210)
        .onAppear {
            spin = true
        }
    }
}

private struct ConnectButtonLabel: View {
    let isConnecting: Bool
    let scanPhase: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isConnecting {
                ProgressView()
                    .tint(.white)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.pulse, value: scanPhase)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(isConnecting ? "正在连接" : "连接蓝牙")
                .font(.system(size: 17, weight: .semibold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: isConnecting ? [AppTheme.primary.opacity(0.82), AppTheme.primaryLight] : [AppTheme.primary, AppTheme.primary.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(isConnecting ? 0.22 : 0))
                .frame(width: 86, height: 56)
                .blur(radius: 14)
                .offset(x: isConnecting ? 250 : -120)
                .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false), value: isConnecting)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.primary.opacity(0.26), radius: 18, x: 0, y: 10)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isConnecting)
    }
}

private struct ConnectionStatePill: View {
    let title: String
    let isConnected: Bool
    let isConnecting: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? AppTheme.success : (isConnecting ? AppTheme.primary : AppTheme.textTertiary))
                .frame(width: 8, height: 8)
                .scaleEffect(isConnecting ? 1.35 : 1)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isConnecting)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .contentTransition(.opacity)
        }
        .foregroundStyle(isConnected ? AppTheme.success : AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background((isConnected ? AppTheme.success : AppTheme.primary).opacity(isConnecting || isConnected ? 0.12 : 0.06))
        .clipShape(Capsule())
    }
}

private struct GlobalProgressBanner: View {
    let state: OperationProgressState

    private var percentText: String {
        "\(Int((state.normalizedProgress * 100).rounded()))%"
    }

    private var accentColor: Color {
        switch state.tone {
        case .active:
            return AppTheme.primary
        case .success:
            return AppTheme.success
        case .warning:
            return AppTheme.warning
        }
    }

    private var iconName: String {
        switch state.tone {
        case .active:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse, options: .repeating, value: state.tone == .active)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(state.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(state.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(percentText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                }

                ProgressView(value: state.normalizedProgress)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.title)，\(state.message)，\(percentText)")
    }
}

// MARK: - Design System
enum AppTheme {
    static let primary = Color(red: 0.0, green: 0.7, blue: 0.64)
    static let primaryLight = Color(red: 0.4, green: 0.85, blue: 0.8)
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21)
    
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceBackground = Color(uiColor: .systemGroupedBackground)
    static let fieldBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
    
    static func cardShadow() -> some View {
        EmptyView()
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    static func buttonShadow() -> some View {
        EmptyView()
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Overview Screen
private struct OverviewScreen: View {
    @EnvironmentObject private var store: RadioStore
    @Binding var selectedTab: RootTab
    @State private var showQuickActions = false

    private var activeChannels: [Channel] {
        store.data.channels[store.selectedBankIndex].filter { $0.visible && !$0.rxFreq.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let notice = store.notice {
                            NoticeBanner(notice: notice)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        heroCard
                        
                        quickActionsCard
                        
                        metricsCard
                        
                        recommendedFlowCard
                        
                        activeChannelsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                        Text("8800Pro")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    private var heroCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("控制台")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("连接设备、读写配置、管理信道与备份")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    Spacer()
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    StatusBadge(
                        title: store.linkState.title,
                        isPositive: store.linkState.isConnected,
                        icon: store.linkState.isConnected ? "checkmark.circle.fill" : "circle"
                    )
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(store.currentBankName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("当前分组")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
    }
    
    private var quickActionsCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Label("快速操作", systemImage: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    PrimaryButton(
                        title: store.linkState.isConnected ? "断开" : "连接",
                        icon: store.linkState.isConnected ? "xmark.circle.fill" : "antenna.radiowaves.left.and.right",
                        isCompact: true
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if store.linkState.isConnected {
                                store.disconnect()
                            } else {
                                store.connectBluetooth()
                            }
                        }
                    }
                    
                    SecondaryButton(
                        title: "读频",
                        icon: "arrow.down.circle.fill",
                        isCompact: true
                    ) {
                        store.readRadio()
                    }
                    
                    SecondaryButton(
                        title: "写频",
                        icon: "arrow.up.circle.fill",
                        isCompact: true
                    ) {
                        store.writeRadio()
                    }
                }
            }
        }
    }
    
    private var metricsCard: some View {
        HStack(spacing: 12) {
            MetricCard(
                title: "已配信道",
                value: "\(store.data.visibleChannelCount)",
                icon: "antenna.radiowaves.left.and.right",
                color: AppTheme.primary
            )
            
            MetricCard(
                title: "本地备份",
                value: "\(store.backups.count)",
                icon: "folder.fill",
                color: AppTheme.success
            )
        }
    }
    
    private var recommendedFlowCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("推荐流程", systemImage: "map.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    FlowStep(number: 1, text: "点击「连接」，确认状态变成已连接")
                    FlowStep(number: 2, text: "先「读频」并保留自动备份")
                    FlowStep(number: 3, text: "去信道页修改一条测试，再「写频」")
                    FlowStep(number: 4, text: "确认机器显示正常后继续批量整理")
                }
                
                Text("第一次建议先读频，再改一条信道试写，确认没问题后再批量整理")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
    
    private var activeChannelsCard: some View {
        Group {
            if !activeChannels.isEmpty {
                ModernCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("活跃信道", systemImage: "waveform")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(activeChannels.count) 条")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        VStack(spacing: 8) {
                            ForEach(activeChannels.prefix(5)) { channel in
                                CompactChannelRow(channel: channel)
                            }
                        }
                        
                        if activeChannels.count > 5 {
                            Button {
                                selectedTab = .channels
                            } label: {
                                HStack {
                                    Text("查看全部 \(activeChannels.count) 条信道")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.primaryLight.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }
}
// MARK: - Channels Screen
private struct ChannelsScreen: View {
    @EnvironmentObject private var store: RadioStore
    @State private var showingEditor = false
    @State private var showingImport = false
    @State private var editingBankIndex: Int?
    @State private var editingBankName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        bankOverview
                        
                        searchBar
                        
                        channelList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("信道管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingImport = true
                        } label: {
                            Label("导入中继台", systemImage: "square.and.arrow.down")
                        }
                        
                        Button {
                            store.importFromClipboard()
                        } label: {
                            Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                        }
                        
                        Divider()
                        
                        Toggle(isOn: $store.showEmptyChannels) {
                            Label("显示空信道", systemImage: "eye")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ChannelEditorSheet()
            }
            .sheet(isPresented: $showingImport) {
                RepeaterImportSheet()
            }
            .alert("编辑区域名称", isPresented: Binding(
                get: { editingBankIndex != nil },
                set: { if !$0 { editingBankIndex = nil } }
            )) {
                TextField("区域名称", text: $editingBankName)
                Button("保存") {
                    if let editingBankIndex {
                        store.updateBankName(index: editingBankIndex, value: editingBankName)
                    }
                    editingBankIndex = nil
                }
                Button("取消", role: .cancel) {
                    editingBankIndex = nil
                }
            } message: {
                Text("区域名称会随写频写入机器。")
            }
        }
    }
    
    private var bankOverview: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.13))
                            .frame(width: 48, height: 48)
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前区域")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)

                        Text("\(store.selectedBankIndex + 1) · \(store.currentBankName)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("\(activeChannelCount(in: store.selectedBankIndex)) 条有效信道，长按下方区域可编辑名称")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        beginEditingBank(store.selectedBankIndex)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.92))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(store.data.bankNames.enumerated()), id: \.offset) { index, name in
                            BankChip(
                                index: index,
                                name: name,
                                activeCount: activeChannelCount(in: index),
                                isSelected: index == store.selectedBankIndex,
                                selectAction: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        store.selectBank(index)
                                    }
                                },
                                editAction: {
                                    beginEditingBank(index)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                
                TextField("搜索信道名称或频率", text: $store.channelSearchText)
                    .font(.system(size: 15))
                
                if !store.channelSearchText.isEmpty {
                    Button {
                        store.channelSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(AppTheme.cardShadow())
        }
    }
    
    private var channelList: some View {
        LazyVStack(spacing: 10) {
            if store.filteredChannels.isEmpty {
                NewChannelCard(
                    title: store.channelSearchText.isEmpty ? "当前区域还没有信道" : "没有匹配的信道",
                    subtitle: "新建会使用当前区域里的第一个空信道，保存后它会出现在列表中。",
                    action: createNewChannel
                )
            } else {
                ForEach(store.filteredChannels) { channel in
                    ChannelCard(channel: channel) {
                        store.selectChannel(id: channel.id)
                        showingEditor = true
                    }
                }

                NewChannelCard(
                    title: "新建信道",
                    subtitle: "在当前区域中找到第一个空信道并写入频率、亚音和名称。",
                    isCompact: true,
                    action: createNewChannel
                )
            }
        }
    }

    private func activeChannelCount(in bankIndex: Int) -> Int {
        guard store.data.channels.indices.contains(bankIndex) else { return 0 }
        return store.data.channels[bankIndex].filter { $0.visible && !$0.rxFreq.isEmpty }.count
    }

    private func beginEditingBank(_ index: Int) {
        guard store.data.bankNames.indices.contains(index) else { return }
        editingBankIndex = index
        editingBankName = store.data.bankNames[index]
    }

    private func createNewChannel() {
        guard store.prepareNewChannelInCurrentBank() else { return }
        showingEditor = true
    }
}

// MARK: - Settings Screen
private struct SettingsScreen: View {
    @EnvironmentObject private var store: RadioStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 18) {
                        SettingsHeroCard(functions: store.data.functions, linkTitle: store.linkState.title)

                        SettingsSection(
                            title: "通道与显示",
                            subtitle: "控制 A/B 通道展示方式、当前区域和背光逻辑。",
                            icon: "rectangle.2.swap",
                            color: AppTheme.primary
                        ) {
                            SettingsGrid {
                                SettingMenuControl(title: "A 通道显示", subtitle: "屏幕上方主通道显示内容", icon: "a.square", color: AppTheme.primary, selection: settingBinding(\.chADisplay), options: RadioChoices.displayMode)
                                SettingMenuControl(title: "B 通道显示", subtitle: "副通道显示内容", icon: "b.square", color: AppTheme.primary, selection: settingBinding(\.chBDisplay), options: RadioChoices.displayMode)
                                SettingMenuControl(title: "A 当前区域", subtitle: "A 通道默认使用的信道组", icon: "rectangle.3.group", color: .blue, selection: settingBinding(\.currentBankA), options: bankOptions)
                                SettingMenuControl(title: "B 当前区域", subtitle: "B 通道默认使用的信道组", icon: "rectangle.3.group.fill", color: .blue, selection: settingBinding(\.currentBankB), options: bankOptions)
                                SettingMenuControl(title: "背光时长", subtitle: "按键或收发后的屏幕点亮时间", icon: "sun.max", color: .orange, selection: settingBinding(\.backlight), options: backlightOptions)
                                SettingMenuControl(title: "开机显示", subtitle: "开机时显示的界面类型", icon: "power", color: .purple, selection: settingBinding(\.powerOnDisplay), options: powerOnDisplayOptions)
                            }
                        }

                        SettingsSection(
                            title: "音频与收发",
                            subtitle: "静噪、VOX、麦克风增益和蓝牙音频都集中在这里。",
                            icon: "speaker.wave.3",
                            color: .indigo
                        ) {
                            SettingsGrid {
                                SettingMenuControl(title: "静噪等级", subtitle: "越高越不容易被弱信号打开", icon: "waveform", color: .indigo, selection: settingBinding(\.sql), options: levelOptions)
                                SettingMenuControl(title: "VOX 灵敏度", subtitle: "声控发射触发强度", icon: "mic", color: .indigo, selection: settingBinding(\.vox), options: levelOptions)
                                SettingMenuControl(title: "VOX 延迟", subtitle: "声控发射松开后的保持时间", icon: "timer", color: .indigo, selection: settingBinding(\.voxDelay), options: delayOptions)
                                SettingMenuControl(title: "麦克风增益", subtitle: "本机麦克风输入增益", icon: "mic.fill", color: .indigo, selection: settingBinding(\.micGain), options: gainOptions)
                                SettingMenuControl(title: "蓝牙麦克风", subtitle: "蓝牙麦克风输入增益", icon: "dot.radiowaves.left.and.right", color: .cyan, selection: settingBinding(\.bluetoothMicGain), options: bluetoothGainOptions)
                                SettingMenuControl(title: "蓝牙音频", subtitle: "蓝牙耳机/音箱输出增益", icon: "headphones", color: .cyan, selection: settingBinding(\.bluetoothAudioGain), options: bluetoothGainOptions)
                            }
                        }

                        SettingsSection(
                            title: "工作模式",
                            subtitle: "决定双守、信道/频率模式、省电和扫描策略。",
                            icon: "gearshape.2",
                            color: .green
                        ) {
                            SettingsGrid {
                                SettingSegmentedControl(title: "双守", subtitle: "同时监听 A/B 两个通道", icon: "arrow.triangle.2.circlepath", color: .green, selection: settingBinding(\.dualStandby), options: RadioChoices.onOff)
                                SettingMenuControl(title: "A 工作模式", subtitle: "A 通道使用信道或 VFO", icon: "a.circle", color: .green, selection: settingBinding(\.chAWorkmode), options: RadioChoices.workMode)
                                SettingMenuControl(title: "B 工作模式", subtitle: "B 通道使用信道或 VFO", icon: "b.circle", color: .green, selection: settingBinding(\.chBWorkmode), options: RadioChoices.workMode)
                                SettingMenuControl(title: "扫描模式", subtitle: "扫描暂停和继续的规则", icon: "dot.viewfinder", color: .green, selection: settingBinding(\.scanMode), options: RadioChoices.scanMode)
                                SettingMenuControl(title: "省电模式", subtitle: "待机时降低耗电", icon: "battery.75percent", color: .green, selection: settingBinding(\.saveMode), options: saveModeOptions)
                                SettingMenuControl(title: "自动锁键", subtitle: "闲置后自动锁定键盘", icon: "lock", color: .green, selection: settingBinding(\.autoLock), options: RadioChoices.autoLock)
                            }
                        }

                        SettingsSection(
                            title: "提示与按键",
                            subtitle: "控制提示音、尾音、PTT 延迟和自定义按键。",
                            icon: "keyboard",
                            color: .orange
                        ) {
                            SettingsGrid {
                                SettingSegmentedControl(title: "语音提示", subtitle: "菜单与操作语音播报", icon: "person.wave.2", color: .orange, selection: settingBinding(\.voice), options: RadioChoices.onOff)
                                SettingSegmentedControl(title: "按键音", subtitle: "按键反馈声音", icon: "speaker.badge.exclamationmark", color: .orange, selection: settingBinding(\.beep), options: RadioChoices.onOff)
                                SettingMenuControl(title: "PTT 延迟", subtitle: "按下 PTT 后的发射延迟", icon: "hand.tap", color: .orange, selection: settingBinding(\.pttDelay), options: pttDelayOptions)
                                SettingSegmentedControl(title: "Roger 音", subtitle: "发射结束提示音", icon: "checkmark.message", color: .orange, selection: settingBinding(\.roger), options: RadioChoices.onOff)
                                SettingMenuControl(title: "中继尾音消除", subtitle: "发射结束后的静噪尾音处理", icon: "antenna.radiowaves.left.and.right", color: .orange, selection: settingBinding(\.rptTailClear), options: rptTailOptions)
                                SettingMenuControl(title: "短按侧键", subtitle: "侧键短按功能", icon: "button.programmable", color: .orange, selection: settingBinding(\.key2Short), options: keyActionOptions)
                            }
                        }

                        SettingsSaveCard {
                            store.saveFunctionSettings()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 132)
                }
            }
            .navigationTitle("功能")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var bankOptions: [String] {
        store.data.bankNames.enumerated().map { index, name in
            "\(index + 1) · \(name)"
        }
    }

    private var levelOptions: [String] {
        (0...9).map { "等级 \($0)" }
    }

    private var delayOptions: [String] {
        (0...15).map { "\($0)" }
    }

    private var pttDelayOptions: [String] {
        (0...15).map { "\($0)" }
    }

    private var saveModeOptions: [String] {
        ["关闭", "省电 1", "省电 2", "省电 3"]
    }

    private var gainOptions: [String] {
        ["低", "标准", "高"]
    }

    private var bluetoothGainOptions: [String] {
        ["0", "1", "2", "3", "4"]
    }

    private var backlightOptions: [String] {
        ["常亮", "5秒", "10秒", "20秒", "30秒", "1分钟", "2分钟", "5分钟", "自动"]
    }

    private var powerOnDisplayOptions: [String] {
        ["默认", "电压", "图片", "文字", "信道", "频率", "名称", "时间", "欢迎语", "呼号", "Logo", "简洁", "详细", "区域", "A 通道", "B 通道", "双通道", "菜单", "状态", "自定义 1", "自定义 2", "关闭"]
    }

    private var rptTailOptions: [String] {
        ["关闭", "100ms", "200ms", "300ms", "400ms", "500ms", "600ms", "700ms", "800ms", "900ms", "1000ms"]
    }

    private var keyActionOptions: [String] {
        ["无", "监听", "扫描", "手电", "告警"]
    }

    private func settingBinding(_ keyPath: WritableKeyPath<RadioFunctionSettings, Int>) -> Binding<Int> {
        Binding(
            get: { store.data.functions[keyPath: keyPath] },
            set: { store.updateFunctionSetting(keyPath, value: $0) }
        )
    }
}

// MARK: - Tools Screen
private struct ToolsScreen: View {
    @EnvironmentObject private var store: RadioStore
    @State private var selectedTool: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        MoreHeroCard()

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MoreStatCard(title: "有效信道", value: "\(store.data.visibleChannelCount)", icon: "list.number", color: AppTheme.primary)
                            MoreStatCard(title: "区域", value: store.currentBankName, icon: "rectangle.3.group", color: Color.blue)
                            MoreStatCard(title: "快照", value: "\(store.backups.count)", icon: "clock.arrow.circlepath", color: AppTheme.success)
                            MoreStatCard(title: "日志", value: "\(store.logs.count)", icon: "doc.text", color: Color.purple)
                        }

                        MoreProtocolCard()

                        MoreToolSection(title: "高级写频", subtitle: "VFO、DTMF、FM 与开机图都放在这里集中处理。") {
                            ToolCard(
                                title: "VFO 频率",
                                description: "手动输入 A/B 频率、差频、亚音和步进。",
                                icon: "waveform.path",
                                color: AppTheme.primary
                            ) {
                                selectedTool = "vfo"
                            }

                            ToolCard(
                                title: "DTMF 编码",
                                description: "配置本机 ID、PTT ID、组呼号码和成员名称。",
                                icon: "number.square",
                                color: Color.blue
                            ) {
                                selectedTool = "dtmf"
                            }

                            ToolCard(
                                title: "FM 收音",
                                description: "编辑 FM 当前频率与广播电台记忆。",
                                icon: "radio",
                                color: Color.orange
                            ) {
                                selectedTool = "fm"
                            }

                            ToolCard(
                                title: "开机图",
                                description: "蓝牙写入开机图仍在开发中，暂不开放操作。",
                                icon: "photo",
                                color: Color.indigo,
                                status: "开发中",
                                isDisabled: true
                            ) {
                            }
                        }

                        MoreToolSection(title: "数据维护", subtitle: "写频前后建议保留快照，出问题可以快速恢复。") {
                            ToolCard(
                                title: "备份与恢复",
                                description: "管理本地配置快照，恢复读写前的频率表。",
                                icon: "folder.badge.gearshape",
                                color: AppTheme.success
                            ) {
                                selectedTool = "backup"
                            }

                            ToolCard(
                                title: "通信日志",
                                description: "查看握手、读频、蓝牙写入与 ACK 明细。",
                                icon: "doc.text.magnifyingglass",
                                color: Color.purple
                            ) {
                                selectedTool = "logs"
                            }
                        }

                        MoreToolSection(title: "帮助与说明", subtitle: "新手流程、功能解释和版本信息也从这里进入。") {
                            ToolCard(
                                title: "新手教程",
                                description: "读频、写频、区域和信道的基础概念说明。",
                                icon: "book.closed",
                                color: Color.teal
                            ) {
                                selectedTool = "guide"
                            }

                            ToolCard(
                                title: "关于项目",
                                description: "查看版本、项目说明、免责声明和更新日志。",
                                icon: "info.circle",
                                color: Color.gray
                            ) {
                                selectedTool = "about"
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: Binding(
                get: { selectedTool.map { ToolItem(id: $0) } },
                set: { selectedTool = $0?.id }
            )) { tool in
                toolSheet(for: tool.id)
            }
        }
    }
    
    @ViewBuilder
    private func toolSheet(for tool: String) -> some View {
        switch tool {
        case "vfo":
            VFOEditorSheet()
        case "dtmf":
            DTMFEditorSheet()
        case "fm":
            FMEditorSheet()
        case "boot":
            BootLogoEditorSheet()
        case "backup":
            BackupManagerSheet()
        case "logs":
            LogViewerSheet()
        case "guide":
            GuideScreen()
        case "about":
            AboutScreen()
        default:
            EmptyView()
        }
    }
}

private struct ToolItem: Identifiable {
    let id: String
}

private struct MoreHeroCard: View {
    @EnvironmentObject private var store: RadioStore

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.14))
                            .frame(width: 58, height: 58)
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("更多工具")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("把不常用但关键的高级写频、快照和诊断入口集中到一处。")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    StatusBadge(
                        title: store.linkState.isConnected ? "蓝牙在线" : "未连接",
                        isPositive: store.linkState.isConnected,
                        icon: store.linkState.isConnected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right.slash"
                    )

                    Text(store.progressNote)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct MoreStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(AppTheme.cardShadow())
    }
}

private struct MoreProtocolCard: View {
    @EnvironmentObject private var store: RadioStore
    @State private var appeared = false

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .symbolEffect(.variableColor.iterative, options: .repeating, value: appeared)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("网页同款蓝牙链路")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("iOS 写频已切到 4 字节头 + 两段 64 字节数据 + ACK 的流式协议，并保留读频拿到的原始块。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    MoreProtocolChip(title: "raw \(store.data.rawBlocks?.count ?? 0)", icon: "shippingbox")
                    MoreProtocolChip(title: "区域名保护", icon: "rectangle.3.group")
                    MoreProtocolChip(title: "污染过滤", icon: "shield.checkered")
                }
            }
        }
        .onAppear { appeared = true }
    }
}

private struct MoreProtocolChip: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(AppTheme.primary.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct MoreToolSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 2)

            VStack(spacing: 12) {
                content
            }
        }
    }
}
// MARK: - Guide Screen
private struct GuideScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("核心概念", systemImage: "lightbulb.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(DemoData.guideConcepts, id: \.0) { concept in
                                        ConceptCard(title: concept.0, text: concept.1)
                                    }
                                }
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("功能导览", systemImage: "map.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(DemoData.featureCards, id: \.0) { feature in
                                        FeatureCard(title: feature.0, text: feature.1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("教程")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - About Screen
private struct AboutScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 64, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.primary, AppTheme.primaryLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(spacing: 6) {
                                Text("8800Pro Mobile")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("版本 0.5")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("制作：BG7OWW")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("项目说明")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("原生 iOS 版 8800Pro 写频控制台。采用 SwiftUI 构建，提供流畅的移动端信道管理与配置体验。")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("免责声明")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("本工具仅供学习交流，使用前请确保持有业余无线电操作证书并遵守当地法规。不当配置可能导致设备异常，请先做好备份。")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("更新日志", systemImage: "clock.arrow.circlepath")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                }
                                
                                VStack(spacing: 14) {
                                    ForEach(DemoData.updateLogs, id: \.version) { log in
                                        ChangelogCard(log: log)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Reusable Components

private struct ModernCard<Content: View>: View {
    let content: Content
    @State private var appeared = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(AppTheme.cardShadow())
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: appeared)
            .onAppear { appeared = true }
    }
}

private struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .shadow(color: AppTheme.primary.opacity(configuration.isPressed ? 0.12 : 0), radius: configuration.isPressed ? 14 : 0, x: 0, y: 8)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct NoticeBanner: View {
    let notice: NoticeMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
            
            Text(notice.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
            
            Spacer()
        }
        .padding(14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var iconName: String {
        switch notice.tone {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .neutral: return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch notice.tone {
        case .success: return AppTheme.success
        case .warning: return AppTheme.warning
        case .neutral: return AppTheme.primary
        }
    }
    
    private var backgroundColor: Color {
        switch notice.tone {
        case .success: return AppTheme.success.opacity(0.12)
        case .warning: return AppTheme.warning.opacity(0.12)
        case .neutral: return AppTheme.primary.opacity(0.12)
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .symbolEffect(.bounce, value: isPositive)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(isPositive ? AppTheme.success : AppTheme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            (isPositive ? AppTheme.success : AppTheme.textTertiary)
                .opacity(0.15)
        )
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isPositive)
    }
}

private struct PrimaryButton: View {
    let title: String
    let icon: String
    var isCompact: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                Text(title)
                    .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 12 : 14)
            .background(
                LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primary.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(AppTheme.buttonShadow())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct SecondaryButton: View {
    let title: String
    let icon: String
    var isCompact: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                Text(title)
                    .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
            }
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 12 : 14)
            .background(AppTheme.primaryLight.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, value: appeared)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(AppTheme.cardShadow())
        .offset(y: appeared ? 0 : 12)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: appeared)
        .onAppear { appeared = true }
    }
}

private struct FlowStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.primary)
                .clipShape(Circle())
                .shadow(color: AppTheme.primary.opacity(0.22), radius: 8, x: 0, y: 4)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer()
        }
    }
}

private struct CompactChannelRow: View {
    let channel: Channel
    
    var body: some View {
        HStack(spacing: 12) {
            Text("CH-\(channel.id)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name.isEmpty ? "未命名" : channel.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(channel.rxFreq) MHz")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
// MARK: - More Components

private struct BankChip: View {
    let index: Int
    let name: String
    let activeCount: Int
    let isSelected: Bool
    let selectAction: () -> Void
    let editAction: () -> Void
    
    var body: some View {
        Button(action: selectAction) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.72) : AppTheme.textTertiary)

                    Text(name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Text("\(activeCount) 条")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.76) : AppTheme.textSecondary)
            }
                .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(minWidth: 92, alignment: .leading)
                .background(
                    isSelected ?
                    AnyView(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) :
                    AnyView(AppTheme.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(
                    color: isSelected ? AppTheme.primary.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isSelected ? 6 : 2,
                    x: 0,
                    y: isSelected ? 3 : 1
                )
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in editAction() }
        )
        .contextMenu {
            Button {
                editAction()
            } label: {
                Label("编辑区域名称", systemImage: "pencil")
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct ChannelCard: View {
    let channel: Channel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CH-\(channel.id)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("\(channel.id)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primary)
                }
                .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(channel.name.isEmpty ? "未命名信道" : channel.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Label(channel.rxFreq.isEmpty ? "—" : channel.rxFreq, systemImage: "arrow.down.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        if !channel.txFreq.isEmpty && channel.txFreq != channel.rxFreq {
                            Label(channel.txFreq, systemImage: "arrow.up.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    
                    if channel.txTone != "OFF" || channel.rxTone != "OFF" {
                        HStack(spacing: 6) {
                            if channel.txTone != "OFF" {
                                Text("TX: \(channel.txTone)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            if channel.rxTone != "OFF" {
                                Text("RX: \(channel.rxTone)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.success.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .background(AppTheme.cardShadow())
        }
        .buttonStyle(PressableCardStyle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct NewChannelCard: View {
    let title: String
    let subtitle: String
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: isCompact ? 46 : 54, height: isCompact ? 46 : 54)

                    Image(systemName: "plus")
                        .font(.system(size: isCompact ? 19 : 23, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(isCompact ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(isCompact ? 15 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            )
            .background(AppTheme.cardShadow())
        }
        .buttonStyle(PressableCardStyle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct SettingsHeroCard: View {
    let functions: RadioFunctionSettings
    let linkTitle: String

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)

                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("整机功能控制")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("这些设置会跟随读频数据保存，并在写频时回写到 0x9000 功能块。")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                    SettingsMetricPill(title: "连接", value: linkTitle, icon: "dot.radiowaves.left.and.right", color: AppTheme.primary)
                    SettingsMetricPill(title: "双守", value: RadioChoices.onOff[safe: functions.dualStandby] ?? "未知", icon: "arrow.triangle.2.circlepath", color: .green)
                    SettingsMetricPill(title: "A 显示", value: RadioChoices.displayMode[safe: functions.chADisplay] ?? "未知", icon: "a.square", color: .blue)
                    SettingsMetricPill(title: "蓝牙音频", value: "\(functions.bluetoothAudioGain)", icon: "headphones", color: .cyan)
                }
            }
        }
    }
}

private struct SettingsMetricPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsSaveCard: View {
    let action: () -> Void

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.success)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存功能设置")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("这里的保存只更新当前配置。要传输到机器，请回到总览页面点击写频。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)
                    }
                }

                PrimaryButton(title: "保存", icon: "checkmark.circle.fill", action: action)
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 38, height: 38)
                        .background(color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 0)
                }
                
                content
            }
        }
    }
}

private struct SettingsGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 265), spacing: 12)], spacing: 12) {
            content
        }
    }
}

private struct SettingMenuControl: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        SettingControlShell(title: title, subtitle: subtitle, icon: icon, color: color) {
            Picker(title, selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(color)
            .frame(minWidth: 92, alignment: .trailing)
        }
    }
}

private struct SettingSegmentedControl: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        SettingControlShell(title: title, subtitle: subtitle, icon: icon, color: color, controlAlignment: .bottom) {
            Picker(title, selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

private struct SettingControlShell<Control: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var controlAlignment: VerticalAlignment = .center
    let control: Control

    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        controlAlignment: VerticalAlignment = .center,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.controlAlignment = controlAlignment
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: controlAlignment, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                control
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.18), lineWidth: 0.8)
        )
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            
            content
        }
        .padding(12)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
    }
}

private struct ToolCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    var status: String?
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var appeared = false
    
    var body: some View {
        Button(action: isDisabled ? {} : action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(displayColor.opacity(isDisabled ? 0.10 : 0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(displayColor)
                        .symbolEffect(.pulse, value: appeared)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isDisabled ? AppTheme.textSecondary : AppTheme.textPrimary)

                        if let status {
                            Text(status)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.textTertiary.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isDisabled ? "lock.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(18)
            .background(isDisabled ? AppTheme.fieldBackground : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(AppTheme.cardShadow())
        }
        .disabled(isDisabled)
        .buttonStyle(PressableCardStyle())
        .offset(y: appeared ? 0 : 12)
        .opacity(appeared ? (isDisabled ? 0.72 : 1) : 0)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: appeared)
        .onAppear { appeared = true }
    }

    private var displayColor: Color {
        isDisabled ? AppTheme.textTertiary : color
    }
}

private struct MoreToolSaveFooter: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: "保存", icon: "checkmark.circle.fill", action: action)

            Text("要传输到机器，请回到总览页面点击写频。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 2)
    }
}

private struct ConceptCard: View {
    let title: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct FeatureCard: View {
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)
            }
            
            Spacer()
        }
        .padding(14)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

private struct ChangelogCard: View {
    let log: ChangelogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(log.version)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.12))
                    .clipShape(Capsule())
                
                Text(log.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
            }
            
            Text(log.detail)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Sheet Placeholders
private struct ChannelEditorSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard

                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SheetSectionHeader(title: "频率配置", icon: "waveform")

                                VStack(spacing: 12) {
                                    ChannelFrequencyField(title: "接收频率", placeholder: "145.62500", value: Binding(
                                        get: { store.currentChannel.rxFreq },
                                        set: { newValue in store.updateCurrentChannel { $0.rxFreq = sanitizeRadioFrequencyDraft(newValue) } }
                                    ))

                                    Divider()

                                    ChannelFrequencyField(title: "发射频率", placeholder: "145.62500", value: Binding(
                                        get: { store.currentChannel.txFreq },
                                        set: { newValue in store.updateCurrentChannel { $0.txFreq = sanitizeRadioFrequencyDraft(newValue) } }
                                    ))
                                }
                            }
                        }

                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SheetSectionHeader(title: "亚音与信令", icon: "dot.radiowaves.left.and.right")

                                VStack(spacing: 12) {
                                    ChannelPickerRow(title: "接收亚音", selection: Binding(
                                        get: { store.currentChannel.rxTone },
                                        set: { newValue in store.updateCurrentChannel { $0.rxTone = newValue } }
                                    ), options: ToneLibrary.ctcss)

                                    Divider()

                                    ChannelPickerRow(title: "发射亚音", selection: Binding(
                                        get: { store.currentChannel.txTone },
                                        set: { newValue in store.updateCurrentChannel { $0.txTone = newValue } }
                                    ), options: ToneLibrary.ctcss)

                                    Divider()

                                    Stepper(value: Binding(
                                        get: { store.currentChannel.signalGroup },
                                        set: { newValue in store.updateCurrentChannel { $0.signalGroup = max(0, min(19, newValue)) } }
                                    ), in: 0...19) {
                                        RowTitleValue(title: "信令组", value: "\(store.currentChannel.signalGroup)")
                                    }
                                }
                            }
                        }

                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SheetSectionHeader(title: "信道参数", icon: "slider.horizontal.3")

                                VStack(spacing: 12) {
                                    IndexedPickerRow(title: "发射功率", value: Binding(
                                        get: { store.currentChannel.txPower },
                                        set: { newValue in store.updateCurrentChannel { $0.txPower = newValue } }
                                    ), options: RadioChoices.power)

                                    Divider()

                                    IndexedPickerRow(title: "带宽", value: Binding(
                                        get: { store.currentChannel.bandwidth },
                                        set: { newValue in store.updateCurrentChannel { $0.bandwidth = newValue } }
                                    ), options: RadioChoices.bandwidth)

                                    Divider()

                                    IndexedPickerRow(title: "PTT-ID", value: Binding(
                                        get: { store.currentChannel.pttID },
                                        set: { newValue in store.updateCurrentChannel { $0.pttID = newValue } }
                                    ), options: RadioChoices.pttID)

                                    Divider()

                                    ToggleRow(title: "加入扫描", value: Binding(
                                        get: { store.currentChannel.scanAdd == 1 },
                                        set: { newValue in store.updateCurrentChannel { $0.scanAdd = newValue ? 1 : 0 } }
                                    ))

                                    Divider()

                                    ToggleRow(title: "繁忙锁定", value: Binding(
                                        get: { store.currentChannel.busyLock == 1 },
                                        set: { newValue in store.updateCurrentChannel { $0.busyLock = newValue ? 1 : 0 } }
                                    ))
                                }
                            }
                        }

                        ModernCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SheetSectionHeader(title: "信道管理", icon: "square.on.square")

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    SecondaryActionButton(title: "复制", icon: "doc.on.doc") { store.copyCurrentChannel() }
                                    SecondaryActionButton(title: "剪切", icon: "scissors") { store.cutCurrentChannel() }
                                    SecondaryActionButton(title: "粘贴", icon: "doc.on.clipboard") { store.pasteToCurrentChannel() }
                                    SecondaryActionButton(title: "插入空信道", icon: "plus.rectangle.on.rectangle") { store.insertEmptyChannelAfterSelection() }
                                    SecondaryActionButton(title: "删除上移", icon: "trash") { store.deleteCurrentChannelAndShift() }
                                    SecondaryActionButton(title: "整理本区域", icon: "arrow.up.arrow.down.square") { store.compactCurrentBank() }
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            PrimaryButton(title: "保存修改", icon: "checkmark.circle.fill") {
                                dismiss()
                            }
                            
                            Button("清空此信道") {
                                store.clearCurrentChannel()
                                dismiss()
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("编辑信道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerCard: some View {
        ModernCard {
            VStack(spacing: 12) {
                Text("CH-\(store.currentChannel.id)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("信道名称", text: Binding(
                    get: { store.currentChannel.name },
                    set: { newValue in store.updateCurrentChannel { $0.name = String(newValue.prefix(12)) } }
                ))
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
            }
        }
        .padding(.top, 12)
    }
}

private struct RepeaterImportSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRegion = ""
    @State private var selectedProvinceCode: Int?
    @State private var selectedCityCode: Int?
    @State private var searchText = ""

    private var activeRegions: [RepeaterRegionGroup] {
        if !store.repeaterRegions.isEmpty {
            return store.repeaterRegions
        }
        let labels = Array(Set(store.repeaterLibrary.map(\.region))).sorted()
        return labels.map { label in
            RepeaterRegionGroup(label: label, children: [])
        }
    }

    private var activeProvinceGroups: [RepeaterProvinceGroup] {
        if let region = activeRegions.first(where: { $0.label == selectedRegion }), !region.children.isEmpty {
            return region.children
        }
        let entries = store.repeaterLibrary.filter { selectedRegion.isEmpty || $0.region == selectedRegion }
        let grouped = Dictionary(grouping: entries, by: \.provinceCode)
        return grouped.values.compactMap { items in
            guard let first = items.first else { return nil }
            return RepeaterProvinceGroup(
                name: first.province,
                code: first.provinceCode,
                analogTotal: items.filter { $0.kind.contains("模拟") || $0.kind.contains("混合") }.count,
                digiTotal: items.filter { $0.kind.contains("数字") }.count,
                municipality: nil
            )
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var activeCities: [(code: Int, name: String, count: Int)] {
        let entries = filteredByArea(includeCity: false)
        let grouped = Dictionary(grouping: entries, by: \.cityCode)
        return grouped.values.compactMap { items in
            guard let first = items.first else { return nil }
            return (first.cityCode, first.city, items.count)
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var visibleRepeaters: [RepeaterEntry] {
        var entries = filteredByArea(includeCity: true)
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !keyword.isEmpty {
            entries = entries.filter {
                "\($0.name) \($0.callSign ?? "") \($0.rxFreq) \($0.txFreq) \($0.province) \($0.city) \($0.remark ?? "")"
                    .lowercased()
                    .contains(keyword)
            }
        }
        return entries
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SheetSectionHeader(title: "HamCQ 中继台库", icon: "antenna.radiowaves.left.and.right")

                                Text(store.repeaterLibraryStatus)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)

                                SearchField(text: $searchText, placeholder: "搜索中继名、城市、频率")
                            }
                        }

                        if store.repeaterLibrary.isEmpty {
                            ProgressView("正在加载中继台库")
                                .padding(.top, 40)
                        } else {
                            regionSelector
                            provinceSelector
                            citySelector
                            repeaterList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("中继台库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await store.loadRepeaterLibraryIfNeeded()
                if selectedRegion.isEmpty {
                    selectedRegion = activeRegions.first?.label ?? ""
                }
                if selectedProvinceCode == nil {
                    selectedProvinceCode = activeProvinceGroups.first?.code
                }
            }
        }
    }

    private var regionSelector: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                SheetSectionHeader(title: "大区", icon: "map")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeRegions) { region in
                            SelectionChip(title: region.label, subtitle: nil, isSelected: selectedRegion == region.label) {
                                selectedRegion = region.label
                                selectedProvinceCode = region.children.first?.code
                                selectedCityCode = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var provinceSelector: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                SheetSectionHeader(title: "省份", icon: "mappin.and.ellipse")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(activeProvinceGroups) { province in
                        SelectionChip(
                            title: province.name,
                            subtitle: "模 \(province.analogTotal) / 数 \(province.digiTotal)",
                            isSelected: selectedProvinceCode == province.code
                        ) {
                            selectedProvinceCode = province.code
                            selectedCityCode = nil
                        }
                    }
                }
            }
        }
    }

    private var citySelector: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                SheetSectionHeader(title: "城市", icon: "building.2")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SelectionChip(title: "全部", subtitle: "\(filteredByArea(includeCity: false).count) 条", isSelected: selectedCityCode == nil) {
                            selectedCityCode = nil
                        }
                        ForEach(activeCities, id: \.code) { city in
                            SelectionChip(title: city.name, subtitle: "\(city.count) 条", isSelected: selectedCityCode == city.code) {
                                selectedCityCode = city.code
                            }
                        }
                    }
                }
            }
        }
    }

    private var repeaterList: some View {
        LazyVStack(spacing: 10) {
            if visibleRepeaters.isEmpty {
                Text("没有匹配的中继台")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 28)
            } else {
                ForEach(visibleRepeaters) { repeater in
                    Button {
                        store.applyRepeater(repeater)
                        dismiss()
                    } label: {
                        RepeaterRow(repeater: repeater)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    private func filteredByArea(includeCity: Bool) -> [RepeaterEntry] {
        store.repeaterLibrary.filter { entry in
            (selectedRegion.isEmpty || entry.region == selectedRegion) &&
                (selectedProvinceCode == nil || entry.provinceCode == selectedProvinceCode) &&
                (!includeCity || selectedCityCode == nil || entry.cityCode == selectedCityCode)
        }
    }
}

private struct RepeaterRow: View {
    let repeater: RepeaterEntry
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(repeater.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 8) {
                    Text(repeater.locationText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("•")
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("\(repeater.rxFreq) -> \(repeater.txFreq)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: 6) {
                    if !repeater.offset.isEmpty {
                        DetailPill(text: "差频 \(repeater.offset)", color: AppTheme.primary)
                    }
                    if !repeater.toneText.isEmpty {
                        DetailPill(text: repeater.toneText, color: AppTheme.success)
                    }
                    if let mode = repeater.mode, !mode.isEmpty, mode != "0" {
                        DetailPill(text: mode, color: AppTheme.warning)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(repeater.kind)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.success)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(AppTheme.cardShadow())
    }
}

private struct SheetSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private struct ChannelFrequencyField: View {
    let title: String
    let placeholder: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
        }
    }
}

private struct ChannelPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct IndexedPickerRow: View {
    let title: String
    @Binding var value: Int
    let options: [String]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Picker(title, selection: $value) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var value: Bool

    var body: some View {
        Toggle(isOn: $value) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .tint(AppTheme.primary)
    }
}

private struct RowTitleValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(AppTheme.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }
}

private struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textTertiary)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SelectionChip: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? AppTheme.primary : AppTheme.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }
}

private struct DetailPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private func sanitizeRadioFrequencyDraft(_ value: String) -> String {
    let cleaned = value.filter { $0.isNumber || $0 == "." }
    let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
    let integer = String(parts.first ?? "").prefix(3)
    guard cleaned.contains(".") else {
        return String(integer)
    }
    let decimal = parts.dropFirst().joined().prefix(5)
    return "\(integer).\(decimal)"
}

private struct BackupManagerSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var backupToDelete: RadioSnapshot?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                if store.backups.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.backups) { backup in
                                BackupCard(backup: backup) {
                                    // Restore
                                    store.restoreBackup(backup)
                                    dismiss()
                                } onDelete: {
                                    // Delete
                                    backupToDelete = backup
                                    showDeleteConfirm = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("备份管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("新建备份") {
                        store.createBackup(title: "手动备份 \(Formatters.shortDate.string(from: .now))")
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
            .alert("删除备份", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let backup = backupToDelete {
                        store.deleteBackup(backup)
                    }
                }
            } message: {
                if let backup = backupToDelete {
                    Text("确定要删除备份「\(backup.title)」吗？此操作不可恢复。")
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.textTertiary)
            
            VStack(spacing: 8) {
                Text("暂无备份")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("读频或写频时会自动创建备份\n你也可以随时手动创建备份")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                store.createBackup(title: "手动备份 \(Formatters.shortDate.string(from: .now))")
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("创建备份")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.primary)
                .clipShape(Capsule())
            }
        }
    }
}

private struct BackupCard: View {
    let backup: RadioSnapshot
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(backup.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(Formatters.shortDate.string(from: backup.createdAt))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Menu {
                    Button {
                        onRestore()
                    } label: {
                        Label("恢复此备份", systemImage: "arrow.clockwise")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除备份", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            HStack(spacing: 16) {
                BackupStat(title: "信道", value: "\(backup.data.visibleChannelCount)")
                BackupStat(title: "分组", value: backup.data.bankNames.filter { !$0.isEmpty && $0 != "区域一" }.count > 0 ? "已配置" : "默认")
                BackupStat(title: "VFO", value: backup.data.vfos.vfoAFreq.isEmpty ? "未设置" : "已设置")
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(AppTheme.cardShadow())
    }
}

private struct BackupStat: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}


private struct LogViewerSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                if store.logs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(store.logs.enumerated()), id: \.offset) { index, log in
                                LogRow(log: log, index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("通信日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.clearLogs()
                    } label: {
                        Text("清空")
                            .foregroundStyle(AppTheme.error)
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.textTertiary)
            
            VStack(spacing: 8) {
                Text("暂无日志")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("蓝牙通信日志会显示在这里")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

private struct LogRow: View {
    let log: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("#\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 40, alignment: .leading)
            
            Text(log)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(index % 2 == 0 ? AppTheme.cardBackground : AppTheme.surfaceBackground)
    }
}


#Preview {
    ContentView()
        .environmentObject(RadioStore())
}
private struct VFOEditorSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // VFO A Section
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("VFO A", systemImage: "waveform.path")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text("频率模式")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                FrequencyInputRow(
                                    title: "频率",
                                    frequency: Binding(
                                        get: { store.data.vfos.vfoAFreq },
                                        set: { newValue in store.updateVFO { $0.vfoAFreq = newValue } }
                                    ),
                                    offset: Binding(
                                        get: { store.data.vfos.vfoAOffset },
                                        set: { newValue in store.updateVFO { $0.vfoAOffset = newValue } }
                                    )
                                )
                                
                                Divider()
                                
                                ToneSelectionRow(
                                    rxTone: Binding(
                                        get: { store.data.vfos.vfoARxTone },
                                        set: { newValue in store.updateVFO { $0.vfoARxTone = newValue } }
                                    ),
                                    txTone: Binding(
                                        get: { store.data.vfos.vfoATxTone },
                                        set: { newValue in store.updateVFO { $0.vfoATxTone = newValue } }
                                    )
                                )
                                
                                Divider()
                                
                                SettingPickerRow(
                                    title: "功率",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoATxPower },
                                        set: { newValue in store.updateVFO { $0.vfoATxPower = newValue } }
                                    ),
                                    options: RadioChoices.power
                                )
                                
                                SettingPickerRow(
                                    title: "带宽",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoABandwidth },
                                        set: { newValue in store.updateVFO { $0.vfoABandwidth = newValue } }
                                    ),
                                    options: RadioChoices.bandwidth
                                )
                                
                                SettingPickerRow(
                                    title: "步进",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoAStep },
                                        set: { newValue in store.updateVFO { $0.vfoAStep = newValue } }
                                    ),
                                    options: RadioChoices.stepOptions
                                )
                            }
                        }
                        
                        // VFO B Section
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("VFO B", systemImage: "waveform.path")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text("频率模式")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                FrequencyInputRow(
                                    title: "频率",
                                    frequency: Binding(
                                        get: { store.data.vfos.vfoBFreq },
                                        set: { newValue in store.updateVFO { $0.vfoBFreq = newValue } }
                                    ),
                                    offset: Binding(
                                        get: { store.data.vfos.vfoBOffset },
                                        set: { newValue in store.updateVFO { $0.vfoBOffset = newValue } }
                                    )
                                )
                                
                                Divider()
                                
                                ToneSelectionRow(
                                    rxTone: Binding(
                                        get: { store.data.vfos.vfoBRxTone },
                                        set: { newValue in store.updateVFO { $0.vfoBRxTone = newValue } }
                                    ),
                                    txTone: Binding(
                                        get: { store.data.vfos.vfoBTxTone },
                                        set: { newValue in store.updateVFO { $0.vfoBTxTone = newValue } }
                                    )
                                )
                                
                                Divider()
                                
                                SettingPickerRow(
                                    title: "功率",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoBTxPower },
                                        set: { newValue in store.updateVFO { $0.vfoBTxPower = newValue } }
                                    ),
                                    options: RadioChoices.power
                                )
                                
                                SettingPickerRow(
                                    title: "带宽",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoBBandwidth },
                                        set: { newValue in store.updateVFO { $0.vfoBBandwidth = newValue } }
                                    ),
                                    options: RadioChoices.bandwidth
                                )
                                
                                SettingPickerRow(
                                    title: "步进",
                                    selection: Binding(
                                        get: { store.data.vfos.vfoBStep },
                                        set: { newValue in store.updateVFO { $0.vfoBStep = newValue } }
                                    ),
                                    options: RadioChoices.stepOptions
                                )
                            }
                        }
                        
                        MoreToolSaveFooter {
                            store.showSuccess("VFO 设置已保存到本地配置。要传输到机器，请回到总览页面写频。")
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("VFO 频率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FrequencyInputRow: View {
    let title: String
    @Binding var frequency: String
    @Binding var offset: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("频率 (MHz)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("145.62500", text: $frequency)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .padding(10)
                        .background(AppTheme.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("频差")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("00.0000", text: $offset)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .padding(10)
                        .background(AppTheme.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct ToneSelectionRow: View {
    @Binding var rxTone: String
    @Binding var txTone: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("亚音设置")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("接收亚音")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    Picker("RX", selection: $rxTone) {
                        ForEach(ToneLibrary.ctcss, id: \.self) { tone in
                            Text(tone).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(AppTheme.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("发射亚音")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    Picker("TX", selection: $txTone) {
                        ForEach(ToneLibrary.ctcss, id: \.self) { tone in
                            Text(tone).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(AppTheme.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct SettingPickerRow: View {
    let title: String
    @Binding var selection: Int
    let options: [String]
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 14))
        }
    }
}
private struct DTMFEditorSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Basic Settings
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("基本设置", systemImage: "number.square")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                DTMFInputRow(
                                    title: "本机 ID",
                                    value: Binding(
                                        get: { store.data.dtmf.localID },
                                        set: { newValue in store.updateDTMF { $0.localID = String(newValue.prefix(3)) } }
                                    ),
                                    placeholder: "100"
                                )
                                
                                Divider()
                                
                                HStack {
                                    Text("PTT ID")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("PTT ID", selection: Binding(
                                        get: { store.data.dtmf.pttID },
                                        set: { newValue in store.updateDTMF { $0.pttID = newValue } }
                                    )) {
                                        ForEach(Array(RadioChoices.pttID.enumerated()), id: \.offset) { index, option in
                                            Text(option).tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("按键时长")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("按键时长", selection: Binding(
                                        get: { store.data.dtmf.wordTime },
                                        set: { newValue in store.updateDTMF { $0.wordTime = newValue } }
                                    )) {
                                        ForEach(0..<10) { i in
                                            Text("\(i * 100 + 100) ms").tag(i)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                HStack {
                                    Text("间隔时长")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("间隔时长", selection: Binding(
                                        get: { store.data.dtmf.idleTime },
                                        set: { newValue in store.updateDTMF { $0.idleTime = newValue } }
                                    )) {
                                        ForEach(0..<10) { i in
                                            Text("\(i * 100 + 100) ms").tag(i)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        
                        // Group List
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("组呼列表", systemImage: "person.3")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text("15 组")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(0..<15, id: \.self) { index in
                                        DTMFGroupRow(
                                            index: index,
                                            name: Binding(
                                                get: { store.data.dtmf.groupNames[index] },
                                                set: { newValue in
                                                    store.updateDTMF { dtmf in
                                                        dtmf.groupNames[index] = String(newValue.prefix(12))
                                                    }
                                                }
                                            ),
                                            code: Binding(
                                                get: { store.data.dtmf.groups[index] },
                                                set: { newValue in
                                                    store.updateDTMF { dtmf in
                                                        dtmf.groups[index] = String(newValue.prefix(16))
                                                    }
                                                }
                                            )
                                        )
                                        
                                        if index < 14 {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                        
                        MoreToolSaveFooter {
                            store.showSuccess("DTMF 设置已保存到本地配置。要传输到机器，请回到总览页面写频。")
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("DTMF 编码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct DTMFInputRow: View {
    let title: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            
            TextField(placeholder, text: $value)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .padding(12)
                .background(AppTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct DTMFGroupRow: View {
    let index: Int
    @Binding var name: String
    @Binding var code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("组 \(index + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 50, alignment: .leading)
                
                TextField("名称", text: $name)
                    .font(.system(size: 14))
                    .padding(8)
                    .background(AppTheme.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            TextField("DTMF 编码（最多 16 位）", text: $code)
                .keyboardType(.numberPad)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .background(AppTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
private struct FMEditorSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    @State private var frequencyDraft = ""
    @State private var selectedMemoryIndex: Int?
    @FocusState private var isFrequencyFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Frequency
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("当前频率", systemImage: "radio")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                HStack {
                                    Text("FM 频率")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    
                                    Spacer()
                                    
                                    TextField("90.4", text: $frequencyDraft)
                                        .keyboardType(.decimalPad)
                                        .focused($isFrequencyFocused)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                                        .frame(width: 112)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(AppTheme.surfaceBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .onSubmit {
                                            applyFrequencyDraft()
                                        }
                                        .onChange(of: isFrequencyFocused) { _, focused in
                                            if focused {
                                                frequencyDraft = fmDisplayFrequency
                                            } else {
                                                applyFrequencyDraft()
                                            }
                                        }
                                }
                                
                                HStack(spacing: 10) {
                                    Text("范围: 76.0 - 108.0 MHz")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textTertiary)

                                    Spacer()

                                    Button {
                                        applyFrequencyDraft()
                                        isFrequencyFocused = false
                                    } label: {
                                        Text("应用")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.primary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        store.updateFM { fm in
                                            fm.currentFreq = max(760, fm.currentFreq - 1)
                                        }
                                        frequencyDraft = fmDisplayFrequency
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        Text(fmDisplayFrequency)
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppTheme.primary)
                                        Text("收音机")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        store.updateFM { fm in
                                            fm.currentFreq = min(1080, fm.currentFreq + 1)
                                        }
                                        frequencyDraft = fmDisplayFrequency
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                            }
                        }
                        
                        // Memory Channels
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("记忆频道", systemImage: "bookmark.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text("30 个")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(0..<30, id: \.self) { index in
                                        FMChannelButton(
                                            index: index,
                                            frequency: store.data.fm.channels[index],
                                            isSelected: false
                                        ) {
                                            if store.data.fm.channels[index] == 0 {
                                                store.updateFM { fm in
                                                    fm.channels[index] = fm.currentFreq
                                                }
                                            } else {
                                                selectedMemoryIndex = index
                                            }
                                            frequencyDraft = fmDisplayFrequency
                                        } onLongPress: {
                                            store.updateFM { fm in
                                                fm.channels[index] = 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Instructions
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("使用说明", systemImage: "info.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    InstructionRow(icon: "1.circle.fill", text: "可直接输入 90.4 这样的 MHz 频率")
                                    InstructionRow(icon: "2.circle.fill", text: "点击 ＋/－ 按 0.1 MHz 微调")
                                    InstructionRow(icon: "3.circle.fill", text: "点击空白记忆位保存当前频率")
                                    InstructionRow(icon: "4.circle.fill", text: "点击已有记忆位可加载、覆盖或删除")
                                }
                            }
                        }
                        
                        MoreToolSaveFooter {
                            applyFrequencyDraft()
                            store.showSuccess("FM 收音设置已保存到本地配置。要传输到机器，请回到总览页面写频。")
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("FM 收音")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                selectedMemoryTitle,
                isPresented: Binding(
                    get: { selectedMemoryIndex != nil },
                    set: { if !$0 { selectedMemoryIndex = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("加载到当前频率") {
                    loadSelectedMemory()
                }
                Button("用当前频率覆盖") {
                    overwriteSelectedMemory()
                }
                Button("删除记忆位", role: .destructive) {
                    deleteSelectedMemory()
                }
                Button("取消", role: .cancel) {
                    selectedMemoryIndex = nil
                }
            } message: {
                Text("空记忆位会直接保存当前频率；已有记忆位可以在这里管理。")
            }
            .onAppear {
                frequencyDraft = fmDisplayFrequency
            }
            .onChange(of: store.data.fm.currentFreq) { _, _ in
                if !isFrequencyFocused {
                    frequencyDraft = fmDisplayFrequency
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        applyFrequencyDraft()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var fmDisplayFrequency: String {
        let freq = store.data.fm.currentFreq
        let mhz = Double(freq) / 10.0
        return String(format: "%.1f", mhz)
    }

    private var selectedMemoryTitle: String {
        guard let selectedMemoryIndex, store.data.fm.channels.indices.contains(selectedMemoryIndex) else {
            return "记忆位"
        }
        let frequency = Double(store.data.fm.channels[selectedMemoryIndex]) / 10.0
        return "M\(selectedMemoryIndex + 1) · \(String(format: "%.1f", frequency)) MHz"
    }

    private func applyFrequencyDraft() {
        guard let value = parseFMFrequency(frequencyDraft) else {
            frequencyDraft = fmDisplayFrequency
            return
        }
        store.updateFM { fm in
            fm.currentFreq = value
        }
        frequencyDraft = String(format: "%.1f", Double(value) / 10.0)
    }

    private func loadSelectedMemory() {
        guard let selectedMemoryIndex, store.data.fm.channels.indices.contains(selectedMemoryIndex) else { return }
        let value = store.data.fm.channels[selectedMemoryIndex]
        guard value > 0 else { return }
        store.updateFM { fm in
            fm.currentFreq = value
        }
        frequencyDraft = String(format: "%.1f", Double(value) / 10.0)
        self.selectedMemoryIndex = nil
    }

    private func overwriteSelectedMemory() {
        guard let selectedMemoryIndex, store.data.fm.channels.indices.contains(selectedMemoryIndex) else { return }
        store.updateFM { fm in
            fm.channels[selectedMemoryIndex] = fm.currentFreq
        }
        self.selectedMemoryIndex = nil
    }

    private func deleteSelectedMemory() {
        guard let selectedMemoryIndex, store.data.fm.channels.indices.contains(selectedMemoryIndex) else { return }
        store.updateFM { fm in
            fm.channels[selectedMemoryIndex] = 0
        }
        self.selectedMemoryIndex = nil
    }

    private func parseFMFrequency(_ text: String) -> Int? {
        let normalized = text
            .replacingOccurrences(of: "ＭＨＺ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "MHZ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "MHz", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mhz = Double(normalized), (76.0...108.0).contains(mhz) else {
            return nil
        }
        return max(760, min(1080, Int((mhz * 10).rounded())))
    }
}

private struct FMChannelButton: View {
    let index: Int
    let frequency: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("M\(index + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(frequency > 0 ? AppTheme.primary : AppTheme.textTertiary)
                
                if frequency > 0 {
                    Text(String(format: "%.1f", Double(frequency) / 10.0))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(frequency > 0 ? AppTheme.primary.opacity(0.1) : AppTheme.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(frequency > 0 ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
}

private struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
private struct BootLogoEditorSheet: View {
    @EnvironmentObject private var store: RadioStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Logo Preview
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("当前开机图", systemImage: "photo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                if let logoData = store.data.bootLogo, !logoData.isEmpty {
                                    if let uiImage = createImageFromData(logoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .interpolation(.none)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                            .background(Color.black)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        emptyLogoPlaceholder
                                    }
                                } else {
                                    emptyLogoPlaceholder
                                }
                                
                                Text("尺寸: 128×128 像素 • RGB565 彩色")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        
                        // Image Selection
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("选择图片", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                if let selectedImage = selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Text("已选择图片 • 将自动转换为 128×128 RGB565")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.success)
                                } else {
                                    Text("从相册选择图片，将自动转换为对讲机开机图格式")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 20)
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    SecondaryButton(title: "选择图片", icon: "photo.on.rectangle") {
                                        showImagePicker = true
                                    }
                                    
                                    if selectedImage != nil {
                                        SecondaryButton(title: "应用", icon: "checkmark") {
                                            applySelectedImage()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Presets
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("预设图案", systemImage: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    PresetLogoButton(title: "呼号", icon: "antenna.radiowaves.left.and.right") {
                                        applyCallsignLogo()
                                    }
                                    
                                    PresetLogoButton(title: "经典", icon: "square.grid.2x2") {
                                        applyClassicLogo()
                                    }
                                    
                                    PresetLogoButton(title: "清空", icon: "clear") {
                                        clearLogo()
                                    }
                                    
                                    PresetLogoButton(title: "默认", icon: "arrow.counterclockwise") {
                                        resetToDefault()
                                    }
                                }
                            }
                        }
                        
                        // Instructions
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("使用说明", systemImage: "info.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    InstructionRow(icon: "1.circle.fill", text: "点击「选择图片」从相册选择")
                                    InstructionRow(icon: "2.circle.fill", text: "图片将自动裁切为 128×128 RGB565")
                                    InstructionRow(icon: "3.circle.fill", text: "点击「应用」确认使用此图片")
                                    InstructionRow(icon: "4.circle.fill", text: "点击「保存并写入开机图」写入对讲机")
                                }
                            }
                        }
                        
                        // Save Button
                        if isProcessing {
                            HStack {
                                ProgressView()
                                Text("处理中...")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            Button {
                                store.writeBootLogo()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "hammer.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("写入开机图开发中")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.textTertiary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("开机图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private var emptyLogoPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            
            Text("未设置开机图")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func applySelectedImage() {
        guard let image = selectedImage else { return }
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let logoData = convertImageToLogoData(image)
            
            DispatchQueue.main.async {
                store.updateBootLogo(logoData)
                selectedImage = nil
                isProcessing = false
                store.showSuccess("开机图已更新")
            }
        }
    }
    
    private func applyCallsignLogo() {
        let callsign = store.data.functions.callSign.isEmpty ? "8800PRO" : store.data.functions.callSign
        let logoData = generateCallsignLogo(callsign)
        store.updateBootLogo(logoData)
        store.showSuccess("已应用呼号图案")
    }
    
    private func applyClassicLogo() {
        let logoData = generateClassicLogo()
        store.updateBootLogo(logoData)
        store.showSuccess("已应用经典图案")
    }
    
    private func clearLogo() {
        store.updateBootLogo(Data(repeating: 0x00, count: SHX8800PRO.bootImageBytes))
        store.showSuccess("开机图已清空")
    }
    
    private func resetToDefault() {
        store.updateBootLogo(nil)
        store.showSuccess("已恢复默认")
    }
    
    // MARK: - Image Processing
    
    private func convertImageToLogoData(_ image: UIImage) -> Data {
        guard let rgba = renderRGBA(image) else {
            return Data(repeating: 0x00, count: SHX8800PRO.bootImageBytes)
        }
        return rgb565Data(fromRGBA: rgba)
    }
    
    private func createImageFromData(_ data: Data) -> UIImage? {
        guard data.count >= SHX8800PRO.bootImageBytes else { return nil }

        let width = SHX8800PRO.bootImageWidth
        let height = SHX8800PRO.bootImageHeight
        var pixels = [UInt8](repeating: 255, count: width * height * 4)

        for index in 0..<(width * height) {
            let low = UInt16(data[index * 2])
            let high = UInt16(data[index * 2 + 1])
            let value = (high << 8) | low
            let red = UInt8(((value >> 11) & 0x1F) * 255 / 31)
            let green = UInt8(((value >> 5) & 0x3F) * 255 / 63)
            let blue = UInt8((value & 0x1F) * 255 / 31)
            pixels[index * 4] = red
            pixels[index * 4 + 1] = green
            pixels[index * 4 + 2] = blue
            pixels[index * 4 + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func generateCallsignLogo(_ callsign: String) -> Data {
        let image = renderPresetImage { context, rect in
            let cg = context.cgContext
            let background = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.0, green: 0.10, blue: 0.12, alpha: 1).cgColor,
                    UIColor(red: 0.0, green: 0.58, blue: 0.52, alpha: 1).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
            if let background {
                cg.drawLinearGradient(background, start: CGPoint(x: 0, y: 0), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            }

            UIColor.white.withAlphaComponent(0.18).setStroke()
            cg.setLineWidth(2)
            for offset in stride(from: -64, through: 160, by: 18) {
                cg.move(to: CGPoint(x: offset, y: 0))
                cg.addLine(to: CGPoint(x: offset + 80, y: 128))
            }
            cg.strokePath()

            drawCenteredText(
                String(callsign.prefix(12)),
                in: CGRect(x: 10, y: 42, width: 108, height: 34),
                font: .systemFont(ofSize: 21, weight: .heavy),
                color: .white
            )
            drawCenteredText(
                "SHX 8800PRO",
                in: CGRect(x: 8, y: 82, width: 112, height: 18),
                font: .monospacedSystemFont(ofSize: 10, weight: .semibold),
                color: UIColor.white.withAlphaComponent(0.86)
            )
        }
        return convertImageToLogoData(image)
    }
    
    private func generateClassicLogo() -> Data {
        let image = renderPresetImage { context, rect in
            let cg = context.cgContext
            UIColor.black.setFill()
            cg.fill(rect)

            UIColor(red: 0.0, green: 0.72, blue: 0.65, alpha: 1).setStroke()
            cg.setLineWidth(4)
            cg.strokeEllipse(in: CGRect(x: 19, y: 19, width: 90, height: 90))
            cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: 35, y: 35, width: 58, height: 58))

            UIColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 57, y: 57, width: 14, height: 14))

            UIColor.white.withAlphaComponent(0.9).setStroke()
            cg.setLineWidth(3)
            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
                let start = CGPoint(x: 64 + cos(angle) * 18, y: 64 + sin(angle) * 18)
                let end = CGPoint(x: 64 + cos(angle) * 51, y: 64 + sin(angle) * 51)
                cg.move(to: start)
                cg.addLine(to: end)
            }
            cg.strokePath()
        }
        return convertImageToLogoData(image)
    }

    private func renderRGBA(_ image: UIImage) -> [UInt8]? {
        let width = SHX8800PRO.bootImageWidth
        let height = SHX8800PRO.bootImageHeight
        let targetSize = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let sourceSize = image.size
            let ratio = max(targetSize.width / max(sourceSize.width, 1), targetSize.height / max(sourceSize.height, 1))
            let drawSize = CGSize(width: sourceSize.width * ratio, height: sourceSize.height * ratio)
            let drawRect = CGRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect)
        }

        guard let cgImage = rendered.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private func rgb565Data(fromRGBA pixels: [UInt8]) -> Data {
        var output = Data()
        output.reserveCapacity(SHX8800PRO.bootImageBytes)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = UInt16(pixels[index] >> 3)
            let green = UInt16(pixels[index + 1] >> 2)
            let blue = UInt16(pixels[index + 2] >> 3)
            let value = (red << 11) | (green << 5) | blue
            output.append(UInt8(value & 0xFF))
            output.append(UInt8((value >> 8) & 0xFF))
        }

        return output
    }

    private func renderPresetImage(_ draw: (UIGraphicsImageRendererContext, CGRect) -> Void) -> UIImage {
        let size = CGSize(width: SHX8800PRO.bootImageWidth, height: SHX8800PRO.bootImageHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            draw(context, CGRect(origin: .zero, size: size))
        }
    }

    private func drawCenteredText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let measured = text.boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.midY - measured.height / 2,
            width: rect.width,
            height: min(rect.height, measured.height + 2)
        )
        text.draw(in: drawRect, withAttributes: attributes)
    }
}

private struct PresetLogoButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
