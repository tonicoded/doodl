import SwiftUI
import PencilKit
import Combine
import CoreImage

private enum DoodleTemplate: String, CaseIterable, Identifiable {
    case none
    case grid
    case dots
    case smiley
    case face
    case heart
    case star
    case cat
    case crown
    case lightning
    case flower
    case rocket
    case skull
    case christmasTree
    case butterfly

    var id: String { rawValue }

    /// Curated list shown in the UI (only the nicest templates).
    static var featured: [DoodleTemplate] {
        [
            .none,
            .grid,
            .dots,
            .face,
            .heart,
            .star,
            .lightning,
            .crown,
            .butterfly,
        ]
    }

    var isProOnly: Bool {
        switch self {
        case .none, .grid: false
        case .dots, .smiley, .face, .heart, .star, .cat, .crown, .lightning, .flower, .rocket, .skull, .christmasTree, .butterfly: true
        }
    }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.none, .english): "none"
        case (.none, .dutch): "geen"
        case (.none, .german): "keins"
        case (.none, .spanish): "ninguno"

        case (.grid, .english): "grid"
        case (.grid, .dutch): "raster"
        case (.grid, .german): "raster"
        case (.grid, .spanish): "cuadrícula"

        case (.dots, .english): "dots"
        case (.dots, .dutch): "punten"
        case (.dots, .german): "punkte"
        case (.dots, .spanish): "puntos"

        case (.smiley, .english): "smiley"
        case (.smiley, .dutch): "smiley"
        case (.smiley, .german): "smiley"
        case (.smiley, .spanish): "carita"

        case (.face, .english): "face guide"
        case (.face, .dutch): "gezicht gids"
        case (.face, .german): "gesichts-hilfe"
        case (.face, .spanish): "guía de cara"

        case (.heart, .english): "heart"
        case (.heart, .dutch): "hart"
        case (.heart, .german): "herz"
        case (.heart, .spanish): "corazón"

        case (.star, .english): "star"
        case (.star, .dutch): "ster"
        case (.star, .german): "stern"
        case (.star, .spanish): "estrella"

        case (.cat, .english): "cat"
        case (.cat, .dutch): "kat"
        case (.cat, .german): "katze"
        case (.cat, .spanish): "gato"

        case (.crown, .english): "crown"
        case (.crown, .dutch): "kroon"
        case (.crown, .german): "krone"
        case (.crown, .spanish): "corona"

        case (.lightning, .english): "bolt"
        case (.lightning, .dutch): "bliksem"
        case (.lightning, .german): "blitz"
        case (.lightning, .spanish): "rayo"

        case (.flower, .english): "flower"
        case (.flower, .dutch): "bloem"
        case (.flower, .german): "blume"
        case (.flower, .spanish): "flor"

        case (.rocket, .english): "rocket"
        case (.rocket, .dutch): "raket"
        case (.rocket, .german): "rakete"
        case (.rocket, .spanish): "cohete"

        case (.skull, .english): "skull"
        case (.skull, .dutch): "schedel"
        case (.skull, .german): "schädel"
        case (.skull, .spanish): "calavera"

        case (.christmasTree, .english): "tree"
        case (.christmasTree, .dutch): "boom"
        case (.christmasTree, .german): "baum"
        case (.christmasTree, .spanish): "árbol"

        case (.butterfly, .english): "butterfly"
        case (.butterfly, .dutch): "vlinder"
        case (.butterfly, .german): "schmetterling"
        case (.butterfly, .spanish): "mariposa"
        }
    }
}

@MainActor
final class DoodleCanvasViewModel: NSObject, ObservableObject, PKCanvasViewDelegate {
    let canvasView = PKCanvasView()

    // Use explicit sRGB colors (avoid device-gray colorspace issues with PencilKit/export).
    @Published var selectedColor: UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1) {
        didSet {
            ensureVisibleColor()
            updateTool()
        }
    }

    @Published var inkType: PKInkingTool.InkType = .pen {
        didSet { updateTool() }
    }

    @Published var lineWidth: CGFloat = 12 {
        didSet { updateTool() }
    }

    @Published var isEraser: Bool = false {
        didSet { updateTool() }
    }

    @Published var isNeonCanvas: Bool = false {
        didSet {
            if !isNeonCanvas, isGlowBrush {
                isGlowBrush = false
            }
            ensureVisibleColor()
        }
    }
    @Published var isGlowBrush: Bool = false {
        didSet {
            updateTool()
            if !isGlowBrush { glowPreviewImage = nil }
            scheduleGlowPreviewUpdate()
        }
    }

    @Published var glowIntensity: Double = 1.35 { didSet { scheduleGlowPreviewUpdate() } }
    @Published var glowRadius: Double = 16 { didSet { scheduleGlowPreviewUpdate() } }

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var isEmpty = true
    @Published private(set) var glowPreviewImage: UIImage?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var glowPreviewTask: Task<Void, Never>?
    private var isAdjustingColor = false

    override init() {
        super.init()
        // Keep the live canvas transparent so we can show templates underneath.
        // Export is still flattened onto white in `renderImage()`.
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = self
        updateTool()
        refreshState()
    }

    func clear() {
        canvasView.drawing = PKDrawing()
        refreshState()
        glowPreviewImage = nil
    }

    func undo() {
        canvasView.undoManager?.undo()
        refreshState()
        scheduleGlowPreviewUpdate()
    }

    func redo() {
        canvasView.undoManager?.redo()
        refreshState()
        scheduleGlowPreviewUpdate()
    }

    func renderImage() -> UIImage {
        canvasView.layoutIfNeeded()
        let baseBounds = canvasView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 360, height: 360) : canvasView.bounds
        let bounds = baseBounds.insetBy(dx: -8, dy: -8)
        let drawingImage = canvasView.drawing.image(from: bounds, scale: UIScreen.main.scale)

        let scale = drawingImage.scale
        let pixelSize = CGSize(width: drawingImage.size.width * scale, height: drawingImage.size.height * scale)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              pixelSize.width >= 1, pixelSize.height >= 1 else {
            return drawingImage
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(pixelSize.width),
            height: Int(pixelSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return drawingImage
        }

        context.scaleBy(x: scale, y: scale)
        context.setFillColor((isNeonCanvas ? UIColor.black : UIColor.white).cgColor)
        context.fill(CGRect(origin: .zero, size: drawingImage.size))
        if let cgImage = drawingImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: drawingImage.size))
        } else {
            drawingImage.draw(in: CGRect(origin: .zero, size: drawingImage.size))
        }
        guard let flattened = context.makeImage() else { return drawingImage }
        let base = UIImage(cgImage: flattened, scale: scale, orientation: .up)

        guard isGlowBrush else { return base }
        guard let ciImage = CIImage(image: base) else { return base }

        // Multi-pass bloom looks much nicer than a single bloom (tight core + soft halo).
        let radius = max(1, glowRadius)
        let intensity = max(0.0, glowIntensity)

        func applyBloom(_ input: CIImage, radius: Double, intensity: Double) -> CIImage? {
            guard let bloom = CIFilter(name: "CIBloom") else { return nil }
            bloom.setValue(input, forKey: kCIInputImageKey)
            bloom.setValue(Float(radius), forKey: kCIInputRadiusKey)
            bloom.setValue(Float(intensity), forKey: kCIInputIntensityKey)
            return bloom.outputImage
        }

        let pass1 = applyBloom(ciImage, radius: radius * 0.65, intensity: intensity * 1.25) ?? ciImage
        let pass2 = applyBloom(pass1, radius: radius * 1.9, intensity: intensity * 0.9) ?? pass1

        // CIBloom expands the extent beyond the original image; crop back so we don't introduce
        // transparent/white margins in inbox/widget renders.
        let cropped = pass2.cropped(to: ciImage.extent)
        guard let cg = ciContext.createCGImage(cropped, from: cropped.extent) else { return base }
        let bloomed = UIImage(cgImage: cg, scale: scale, orientation: .up)

        // Ensure the exported image is opaque. Some CoreImage paths can introduce transparency
        // which then shows up as white/transparent backgrounds in inbox + widget renders.
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = scale
        return UIGraphicsImageRenderer(size: bloomed.size, format: format).image { context in
            (isNeonCanvas ? UIColor.black : UIColor.white).setFill()
            context.fill(CGRect(origin: .zero, size: bloomed.size))
            bloomed.draw(in: CGRect(origin: .zero, size: bloomed.size))
        }
    }

    private func updateTool() {
        if isEraser {
            // Bitmap eraser removes parts of strokes (feels like a real gum),
            // whereas vector eraser deletes whole strokes.
            canvasView.tool = PKEraserTool(.bitmap)
            return
        }

        if isGlowBrush {
            if !isNeonCanvas { isNeonCanvas = true }
            let glowColor = selectedColor.withAlphaComponent(max(0.75, selectedColor.doodlRGBA?.a ?? 1))
            canvasView.tool = PKInkingTool(.marker, color: glowColor, width: max(lineWidth, 14))
            return
        }

        canvasView.tool = PKInkingTool(inkType, color: selectedColor, width: lineWidth)
    }

    private func ensureVisibleColor() {
        guard isNeonCanvas else { return }
        guard !isAdjustingColor else { return }
        guard let rgba = selectedColor.doodlRGBA else { return }

        // If the canvas is dark, a near-black brush looks like "nothing happened".
        // Auto-shift to a bright neon accent (same one used when enabling glow mode).
        let luminance = (0.2126 * rgba.r) + (0.7152 * rgba.g) + (0.0722 * rgba.b)
        if luminance < 0.08 {
            isAdjustingColor = true
            let alpha = max(0.9, rgba.a)
            selectedColor = UIColor(Color(hex: "2AD1D1")).withAlphaComponent(alpha)
            isAdjustingColor = false
        }
    }

    private func scheduleGlowPreviewUpdate() {
        guard isGlowBrush else { return }
        glowPreviewTask?.cancel()
        glowPreviewTask = Task { [weak self] in
            // Debounce so we don't re-render on every single point update.
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard let self, !Task.isCancelled else { return }

            let baseBounds = self.canvasView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 360, height: 360) : self.canvasView.bounds
            let bounds = baseBounds.insetBy(dx: -8, dy: -8)

            // Render the drawing only (transparent background) at a lower scale for snappy live preview.
            let drawingImage = self.canvasView.drawing.image(from: bounds, scale: 1.0)
            let radius = max(1, self.glowRadius)
            let intensity = max(0.0, self.glowIntensity)

            let ciContext = self.ciContext
            let output: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let ciImage = CIImage(image: drawingImage) else { return nil }
                func applyBloom(_ input: CIImage, radius: Double, intensity: Double) -> CIImage? {
                    guard let bloom = CIFilter(name: "CIBloom") else { return nil }
                    bloom.setValue(input, forKey: kCIInputImageKey)
                    bloom.setValue(Float(radius), forKey: kCIInputRadiusKey)
                    bloom.setValue(Float(intensity), forKey: kCIInputIntensityKey)
                    return bloom.outputImage
                }

                let pass1 = applyBloom(ciImage, radius: radius * 0.65, intensity: intensity * 1.25) ?? ciImage
                let pass2 = applyBloom(pass1, radius: radius * 1.9, intensity: intensity * 0.9) ?? pass1
                let cropped = pass2.cropped(to: ciImage.extent)
                guard let cg = ciContext.createCGImage(cropped, from: cropped.extent) else { return nil }
                return UIImage(cgImage: cg, scale: drawingImage.scale, orientation: .up)
            }.value

            guard !Task.isCancelled else { return }
            self.glowPreviewImage = output
        }
    }

    private func refreshState() {
        canUndo = canvasView.undoManager?.canUndo ?? false
        canRedo = canvasView.undoManager?.canRedo ?? false
        isEmpty = canvasView.drawing.strokes.isEmpty
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        refreshState()
        scheduleGlowPreviewUpdate()
    }
}

