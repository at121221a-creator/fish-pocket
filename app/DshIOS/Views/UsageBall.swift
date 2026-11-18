import SwiftUI

/// 会话里一颗可拖动的小球：显示这一场用了多少 token、大约花了多少钱。
/// 点一下展开明细，长按隐藏（设置里可以再打开）。
struct UsageBall: View {
    let model: SessionModel

    @AppStorage("xidai.ball.hidden") private var hidden = false
    @AppStorage("xidai.ball.dx") private var dx: Double = 0
    @AppStorage("xidai.ball.dy") private var dy: Double = 0
    @AppStorage("xidai.ball.window") private var windowMode = false

    @State private var drag: CGSize = .zero
    @State private var expanded = false

    private var input: Int { model.tokens.input }
    private var output: Int { model.tokens.output }
    private var cache: Int { model.tokens.cacheRead }
    private var total: Int { input + output }

    /// 粗估：输入 3 元 / 百万 token，输出 6 元，缓存命中 0.025 元。
    private var cost: Double {
        let fresh = max(0, input - cache)
        return Double(fresh) / 1_000_000 * 3
            + Double(cache) / 1_000_000 * 0.025
            + Double(output) / 1_000_000 * 6
    }

    var body: some View {
        if hidden {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 8) {
                if windowMode {
                    window
                        .offset(x: dx + drag.width, y: dy + drag.height)
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { value in drag = value.translation }
                                .onEnded { value in
                                    dx += value.translation.width
                                    dy += value.translation.height
                                    drag = .zero
                                }
                        )
                } else if expanded { panel }
                if !windowMode {
                bubble
                    .offset(x: dx + drag.width, y: dy + drag.height)
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in drag = value.translation }
                            .onEnded { value in
                                dx += value.translation.width
                                dy += value.translation.height
                                drag = .zero
                            }
                    )
                    .onTapGesture { withAnimation(.snappy(duration: 0.18)) { expanded.toggle() } }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.snappy(duration: 0.18)) { hidden = true }
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    /// 摊开的窗口：一直显示明细，拖哪儿放哪儿，右上角能收回小球或关掉。
    private var window: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("本场用量")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Button {
                    withAnimation(.snappy(duration: 0.18)) { windowMode = false }
                } label: {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.secondary)
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.snappy(duration: 0.18)) { hidden = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.secondary)
                }
                .buttonStyle(.plain)
            }
            line("输入", short(input))
            line("其中缓存", short(cache))
            line("输出", short(output))
            if let context = model.contextTokens {
                line("上下文", short(context))
            }
            Rectangle().fill(Palette.stroke).frame(height: 1).padding(.vertical, 2)
            HStack(spacing: 4) {
                Text("约").foregroundStyle(Palette.secondary)
                Text(money(cost)).foregroundStyle(Palette.ink)
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(11)
        .frame(width: 158, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var bubble: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().strokeBorder(Palette.stroke, lineWidth: 1)
            VStack(spacing: 0) {
                Text(short(total))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("token")
                    .font(.system(size: 7.5))
            }
            .foregroundStyle(Palette.secondary)
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
        .accessibilityLabel("用量 \(short(total)) token")
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 5) {
            line("输入", short(input))
            line("其中缓存", short(cache))
            line("输出", short(output))
            if let context = model.contextTokens {
                line("上下文", short(context))
            }
            Rectangle().fill(Palette.stroke).frame(height: 1).padding(.vertical, 2)
            HStack(spacing: 4) {
                Text("约").foregroundStyle(Palette.secondary)
                Text(money(cost)).foregroundStyle(Palette.ink)
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(10)
        .frame(width: 148, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.secondary)
            Spacer(minLength: 6)
            Text(value).foregroundStyle(Palette.ink)
        }
        .font(.system(size: 10.5))
    }

    private func short(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1000 { return String(format: "%.1fk", Double(value) / 1000) }
        return "\(value)"
    }

    private func money(_ value: Double) -> String {
        if value < 0.01 { return "不到 ¥0.01" }
        return String(format: "¥%.2f", value)
    }
}
