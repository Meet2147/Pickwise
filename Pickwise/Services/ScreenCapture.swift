import Foundation
import AppKit

/// Interactive region capture via /usr/sbin/screencapture. Requires the
/// Screen Recording permission (NSScreenCaptureUsageDescription in Info.plist).
enum ScreenCapture {
    static func captureRegion() async throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickwise-\(UUID().uuidString).png")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i interactive, -x no sound, -r no dpi metadata, -t png
        proc.arguments = ["-i", "-x", "-r", "-t", "png", tmp.path]
        let errPipe = Pipe(); proc.standardError = errPipe
        do { try proc.run() } catch { throw AppError("Couldn't start screen capture", error: error) }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            proc.terminationHandler = { _ in c.resume() }
        }
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard proc.terminationStatus == 0 else {
            throw AppError("Screen capture failed", details: "screencapture exited \(proc.terminationStatus)\n\(stderr)")
        }
        guard let data = try? Data(contentsOf: tmp), !data.isEmpty else {
            // User pressed Esc — not an error worth shouting about, but still report it.
            throw AppError("Capture cancelled", details: "No image was produced. If you expected one, grant Screen Recording access in System Settings → Privacy & Security.\n\(stderr)")
        }
        guard NSImage(data: data) != nil else {
            throw AppError("Capture produced an unreadable image", details: "\(data.count) bytes\n\(stderr)")
        }
        return data
    }
}