struct DoodleCanvasView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var model = DoodleCanvasViewModel()
    let language: AppLanguage
    let onSend: (UIImage) async throws -> Void
    var onSent: (() -> Void)? = nil
    @State private var canvasSize: CGSize = .zero
		    @State private var toastText: String?
		    @State private var isSending = false
		    @State private var showingTools = false
		    @State private var showingProPaywall = false
	    @State private var confettiTrigger = 0
    @State private var selectedTemplate: DoodleTemplate = .none
    @State private var templateOpacity: Double = 0.22
    private let maxCanvasSide: CGFloat = 500
    private let toastDismissDelaySeconds: Double = 2.2
    private var targetCanvasSide: CGFloat {
        min(UIScreen.main.bounds.width - 32, maxCanvasSide)
    }

    private var colors: [UIColor] {
        let proExtras: [UIColor] = [
            UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1),
            UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
            UIColor(red: 0.92, green: 0.16, blue: 0.26, alpha: 1),
            UIColor(red: 0.74, green: 0.18, blue: 0.95, alpha: 1),
            UIColor(red: 0.45, green: 0.20, blue: 0.95, alpha: 1),
            UIColor(red: 1.00, green: 0.95, blue: 0.35, alpha: 1),
            UIColor(red: 0.00, green: 0.70, blue: 0.40, alpha: 1),
            UIColor(red: 0.15, green: 0.85, blue: 0.70, alpha: 1),
            UIColor(Color(hex: "2AD1D1")),
            UIColor(red: 0.05, green: 0.40, blue: 0.95, alpha: 1),
            UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
            UIColor(red: 0.96, green: 0.76, blue: 0.91, alpha: 1),
            UIColor(red: 0.67, green: 0.88, blue: 1.00, alpha: 1),
            UIColor(red: 0.72, green: 0.94, blue: 0.79, alpha: 1),
            UIColor(red: 0.95, green: 0.92, blue: 0.68, alpha: 1),
            UIColor(red: 0.82, green: 0.80, blue: 0.96, alpha: 1),
            UIColor(red: 0.96, green: 0.86, blue: 0.68, alpha: 1),
            UIColor(red: 0.86, green: 0.98, blue: 0.98, alpha: 1),
            UIColor(red: 0.92, green: 0.92, blue: 0.98, alpha: 1),
            UIColor(red: 0.98, green: 0.84, blue: 0.84, alpha: 1)
        ]

        return freePalette + proExtras
    }

    private var freePalette: [UIColor] {
        [
            UIColor(red: 0, green: 0, blue: 0, alpha: 1), // black
            UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1), // gray
            UIColor(red: 1.00, green: 0.20, blue: 0.40, alpha: 1), // red
            UIColor(Color(hex: "2A9CFF")), // blue
            UIColor(red: 0.62, green: 0.40, blue: 1.00, alpha: 1), // purple
            UIColor(red: 1.00, green: 0.55, blue: 0.15, alpha: 1), // orange
            UIColor(red: 1.00, green: 0.85, blue: 0.20, alpha: 1), // yellow
            UIColor(Color(hex: "6AD84A")) // green
        ]
    }

		    var body: some View {
		        ZStack {
		            ZStack {
		                VStack(spacing: 0) {
		                    HStack(spacing: 10) {
		                        toolsFloatingButton
		                        Spacer(minLength: 0)
		                        toolActions
		                    }
		                    .padding(.horizontal, 6)
		                    .padding(.top, 2)
		                    .padding(.bottom, 12)

		                    let canvasSide = targetCanvasSide
		                    ZStack(alignment: .bottom) {
		                        RoundedRectangle(cornerRadius: 26, style: .continuous)
		                            .fill(model.isNeonCanvas ? Color.black.opacity(0.98) : Color.white.opacity(0.98))
		                            .overlay(
	                                RoundedRectangle(cornerRadius: 26, style: .continuous)
	                                    .stroke(model.isNeonCanvas ? .white.opacity(0.14) : .black.opacity(0.10), lineWidth: 1)
	                            )

	                        DoodleTemplateOverlay(template: selectedTemplate, opacity: templateOpacity, isDarkBackground: model.isNeonCanvas)
	                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
	                            .padding(6)
	                            .allowsHitTesting(false)

		                        if model.isGlowBrush, let preview = model.glowPreviewImage {
		                            Image(uiImage: preview)
		                                .renderingMode(.original)
		                                .resizable()
		                                .scaledToFill()
		                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		                                .padding(6)
		                                .allowsHitTesting(false)
		                                .blendMode(.plusLighter)
		                                .opacity(0.92)
		                        }

		                        CanvasRepresentable(canvasView: model.canvasView)
		                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		                            .padding(6)
		                    }
	                    .frame(width: canvasSide, height: canvasSide)
	                    .frame(maxWidth: .infinity)
	                    .background(
	                        GeometryReader { proxy in
	                            Color.clear
	                                .onAppear { updateCanvasSize(for: proxy.size) }
	                                .onChange(of: proxy.size) { _, newSize in
	                                    updateCanvasSize(for: newSize)
	                                }
	                        }
	                    )
		                }
		                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		                .padding(.top, 8)
		                .padding(.bottom, 92)

		                sendFloatingButton
		            }
		        }
		        .overlay {
		            ConfettiBurstView(trigger: confettiTrigger)
		                .ignoresSafeArea()
                .zIndex(50)
        }
        .onAppear {
            Haptics.prepare()
            enforceAllowedColor()
        }
        .onChange(of: purchaseManager.isPro) { _, _ in
            enforceAllowedColor()
        }
        .overlay(alignment: .top) {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.black.opacity(0.72), in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 10)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
		        }
        .sheet(isPresented: $showingTools) {
		            ToolsSheet(
		                language: language,
		                inkType: $model.inkType,
		                selectedColor: $model.selectedColor,
		                lineWidth: $model.lineWidth,
		                isEraser: $model.isEraser,
		                selectedTemplate: $selectedTemplate,
		                templateOpacity: $templateOpacity,
		                isNeonCanvas: $model.isNeonCanvas,
		                isGlowBrush: $model.isGlowBrush,
		                glowIntensity: $model.glowIntensity,
		                glowRadius: $model.glowRadius,
		                colors: colors,
		                isPro: purchaseManager.isPro,
		                isColorProOnly: { !isAllowedFreeColor($0) },
		                onRequestPro: {
	                    showingProPaywall = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
	        .sheet(isPresented: $showingProPaywall) {
	            ProPaywallView(language: language)
                    .environmentObject(purchaseManager)
	        }
	    }

	    private func updateCanvasSize(for proposedSize: CGSize) {
	        let side = min(min(proposedSize.width, proposedSize.height), maxCanvasSide)
	        let squareSize = CGSize(width: side, height: side)
        canvasSize = squareSize
        model.canvasView.contentSize = squareSize
    }

    private var sendTitle: String {
        switch language {
        case .english: "send doodl"
        case .dutch: "verstuur doodl"
        case .german: "doodl senden"
        case .spanish: "enviar doodl"
        }
    }

	    private var sentTitle: String {
	        switch language {
	        case .english: "sent"
	        case .dutch: "verstuurd"
	        case .german: "gesendet"
	        case .spanish: "enviado"
	        }
	    }

	    private var freeSendLimitReachedTitle: String {
            let limit = DoodleSendQuota.freeDailyLimit
	        switch language {
	        case .english: return "free limit reached (\(limit)/day) — upgrade to pro"
	        case .dutch: return "gratis limiet bereikt (\(limit)/dag) — upgrade naar pro"
	        case .german: return "gratis-limit erreicht (\(limit)/tag) — upgrade auf pro"
	        case .spanish: return "límite gratis alcanzado (\(limit)/día) — mejora a pro"
	        }
	    }

	    private func sentToastTitle(remainingFreeSendsToday: Int?) -> String {
	        guard let remainingFreeSendsToday else { return sentTitle }
	        let limit = DoodleSendQuota.freeDailyLimit
	        guard limit > 0 else { return sentTitle }
	        switch language {
	        case .english: return "\(sentTitle) • free: \(remainingFreeSendsToday)/\(limit) left today"
	        case .dutch: return "\(sentTitle) • gratis: nog \(remainingFreeSendsToday)/\(limit) vandaag"
	        case .german: return "\(sentTitle) • gratis: noch \(remainingFreeSendsToday)/\(limit) heute"
	        case .spanish: return "\(sentTitle) • gratis: quedan \(remainingFreeSendsToday)/\(limit) hoy"
	        }
	    }

    private func freeQuotaBadgeTitle(remainingFreeSendsToday: Int, limit: Int) -> String {
        switch language {
        case .english: return "free \(remainingFreeSendsToday)/\(limit) today"
        case .dutch: return "gratis \(remainingFreeSendsToday)/\(limit) vandaag"
        case .german: return "gratis \(remainingFreeSendsToday)/\(limit) heute"
        case .spanish: return "gratis \(remainingFreeSendsToday)/\(limit) hoy"
        }
    }

    private var freeQuotaBadge: some View {
        Group {
            if !purchaseManager.isPro {
                let limit = DoodleSendQuota.freeDailyLimit
                if limit > 0 && limit != Int.max {
                    let remaining = DoodleSendQuota.remainingFreeSendsToday()
                    Text(freeQuotaBadgeTitle(remainingFreeSendsToday: remaining, limit: limit))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(.black.opacity(0.70), in: Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)
                        .accessibilityLabel(Text("free quota \(remaining) of \(limit) remaining today"))
                }
            }
        }
    }

	    private var sendingTitle: String {
	        switch language {
	        case .english: "sending…"
	        case .dutch: "versturen…"
	        case .german: "senden…"
        case .spanish: "enviando…"
        }
    }

			    private var failedTitle: String {
			        switch language {
			        case .english: "failed"
			        case .dutch: "mislukt"
			        case .german: "fehlgeschlagen"
			        case .spanish: "falló"
			        }
			    }

		    private var toolsFloatingButton: some View {
		        Button {
		            Haptics.tap()
		            showingTools = true
		        } label: {
		            ZStack {
		                Circle()
		                    .fill(.black.opacity(0.28))
		                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
		                Image(systemName: "slider.horizontal.3")
		                    .font(.system(size: 16, weight: .heavy))
		                    .foregroundStyle(.white.opacity(0.95))
		            }
		            .frame(width: 44, height: 44)
		            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 10)
		        }
		        .buttonStyle(.plain)
		        .dashboardTutorialAnchor(.toolsButton)
		    }

			    private var sendFloatingButton: some View {
			        VStack {
			            Spacer()
                    VStack(spacing: 10) {
                        freeQuotaBadge

                        Button {
                            Task {
                                if isSending { return }
                                if !DoodleSendQuota.canSend(isPro: purchaseManager.isPro) {
                                    Haptics.error()
                                    toastText = freeSendLimitReachedTitle
                                    showingProPaywall = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + toastDismissDelaySeconds) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            toastText = nil
                                        }
                                    }
                                    return
                                }
                                Haptics.tap(.medium)
                                isSending = true
                                toastText = sendingTitle
                                let image = model.renderImage()
                                do {
                                    try await onSend(image)
                                    Haptics.success()
                                    confettiTrigger += 1
                                    let remaining = DoodleSendQuota.recordSuccessfulSendIfNeeded(isPro: purchaseManager.isPro)
                                    toastText = sentToastTitle(remainingFreeSendsToday: remaining)
                                    DispatchQueue.main.async {
                                        onSent?()
                                    }
                                } catch {
                                    if error is CancellationError {
                                        toastText = nil
                                        isSending = false
                                        return
                                    }
                                    Haptics.error()
                                    if let message = UserFacingError.message(for: error, language: language) {
                                        toastText = "\(failedTitle): \(message)"
                                    } else {
                                        toastText = nil
                                    }
                                }
                                isSending = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + toastDismissDelaySeconds) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        toastText = nil
                                    }
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "FF3B30").opacity(isSending ? 0.82 : 0.94))
                                    .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 14)
                                Circle()
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                                if isSending {
                                    ProgressView().tint(.white.opacity(0.95))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundStyle(.white.opacity(0.98))
                                        .offset(x: 1, y: -1)
                                }
                            }
                            .frame(width: 72, height: 72)
                        }
                        .buttonStyle(.plain)
                        .dashboardTutorialAnchor(.sendButton)
                        .disabled(isSending)
                        .opacity(isSending ? 0.86 : 1)
                    }
                    // Keep above the floating bottom tab bar.
                    .padding(.bottom, 45)
		        }
		    }

		    private var toolActions: some View {
		        HStack(spacing: 6) {
		            toolIconButton(symbol: "arrow.uturn.backward", isEnabled: model.canUndo) {
		                Haptics.selectionChanged()
		                model.undo()
	            }
	            toolIconButton(symbol: "arrow.uturn.forward", isEnabled: model.canRedo) {
	                Haptics.selectionChanged()
	                model.redo()
	            }
		            toolIconButton(symbol: "trash", isEnabled: !model.isEmpty) {
		                Haptics.tap(.rigid)
		                model.clear()
		            }
		        }
		        .padding(6)
		        .background(.thinMaterial, in: Capsule(style: .continuous))
		        .overlay(
		            Capsule(style: .continuous)
		                .stroke(GlassStyle.stroke, lineWidth: 1)
		        )
		        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 12)
		    }

	    private func toolIconButton(symbol: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
	        Button(action: action) {
	            Image(systemName: symbol)
	                .font(.system(size: 15, weight: .bold))
	                .foregroundStyle(Color.primary.opacity(0.80))
	                .padding(.vertical, 8)
	                .padding(.horizontal, 10)
	        }
	        .buttonStyle(.plain)
	        .disabled(!isEnabled)
	        .opacity(isEnabled ? 1 : 0.35)
	    }

    private var sizeTitle: String {
        switch language {
        case .english: "size"
        case .dutch: "grootte"
        case .german: "größe"
        case .spanish: "tamaño"
        }
    }

    private var penTitle: String {
        switch language {
        case .english: "pen"
        case .dutch: "pen"
        case .german: "stift"
        case .spanish: "pluma"
        }
    }

    private var markerTitle: String {
        switch language {
        case .english: "marker"
        case .dutch: "marker"
        case .german: "marker"
        case .spanish: "marcador"
        }
    }

    private var pencilTitle: String {
        switch language {
        case .english: "pencil"
        case .dutch: "potlood"
        case .german: "bleistift"
        case .spanish: "lápiz"
        }
    }

    private var toolsTitle: String {
        switch language {
        case .english: "tools"
        case .dutch: "tools"
        case .german: "tools"
        case .spanish: "herramientas"
        }
    }

	    private func enforceAllowedColor() {
	        guard !purchaseManager.isPro else { return }
	        guard isAllowedFreeColor(model.selectedColor) else {
	            model.selectedColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
	            return
	        }
	    }
	}

	private struct CanvasRepresentable: UIViewRepresentable {
	    let canvasView: PKCanvasView

	    func makeUIView(context: Context) -> PKCanvasView {
        canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

private struct ToolsSheet: View {
    let language: AppLanguage
    @Binding var inkType: PKInkingTool.InkType
    @Binding var selectedColor: UIColor
    @Binding var lineWidth: CGFloat
    @Binding var isEraser: Bool
    @Binding var selectedTemplate: DoodleTemplate
    @Binding var templateOpacity: Double
    @Binding var isNeonCanvas: Bool
    @Binding var isGlowBrush: Bool
    @Binding var glowIntensity: Double
    @Binding var glowRadius: Double
    let colors: [UIColor]
    let isPro: Bool
    let isColorProOnly: (UIColor) -> Bool
    let onRequestPro: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

	    private enum ToolPreset: String, CaseIterable, Identifiable {
	        case pen
	        case marker
	        case highlighter
	        case pencil
	        case eraser

	        var id: String { rawValue }
	    }

    private enum SizePreset: CaseIterable, Identifiable {
        case s
        case m
        case l

        var id: String { "\(self)" }

        var width: CGFloat {
            switch self {
            case .s: 6
            case .m: 12
            case .l: 20
            }
        }
    }

    private var penTitle: String {
        switch language {
        case .english: "pen"
        case .dutch: "pen"
        case .german: "stift"
        case .spanish: "pluma"
        }
    }

    private var markerTitle: String {
        switch language {
        case .english: "marker"
        case .dutch: "marker"
        case .german: "marker"
        case .spanish: "marcador"
        }
    }

    private var pencilTitle: String {
        switch language {
        case .english: "pencil"
        case .dutch: "potlood"
        case .german: "bleistift"
        case .spanish: "lápiz"
        }
    }

    private var sizeTitle: String {
        switch language {
        case .english: "size"
        case .dutch: "grootte"
        case .german: "größe"
        case .spanish: "tamaño"
        }
    }

    private var opacityTitle: String {
        switch language {
        case .english: "opacity"
        case .dutch: "doorzichtig"
        case .german: "deckkraft"
        case .spanish: "opacidad"
        }
    }

    private var highlighterTitle: String {
        switch language {
        case .english: "highlighter"
        case .dutch: "highlighter"
        case .german: "textmarker"
        case .spanish: "subrayador"
        }
    }

    private var eraserTitle: String {
        switch language {
        case .english: "eraser"
        case .dutch: "gum"
        case .german: "radierer"
        case .spanish: "borrador"
        }
    }

	    private var title: String {
	        switch language {
	        case .english: "tools"
	        case .dutch: "tools"
	        case .german: "tools"
	        case .spanish: "herramientas"
	        }
	    }

        private var canvasTitle: String {
            switch language {
            case .english: "canvas"
            case .dutch: "canvas"
            case .german: "leinwand"
            case .spanish: "lienzo"
            }
        }

	        private var neonCanvasTitle: String {
	            switch language {
	            case .english: "glow mode"
	            case .dutch: "glow modus"
	            case .german: "glow-modus"
	            case .spanish: "modo brillo"
	            }
	        }

	        private var neonCanvasSubtitle: String {
	            switch language {
	            case .english: "neon canvas + glow brush"
	            case .dutch: "neon canvas + glow brush"
	            case .german: "neon-leinwand + glow"
	            case .spanish: "lienzo neón + brillo"
	            }
	        }

	        private var glowIntensityTitle: String {
	            switch language {
	            case .english: "glow intensity"
            case .dutch: "glow sterkte"
            case .german: "glow-stärke"
            case .spanish: "intensidad"
            }
        }

        private var glowRadiusTitle: String {
            switch language {
            case .english: "glow size"
            case .dutch: "glow grootte"
            case .german: "glow-größe"
            case .spanish: "tamaño"
            }
        }

				    var body: some View {
				        NavigationStack {
			            ZStack {
			                ThemedBackground()

				                ScrollView(showsIndicators: false) {
					                    VStack(spacing: 14) {
			                            canvasCard
				                        templateCard
				                        toolPickerCard
				                        colorCard
				                        sizeCard
				                        opacityCard
			                            if isNeonCanvas {
			                                glowSettingsCard
			                            }
					                    }
				                    .padding(.horizontal, 16)
			                    .padding(.top, 16)
			                    .padding(.bottom, 28)
				                }
			            }
				            .navigationTitle(title)
				            .navigationBarTitleDisplayMode(.inline)
				            .toolbarBackground(.hidden, for: .navigationBar)
				            .toolbarColorScheme(colorScheme, for: .navigationBar)
				        }
				    }

	        private var neonModeBinding: Binding<Bool> {
	            Binding(
	                get: { isNeonCanvas },
	                set: { newValue in
	                    Haptics.selectionChanged()
	                    if newValue, !isPro {
	                        Haptics.warning()
	                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
	                            onRequestPro()
	                        }
	                        return
	                    }
	                    if newValue {
	                        isNeonCanvas = true
	                        isGlowBrush = true
	                        isEraser = false
	                        inkType = .marker
	                        lineWidth = max(lineWidth, 14)
	                        if colorsEqualIgnoringAlpha(selectedColor, UIColor.black) {
	                            selectedColor = UIColor(Color(hex: "2AD1D1")).withAlphaComponent(max(currentAlpha, 0.9))
	                        } else {
	                            selectedColor = selectedColor.withAlphaComponent(max(currentAlpha, 0.9))
	                        }
	                    } else {
	                        isNeonCanvas = false
	                        isGlowBrush = false
	                    }
	                }
	            )
	        }

		        private var canvasCard: some View {
		            VStack(alignment: .leading, spacing: 10) {
		                Text(canvasTitle)
		                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.secondary.opacity(0.85))

	                Toggle(isOn: neonModeBinding) {
	                    HStack(spacing: 12) {
		                        Image(systemName: "sparkles.square.filled.on.square")
		                            .font(.system(size: 16, weight: .bold))
		                            .foregroundStyle(.black.opacity(0.72))
		                            .frame(width: 22)
		                        VStack(alignment: .leading, spacing: 3) {
		                            Text(neonCanvasTitle)
		                                .font(.system(size: 14, weight: .heavy, design: .rounded))
		                                .foregroundStyle(.primary.opacity(0.92))
		                            Text(neonCanvasSubtitle)
		                                .font(.system(size: 12, weight: .semibold, design: .rounded))
		                                .foregroundStyle(.secondary.opacity(0.80))
		                        }
	                        Spacer()
		                        if !isPro {
		                            Image(systemName: "crown.fill")
		                                .font(.system(size: 13, weight: .bold))
		                                .foregroundStyle(Color(hex: "D4AF37").opacity(0.95))
		                        }
		                    }
		                }
		                .tint(.black.opacity(0.70))
		                .opacity(isPro ? 1 : 0.78)
	            }
	            .padding(14)
	            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		            .overlay(
		                RoundedRectangle(cornerRadius: 18, style: .continuous)
		                    .stroke(.black.opacity(0.10), lineWidth: 1)
		            )
		        }

		        private var glowSettingsCard: some View {
		            VStack(alignment: .leading, spacing: 10) {
		                HStack {
		                    Text(glowIntensityTitle)
	                        .font(.system(size: 14, weight: .heavy, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                    Spacer()
	                    Text("\(Int(glowIntensity * 100))%")
	                        .font(.system(size: 14, weight: .heavy, design: .rounded))
	                        .monospacedDigit()
	                        .foregroundStyle(.secondary.opacity(0.85))
	                }
	                Slider(value: $glowIntensity, in: 0.2...3.0, step: 0.05)
	                    .tint(.black.opacity(0.65))
	                    .onChange(of: glowIntensity) { _, _ in Haptics.selectionChanged() }

	                HStack {
	                    Text(glowRadiusTitle)
	                        .font(.system(size: 14, weight: .heavy, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                    Spacer()
	                    Text("\(Int(glowRadius))")
	                        .font(.system(size: 14, weight: .heavy, design: .rounded))
	                        .monospacedDigit()
	                        .foregroundStyle(.secondary.opacity(0.85))
	                }
	                Slider(value: $glowRadius, in: 6...44, step: 1)
	                    .tint(.black.opacity(0.65))
	                    .onChange(of: glowRadius) { _, _ in Haptics.selectionChanged() }
	            }
	            .padding(14)
	            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	            .overlay(
	                RoundedRectangle(cornerRadius: 18, style: .continuous)
	                    .stroke(.black.opacity(0.10), lineWidth: 1)
	            )
	        }

    private var templateTitle: String {
        switch language {
        case .english: "templates"
        case .dutch: "templates"
        case .german: "vorlagen"
        case .spanish: "plantillas"
        }
    }

    private var templateSubtitle: String {
        switch language {
        case .english: "pick a guide to draw over"
        case .dutch: "kies een gids om overheen te tekenen"
        case .german: "wähle eine vorlage zum drüberzeichnen"
        case .spanish: "elige una guía para dibujar encima"
        }
    }

    private var templateOpacityTitle: String {
        switch language {
        case .english: "template opacity"
        case .dutch: "template doorzichtig"
        case .german: "vorlagen-deckkraft"
        case .spanish: "opacidad de plantilla"
        }
    }

    private var proOnlyTitle: String {
        switch language {
        case .english: "pro"
        case .dutch: "pro"
        case .german: "pro"
        case .spanish: "pro"
        }
    }

	    private var templateCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            VStack(alignment: .leading, spacing: 4) {
	                Text(templateTitle)
	                    .font(.system(size: 14, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.85))
	                Text(templateSubtitle)
	                    .font(.system(size: 12, weight: .semibold, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.75))
	            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DoodleTemplate.featured) { template in
                        templateChip(template)
                    }
                }
                .padding(.horizontal, 2)
            }

            if selectedTemplate != .none {
	                HStack {
	                    Text(templateOpacityTitle)
	                        .font(.system(size: 13, weight: .heavy, design: .rounded))
	                        .foregroundStyle(.secondary.opacity(0.85))
	                    Spacer()
	                    Text("\(Int(templateOpacity * 100))%")
	                        .font(.system(size: 13, weight: .heavy, design: .rounded))
	                        .monospacedDigit()
	                        .foregroundStyle(.secondary.opacity(0.85))
	                }
	                Slider(value: $templateOpacity, in: 0.08...0.55, step: 0.01)
	                    .tint(.black.opacity(0.65))
	                    .onChange(of: templateOpacity) { _, _ in
	                        Haptics.selectionChanged()
	                    }
	            }
	        }
	        .padding(14)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
	    }

    private func templateChip(_ template: DoodleTemplate) -> some View {
        let isSelected = template == selectedTemplate
        let isLocked = template.isProOnly && !isPro

        return Button {
            if isLocked {
                Haptics.warning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onRequestPro()
                }
                return
            }
            Haptics.selectionChanged()
            selectedTemplate = template
        } label: {
	            VStack(spacing: 8) {
	                ZStack {
	                    RoundedRectangle(cornerRadius: 14, style: .continuous)
	                        .fill(isSelected ? .black.opacity(0.06) : .black.opacity(0.04))

                    DoodleTemplateOverlay(template: template, opacity: isSelected ? 0.35 : 0.26)
                        .padding(8)
                        .allowsHitTesting(false)

                    if isLocked {
                        VStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                            Text(proOnlyTitle)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )
                    }
	                }
	                .frame(width: 68, height: 62)
	                .overlay(
	                    RoundedRectangle(cornerRadius: 14, style: .continuous)
	                        .stroke(.black.opacity(isSelected ? 0.18 : 0.10), lineWidth: isSelected ? 1.5 : 1)
	                )

	                Text(template.title(language: language))
	                    .font(.system(size: 12, weight: .heavy, design: .rounded))
	                    .foregroundStyle(isLocked ? Color.secondary.opacity(0.55) : Color.primary.opacity(0.92))
	                    .lineLimit(1)
	                    .frame(width: 70)
	            }
        }
	        .buttonStyle(.plain)
	        .opacity(isLocked ? 0.95 : 1)
	    }

		    private var toolPickerCard: some View {
		        VStack(alignment: .leading, spacing: 10) {
		            Text(title)
		                .font(.system(size: 14, weight: .heavy, design: .rounded))
		                .foregroundStyle(.secondary.opacity(0.85))

	            ScrollView(.horizontal, showsIndicators: false) {
	                HStack(spacing: 10) {
	                    toolChip(.pen, title: penTitle, symbol: "pencil.tip")
	                    toolChip(.marker, title: markerTitle, symbol: "highlighter")
	                    toolChip(.highlighter, title: highlighterTitle, symbol: "sparkles")
	                    toolChip(.pencil, title: pencilTitle, symbol: "pencil")
	                    toolChip(.eraser, title: eraserTitle, symbol: "eraser.fill")
	                }
	                .padding(.horizontal, 2)
	            }
		        }
	        .padding(14)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
	    }

	    private func toolChip(_ preset: ToolPreset, title: String, symbol: String) -> some View {
	        let isActive = activePreset == preset
	        return Button {
	            Haptics.selectionChanged()
	            apply(preset: preset)
	        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		            }
            .foregroundStyle(isActive ? Color.white : Color.black.opacity(0.82))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isActive {
                        Capsule(style: .continuous).fill(.black.opacity(0.88))
                    } else {
                        Capsule(style: .continuous).fill(.black.opacity(0.05))
                    }
                }
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.black.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

	    private var colorCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            Text(colorTitle)
	                .font(.system(size: 14, weight: .heavy, design: .rounded))
	                .foregroundStyle(.secondary.opacity(0.85))

            let columns = Array(repeating: GridItem(.fixed(36), spacing: 10), count: 7)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(colors.indices, id: \.self) { idx in
                    let color = colors[idx]
                    let isSelected = colorsEqualIgnoringAlpha(selectedColor, color)
                    let isProOnly = isColorProOnly(color)
                    let isLocked = isProOnly && !isPro
                    Button {
                        if isLocked {
                            Haptics.warning()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onRequestPro()
                            }
                            return
                        }
                        Haptics.selectionChanged()
                        selectedColor = color.withAlphaComponent(currentAlpha)
                        if isEraser { isEraser = false }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
	                            Circle()
	                                .fill(Color(uiColor: color))
	                                .frame(width: 36, height: 36)
	                                .overlay(
	                                    Circle()
	                                        .stroke(.black.opacity(isSelected ? 0.55 : 0.16), lineWidth: isSelected ? 2.5 : 1)
	                                )
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .heavy))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }

	                            if isProOnly {
	                                Image(systemName: "crown.fill")
	                                    .font(.system(size: 10, weight: .bold))
	                                    .foregroundStyle(.white.opacity(0.92))
                                    .padding(5)
                                    .background(.black.opacity(0.35), in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                                    .padding(1)
                            }
                        }
                        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
	        }
	        .padding(14)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
	    }

		    private var sizeCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            HStack {
		                Text(sizeTitle)
		                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		                    .foregroundStyle(.secondary.opacity(0.85))
	                Spacer()
		                Text("\(Int(lineWidth))")
		                    .font(.system(size: 14, weight: .heavy, design: .rounded))
		                    .monospacedDigit()
		                    .foregroundStyle(.secondary.opacity(0.85))
	            }

	            HStack(spacing: 10) {
	                sizeChip(.s)
	                sizeChip(.m)
	                sizeChip(.l)
	                Spacer(minLength: 0)
	            }

	            Slider(value: $lineWidth, in: 2...28, step: 1)
	                .tint(.white.opacity(0.85))
		                .onChange(of: lineWidth) { _, _ in
		                    if isEraser { isEraser = false }
		                    Haptics.selectionChanged()
		                }
	        }
	        .padding(14)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
        .opacity(isEraser ? 0.55 : 1)
        .overlay(alignment: .topTrailing) {
	            if isEraser {
	                Text(eraserNote)
	                    .font(.system(size: 12, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.black.opacity(0.88))
	                    .padding(.vertical, 6)
	                    .padding(.horizontal, 10)
	                    .background(.thinMaterial, in: Capsule(style: .continuous))
	                    .overlay(Capsule(style: .continuous).stroke(.black.opacity(0.10), lineWidth: 1))
	                    .padding(10)
	            }
        }
        .disabled(isEraser)
    }

		    private func sizeChip(_ preset: SizePreset) -> some View {
	        let isActive = abs(lineWidth - preset.width) < 0.5
	        return Button {
	            Haptics.selectionChanged()
	            lineWidth = preset.width
	            if isEraser { isEraser = false }
		        } label: {
		            Text(sizeLabel(for: preset))
		                .font(.system(size: 13, weight: .heavy, design: .rounded))
		                .foregroundStyle(isActive ? Color.white : Color.black.opacity(0.82))
	                .padding(.vertical, 8)
	                .padding(.horizontal, 12)
	                .background(
	                    Group {
	                        if isActive {
	                            Capsule(style: .continuous).fill(.black.opacity(0.88))
	                        } else {
	                            Capsule(style: .continuous).fill(.black.opacity(0.05))
	                        }
	                    }
	                )
		                .overlay(
		                    Capsule(style: .continuous)
		                        .stroke(.black.opacity(0.10), lineWidth: 1)
		                )
		        }
	        .buttonStyle(.plain)
	    }

	    private var opacityCard: some View {
	        VStack(alignment: .leading, spacing: 10) {
	            HStack {
	                Text(opacityTitle)
	                    .font(.system(size: 14, weight: .heavy, design: .rounded))
	                    .foregroundStyle(.secondary.opacity(0.85))
	                Spacer()
	                Text("\(Int(currentAlpha * 100))%")
	                    .font(.system(size: 14, weight: .heavy, design: .rounded))
	                    .monospacedDigit()
	                    .foregroundStyle(.secondary.opacity(0.85))
	            }

            Slider(value: Binding(
                get: { currentAlpha },
                set: { newValue in
                    Haptics.selectionChanged()
                    selectedColor = selectedColor.withAlphaComponent(newValue)
                    if isEraser { isEraser = false }
                }
			            ), in: 0.15...1, step: 0.01)
			            .tint(.black.opacity(0.65))
			        }
	        .padding(14)
	        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 18, style: .continuous)
	                .stroke(.black.opacity(0.10), lineWidth: 1)
	        )
        .opacity(isEraser ? 0.55 : 1)
        .disabled(isEraser)
    }

	    private var activePreset: ToolPreset {
	        if isEraser { return .eraser }
	        if inkType == .pencil { return .pencil }
	        if inkType == .marker, currentAlpha <= 0.45 { return .highlighter }
	        if inkType == .marker { return .marker }
	        return .pen
	    }

			    private func apply(preset: ToolPreset) {
			        switch preset {
		        case .pen:
		            isEraser = false
	            inkType = .pen
	            isGlowBrush = isNeonCanvas
	            selectedColor = selectedColor.withAlphaComponent(isNeonCanvas ? max(currentAlpha, 0.9) : 1)
	        case .marker:
	            isEraser = false
	            inkType = .marker
	            isGlowBrush = isNeonCanvas
	            selectedColor = selectedColor.withAlphaComponent(isNeonCanvas ? max(currentAlpha, 0.9) : max(currentAlpha, 0.70))
	        case .highlighter:
	            isEraser = false
	            inkType = .marker
	            isGlowBrush = isNeonCanvas
	            selectedColor = selectedColor.withAlphaComponent(isNeonCanvas ? max(currentAlpha, 0.9) : 0.35)
	            lineWidth = max(lineWidth, isNeonCanvas ? 14 : 16)
	        case .pencil:
	            isEraser = false
	            inkType = .pencil
	            isGlowBrush = isNeonCanvas
	            selectedColor = selectedColor.withAlphaComponent(isNeonCanvas ? max(currentAlpha, 0.9) : 1)
			        case .eraser:
			            isEraser = true
                isGlowBrush = isNeonCanvas
			        }
			    }

    private var currentAlpha: CGFloat {
        var a: CGFloat = 1
        selectedColor.getRed(nil, green: nil, blue: nil, alpha: &a)
        return a
    }

    private func colorsEqualIgnoringAlpha(_ a: UIColor, _ b: UIColor) -> Bool {
        guard let ca = a.doodlRGBA, let cb = b.doodlRGBA else { return false }
        return abs(ca.r - cb.r) < 0.01 && abs(ca.g - cb.g) < 0.01 && abs(ca.b - cb.b) < 0.01
    }

    private var colorTitle: String {
        switch language {
        case .english: "colors"
        case .dutch: "kleuren"
        case .german: "farben"
        case .spanish: "colores"
        }
    }

    private func sizeLabel(for preset: SizePreset) -> String {
        switch preset {
        case .s: return "S"
        case .m: return "M"
        case .l: return "L"
        }
    }

		    private var eraserNote: String {
		        switch language {
		        case .english: "eraser"
		        case .dutch: "gum"
		        case .german: "radierer"
		        case .spanish: "borrador"
		        }
		    }

}

	private struct DoodleTemplateOverlay: View {
		    let template: DoodleTemplate
		    let opacity: Double
		    var isDarkBackground: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let rect = CGRect(x: (proxy.size.width - size) / 2, y: (proxy.size.height - size) / 2, width: size, height: size)
            let strokeColor = (isDarkBackground ? Color.white : Color.black).opacity(opacity)

            ZStack {
                switch template {
                case .none:
                    EmptyView()
                case .grid:
                    grid(in: rect, color: strokeColor)
                case .dots:
                    dots(in: rect, color: strokeColor)
                case .smiley:
                    smiley(in: rect, color: strokeColor)
                case .face:
                    faceGuide(in: rect, color: strokeColor)
                case .heart:
                    heart(in: rect, color: strokeColor)
                case .star:
                    star(in: rect, color: strokeColor)
                case .cat:
                    cat(in: rect, color: strokeColor)
                case .crown:
                    crown(in: rect, color: strokeColor)
                case .lightning:
                    lightning(in: rect, color: strokeColor)
                case .flower:
                    flower(in: rect, color: strokeColor)
                case .rocket:
                    rocket(in: rect, color: strokeColor)
                case .skull:
                    skull(in: rect, color: strokeColor)
                case .christmasTree:
                    christmasTree(in: rect, color: strokeColor)
                case .butterfly:
                    butterfly(in: rect, color: strokeColor)
                }
            }
        }
    }

    private func grid(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        return Path { path in
            let steps = 4
            for i in 1..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = rect.minX + rect.width * t
                let y = rect.minY + rect.height * t
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        .stroke(color, style: stroke)
    }

    private func dots(in rect: CGRect, color: Color) -> some View {
        let step = rect.width / 6
        return Canvas { context, _ in
            let r: CGFloat = 1.6
            for row in 1...5 {
                for col in 1...5 {
                    let x = rect.minX + CGFloat(col) * step
                    let y = rect.minY + CGFloat(row) * step
                    let dotRect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(color))
                }
            }
        }
    }

    private func smiley(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        let inset = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
        return ZStack {
            Path(ellipseIn: inset).stroke(color, style: stroke)
            Canvas { context, _ in
                let eyeR: CGFloat = rect.width * 0.035
                let left = CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.10)
                let right = CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.10)
                context.fill(Path(ellipseIn: CGRect(x: left.x - eyeR, y: left.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(color))
                context.fill(Path(ellipseIn: CGRect(x: right.x - eyeR, y: right.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(color))
            }
            Path { path in
                let mouthWidth = rect.width * 0.46
                let mouthHeight = rect.height * 0.22
                let start = CGPoint(x: rect.midX - mouthWidth / 2, y: rect.midY + rect.height * 0.12)
                let end = CGPoint(x: rect.midX + mouthWidth / 2, y: rect.midY + rect.height * 0.12)
                let control = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.12 + mouthHeight)
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
            }
            .stroke(color, style: stroke)
        }
    }

    private func faceGuide(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [6, 6])
        let solid = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        let inset = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
        return ZStack {
            Path(ellipseIn: inset).stroke(color, style: solid)
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: inset.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: inset.maxY))
                path.move(to: CGPoint(x: inset.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: inset.maxX, y: rect.midY))
                // Eye line
                let eyeY = rect.midY - rect.height * 0.10
                path.move(to: CGPoint(x: inset.minX, y: eyeY))
                path.addLine(to: CGPoint(x: inset.maxX, y: eyeY))
            }
            .stroke(color, style: stroke)
        }
    }

    private func heart(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return Path { path in
            let w = rect.width * 0.66
            let h = rect.height * 0.60
            let x = rect.midX - w / 2
            let y = rect.midY - h / 2
            let top = CGPoint(x: rect.midX, y: y + h * 0.22)
            path.move(to: top)
            path.addCurve(
                to: CGPoint(x: x, y: y + h * 0.30),
                control1: CGPoint(x: rect.midX - w * 0.18, y: y),
                control2: CGPoint(x: x, y: y + h * 0.08)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: y + h),
                control1: CGPoint(x: x, y: y + h * 0.62),
                control2: CGPoint(x: rect.midX - w * 0.05, y: y + h * 0.86)
            )
            path.addCurve(
                to: CGPoint(x: x + w, y: y + h * 0.30),
                control1: CGPoint(x: rect.midX + w * 0.05, y: y + h * 0.86),
                control2: CGPoint(x: x + w, y: y + h * 0.62)
            )
            path.addCurve(
                to: top,
                control1: CGPoint(x: x + w, y: y + h * 0.08),
                control2: CGPoint(x: rect.midX + w * 0.18, y: y)
            )
        }
        .stroke(color, style: stroke)
    }

    private func star(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        let points = 5
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = rect.width * 0.32
        let innerR = rect.width * 0.14

        return Path { path in
            for i in 0..<(points * 2) {
                let angle = (Double(i) * (Double.pi / Double(points))) - Double.pi / 2
                let r = (i % 2 == 0) ? outerR : innerR
                let p = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        .stroke(color, style: stroke)
    }

    private func cat(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            // Head
            Path { path in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22)
                // Ears
                let leftEar = CGPoint(x: head.minX + head.width * 0.18, y: head.minY + head.height * 0.06)
                let rightEar = CGPoint(x: head.maxX - head.width * 0.18, y: head.minY + head.height * 0.06)
                path.move(to: CGPoint(x: head.minX + head.width * 0.12, y: head.minY + head.height * 0.22))
                path.addLine(to: leftEar)
                path.addLine(to: CGPoint(x: head.minX + head.width * 0.34, y: head.minY + head.height * 0.22))
                path.move(to: CGPoint(x: head.maxX - head.width * 0.12, y: head.minY + head.height * 0.22))
                path.addLine(to: rightEar)
                path.addLine(to: CGPoint(x: head.maxX - head.width * 0.34, y: head.minY + head.height * 0.22))
                // Face outline
                path.addEllipse(in: head)
            }
            .stroke(color, style: stroke)

            // Eyes + nose
            Canvas { context, _ in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22)
                let eyeR: CGFloat = rect.width * 0.028
                let left = CGPoint(x: head.midX - head.width * 0.18, y: head.midY - head.height * 0.06)
                let right = CGPoint(x: head.midX + head.width * 0.18, y: head.midY - head.height * 0.06)
                context.fill(Path(ellipseIn: CGRect(x: left.x - eyeR, y: left.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(color))
                context.fill(Path(ellipseIn: CGRect(x: right.x - eyeR, y: right.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(color))
                let nose = CGPoint(x: head.midX, y: head.midY + head.height * 0.06)
                let noseR: CGFloat = rect.width * 0.018
                context.fill(Path(ellipseIn: CGRect(x: nose.x - noseR, y: nose.y - noseR, width: noseR * 2, height: noseR * 2)), with: .color(color))
            }

            // Whiskers
            Path { path in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22)
                let y = head.midY + head.height * 0.08
                for i in -1...1 {
                    let dy = CGFloat(i) * head.height * 0.06
                    path.move(to: CGPoint(x: head.midX - head.width * 0.06, y: y + dy))
                    path.addLine(to: CGPoint(x: head.minX - head.width * 0.10, y: y + dy - head.height * 0.02))
                    path.move(to: CGPoint(x: head.midX + head.width * 0.06, y: y + dy))
                    path.addLine(to: CGPoint(x: head.maxX + head.width * 0.10, y: y + dy - head.height * 0.02))
                }
            }
            .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func crown(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return Path { path in
            let w = rect.width * 0.72
            let h = rect.height * 0.48
            let x = rect.midX - w / 2
            let y = rect.midY - h / 2
            path.move(to: CGPoint(x: x, y: y + h))
            path.addLine(to: CGPoint(x: x + w * 0.12, y: y + h * 0.40))
            path.addLine(to: CGPoint(x: x + w * 0.28, y: y + h * 0.70))
            path.addLine(to: CGPoint(x: x + w * 0.50, y: y + h * 0.28))
            path.addLine(to: CGPoint(x: x + w * 0.72, y: y + h * 0.70))
            path.addLine(to: CGPoint(x: x + w * 0.88, y: y + h * 0.40))
            path.addLine(to: CGPoint(x: x + w, y: y + h))
            path.addLine(to: CGPoint(x: x, y: y + h))
            // Base band
            path.move(to: CGPoint(x: x, y: y + h))
            path.addLine(to: CGPoint(x: x + w, y: y + h))
        }
        .stroke(color, style: stroke)
        .overlay(
            Canvas { context, _ in
                let w = rect.width * 0.72
                let h = rect.height * 0.48
                let x = rect.midX - w / 2
                let y = rect.midY - h / 2
                let r: CGFloat = rect.width * 0.02
                let points = [
                    CGPoint(x: x + w * 0.12, y: y + h * 0.40),
                    CGPoint(x: x + w * 0.50, y: y + h * 0.28),
                    CGPoint(x: x + w * 0.88, y: y + h * 0.40),
                ]
                for p in points {
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
                }
            }
        )
    }

    private func lightning(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        return Path { path in
            let x = rect.midX
            let top = rect.minY + rect.height * 0.14
            let bottom = rect.maxY - rect.height * 0.14
            path.move(to: CGPoint(x: x + rect.width * 0.12, y: top))
            path.addLine(to: CGPoint(x: x - rect.width * 0.08, y: rect.midY - rect.height * 0.06))
            path.addLine(to: CGPoint(x: x + rect.width * 0.06, y: rect.midY - rect.height * 0.06))
            path.addLine(to: CGPoint(x: x - rect.width * 0.12, y: bottom))
            path.addLine(to: CGPoint(x: x + rect.width * 0.10, y: rect.midY + rect.height * 0.04))
            path.addLine(to: CGPoint(x: x - rect.width * 0.02, y: rect.midY + rect.height * 0.04))
            path.closeSubpath()
        }
        .stroke(color, style: stroke)
    }

    private func flower(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            // Petals
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * (Double.pi / 4)
                Path(ellipseIn: CGRect(
                    x: rect.midX - rect.width * 0.10,
                    y: rect.midY - rect.height * 0.34,
                    width: rect.width * 0.20,
                    height: rect.height * 0.30
                ))
                .stroke(color, style: stroke)
                .rotationEffect(.radians(angle), anchor: .center)
            }
            // Center
            Path(ellipseIn: rect.insetBy(dx: rect.width * 0.40, dy: rect.height * 0.40))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    private func rocket(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            // Body
            Path { path in
                let body = rect.insetBy(dx: rect.width * 0.34, dy: rect.height * 0.16)
                path.addRoundedRect(in: body, cornerSize: CGSize(width: body.width * 0.5, height: body.width * 0.5))
                // Nose cone
                path.move(to: CGPoint(x: body.midX, y: body.minY - rect.height * 0.10))
                path.addLine(to: CGPoint(x: body.minX, y: body.minY + body.height * 0.12))
                path.addLine(to: CGPoint(x: body.maxX, y: body.minY + body.height * 0.12))
                path.closeSubpath()
                // Fins
                path.move(to: CGPoint(x: body.minX, y: body.maxY - body.height * 0.08))
                path.addLine(to: CGPoint(x: body.minX - rect.width * 0.10, y: body.maxY))
                path.addLine(to: CGPoint(x: body.minX, y: body.maxY))
                path.move(to: CGPoint(x: body.maxX, y: body.maxY - body.height * 0.08))
                path.addLine(to: CGPoint(x: body.maxX + rect.width * 0.10, y: body.maxY))
                path.addLine(to: CGPoint(x: body.maxX, y: body.maxY))
            }
            .stroke(color, style: stroke)

            // Window + flames
            Canvas { context, _ in
                let body = rect.insetBy(dx: rect.width * 0.34, dy: rect.height * 0.16)
                let r = rect.width * 0.06
                let win = CGRect(x: body.midX - r, y: body.midY - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: win), with: .color(color), lineWidth: 2)
            }
            Path { path in
                let body = rect.insetBy(dx: rect.width * 0.34, dy: rect.height * 0.16)
                let baseY = body.maxY + rect.height * 0.02
                path.move(to: CGPoint(x: body.midX, y: baseY + rect.height * 0.14))
                path.addLine(to: CGPoint(x: body.midX - rect.width * 0.06, y: baseY))
                path.addLine(to: CGPoint(x: body.midX + rect.width * 0.06, y: baseY))
                path.closeSubpath()
            }
            .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func skull(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            // Skull outline
            Path { path in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.18)
                let top = CGRect(x: head.minX, y: head.minY, width: head.width, height: head.height * 0.68)
                path.addRoundedRect(in: top, cornerSize: CGSize(width: top.width * 0.35, height: top.width * 0.35))
                let jaw = CGRect(x: head.minX + head.width * 0.14, y: head.minY + head.height * 0.62, width: head.width * 0.72, height: head.height * 0.36)
                path.addRoundedRect(in: jaw, cornerSize: CGSize(width: jaw.width * 0.18, height: jaw.width * 0.18))
            }
            .stroke(color, style: stroke)

            // Eyes + nose
            Canvas { context, _ in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.18)
                let eyeW = head.width * 0.18
                let eyeH = head.height * 0.14
                let left = CGRect(x: head.midX - eyeW - head.width * 0.06, y: head.minY + head.height * 0.22, width: eyeW, height: eyeH)
                let right = CGRect(x: head.midX + head.width * 0.06, y: head.minY + head.height * 0.22, width: eyeW, height: eyeH)
                context.stroke(Path(roundedRect: left, cornerRadius: eyeW * 0.35), with: .color(color), lineWidth: 2)
                context.stroke(Path(roundedRect: right, cornerRadius: eyeW * 0.35), with: .color(color), lineWidth: 2)
                let nose = CGRect(x: head.midX - eyeW * 0.25, y: head.minY + head.height * 0.40, width: eyeW * 0.5, height: eyeH * 0.55)
                context.stroke(Path(roundedRect: nose, cornerRadius: eyeW * 0.18), with: .color(color), lineWidth: 2)
            }

            // Teeth
            Path { path in
                let head = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.18)
                let y = head.minY + head.height * 0.74
                let x1 = head.minX + head.width * 0.22
                let x2 = head.maxX - head.width * 0.22
                path.move(to: CGPoint(x: x1, y: y))
                path.addLine(to: CGPoint(x: x2, y: y))
                let step = (x2 - x1) / 5
                for i in 1..<5 {
                    let x = x1 + step * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: y - head.height * 0.06))
                    path.addLine(to: CGPoint(x: x, y: y + head.height * 0.08))
                }
            }
            .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }

    private func christmasTree(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            Path { path in
                let w = rect.width * 0.56
                let x = rect.midX - w / 2
                let top = rect.minY + rect.height * 0.14
                let mid = rect.midY
                let bottom = rect.maxY - rect.height * 0.20
                path.move(to: CGPoint(x: rect.midX, y: top))
                path.addLine(to: CGPoint(x: x + w * 0.15, y: mid - rect.height * 0.10))
                path.addLine(to: CGPoint(x: x + w * 0.28, y: mid - rect.height * 0.18))
                path.addLine(to: CGPoint(x: x, y: mid + rect.height * 0.02))
                path.addLine(to: CGPoint(x: x + w * 0.20, y: mid))
                path.addLine(to: CGPoint(x: x + w * 0.08, y: mid + rect.height * 0.18))
                path.addLine(to: CGPoint(x: x + w, y: mid + rect.height * 0.18))
                path.addLine(to: CGPoint(x: x + w * 0.88, y: mid))
                path.addLine(to: CGPoint(x: x + w, y: mid + rect.height * 0.02))
                path.addLine(to: CGPoint(x: x + w * 0.72, y: mid - rect.height * 0.18))
                path.addLine(to: CGPoint(x: x + w * 0.85, y: mid - rect.height * 0.10))
                path.closeSubpath()

                let trunk = CGRect(x: rect.midX - w * 0.10, y: bottom - rect.height * 0.02, width: w * 0.20, height: rect.height * 0.10)
                path.addRoundedRect(in: trunk, cornerSize: CGSize(width: trunk.width * 0.25, height: trunk.width * 0.25))
            }
            .stroke(color, style: stroke)

            // Star topper
            star(in: CGRect(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.06, width: rect.width * 0.20, height: rect.height * 0.20), color: color.opacity(0.9))
        }
    }

    private func butterfly(in rect: CGRect, color: Color) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            // Body
            Path { path in
                let body = CGRect(x: rect.midX - rect.width * 0.03, y: rect.midY - rect.height * 0.20, width: rect.width * 0.06, height: rect.height * 0.40)
                path.addRoundedRect(in: body, cornerSize: CGSize(width: body.width, height: body.width))
                // Antennae
                path.move(to: CGPoint(x: rect.midX, y: body.minY))
                path.addQuadCurve(to: CGPoint(x: rect.midX - rect.width * 0.12, y: body.minY - rect.height * 0.08), control: CGPoint(x: rect.midX - rect.width * 0.06, y: body.minY - rect.height * 0.10))
                path.move(to: CGPoint(x: rect.midX, y: body.minY))
                path.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.12, y: body.minY - rect.height * 0.08), control: CGPoint(x: rect.midX + rect.width * 0.06, y: body.minY - rect.height * 0.10))
            }
            .stroke(color, style: stroke)

            // Wings
            Path { path in
                let wingW = rect.width * 0.30
                let wingH = rect.height * 0.34
                let left = CGRect(x: rect.midX - wingW - rect.width * 0.05, y: rect.midY - wingH * 0.80, width: wingW, height: wingH)
                let right = CGRect(x: rect.midX + rect.width * 0.05, y: rect.midY - wingH * 0.80, width: wingW, height: wingH)
                path.addEllipse(in: left)
                path.addEllipse(in: right)

                let left2 = CGRect(x: rect.midX - wingW - rect.width * 0.02, y: rect.midY - wingH * 0.10, width: wingW * 0.92, height: wingH * 0.88)
                let right2 = CGRect(x: rect.midX + rect.width * 0.02, y: rect.midY - wingH * 0.10, width: wingW * 0.92, height: wingH * 0.88)
                path.addEllipse(in: left2)
                path.addEllipse(in: right2)
            }
            .stroke(color.opacity(0.95), style: stroke)
        }
    }
}

#if canImport(PencilKit)
private extension UIColor {
    struct RGBA {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
    }

    var doodlRGBA: RGBA? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBA(r: r, g: g, b: b, a: a)
    }
}
#endif

private extension DoodleCanvasView {
    func colorKey(_ color: UIColor) -> String? {
        guard let rgba = color.doodlRGBA else { return nil }
        let r = Int((rgba.r * 255).rounded())
        let g = Int((rgba.g * 255).rounded())
        let b = Int((rgba.b * 255).rounded())
        let a = Int((rgba.a * 255).rounded())
        return "\(r),\(g),\(b),\(a)"
    }

    func isAllowedFreeColor(_ color: UIColor) -> Bool {
        guard let key = colorKey(color) else { return false }
        let allowed = Set(freePalette.compactMap(colorKey))
        return allowed.contains(key)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    ZStack {
        LinearGradient(
            colors: [
                .doodlBackground,
                .doodlBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        Color.white.opacity(0.05).ignoresSafeArea()
        DoodleCanvasView(language: .english, onSend: { _ in
            try await Task.sleep(nanoseconds: 0)
        })
            .padding(16)
    }
    .environmentObject(PurchaseManager())
}
#endif
