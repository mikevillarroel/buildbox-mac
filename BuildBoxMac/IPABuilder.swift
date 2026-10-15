import Foundation
import SwiftUI

@MainActor
class IPABuilder: ObservableObject {
    @Published var projectURL: URL?
    @Published var schemes: [String] = []
    @Published var selectedScheme: String?
    @Published var isBuilding = false
    @Published var logOutput = ""
    @Published var resultIPA: URL?
    @Published var errorMessage: String?
    
    var canBuild: Bool {
        projectURL != nil && selectedScheme != nil && !isBuilding
    }
    
    func selectProjectFolder(_ url: URL) {
        var projectFile: URL?
        
        if url.pathExtension == "xcodeproj" {
            projectFile = url
        } else {
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil
            ) {
                projectFile = contents.first(where: { $0.pathExtension == "xcodeproj" })
            }
        }
        
        guard let proj = projectFile else {
            errorMessage = "No .xcodeproj found in selected folder"
            log("✗ No .xcodeproj found in \(url.lastPathComponent)")
            return
        }
        
        projectURL = proj
        selectedScheme = nil
        schemes = []
        resultIPA = nil
        errorMessage = nil
        log("Selected: \(proj.lastPathComponent)")
        loadSchemes()
    }
    
    private func loadSchemes() {
        guard let project = projectURL else { return }
        Task {
            let output = await runProcess(
                "/usr/bin/xcodebuild",
                args: ["-project", project.path, "-list", "-json"]
            )
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let proj = json["project"] as? [String: Any],
               let schemeList = proj["schemes"] as? [String] {
                await MainActor.run {
                    self.schemes = schemeList
                    self.selectedScheme = schemeList.first
                    self.log("Found \(schemeList.count) scheme(s)")
                }
            } else {
                await MainActor.run {
                    self.log("Could not list schemes")
                }
            }
        }
    }
    
    func build() async {
        guard let project = projectURL,
              let scheme = selectedScheme else { return }
        
        isBuilding = true
        errorMessage = nil
        resultIPA = nil
        logOutput = ""
        
        let appName = project.deletingPathExtension().lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuildBoxMac-\(UUID().uuidString)")
        let archivePath = tempDir.appendingPathComponent("\(appName).xcarchive")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            fail("Could not create temp dir: \(error.localizedDescription)")
            return
        }
        
        log("$ xcodebuild -project \(project.lastPathComponent)")
        log("  -scheme \(scheme) -configuration Release archive")
        log("  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO")
        log("")
        
        let _ = await runProcess(
            "/usr/bin/xcodebuild",
            args: [
                "-project", project.path,
                "-scheme", scheme,
                "-configuration", "Release",
                "-archivePath", archivePath.path,
                "archive",
                "CODE_SIGNING_REQUIRED=NO",
                "CODE_SIGNING_ALLOWED=NO"
            ],
            logLive: true
        )
        
        let productsPath = archivePath
            .appendingPathComponent("Products/Applications")
        
        guard let appURL = try? FileManager.default
            .contentsOfDirectory(at: productsPath, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            fail("Archive did not produce a .app bundle")
            return
        }
        
        log("")
        log("▸ Archive produced: \(appURL.lastPathComponent)")
        
        var versionSuffix = ""
        let infoPlist = appURL.appendingPathComponent("Info.plist")
        if let plistData = try? Data(contentsOf: infoPlist),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let version = plist["CFBundleShortVersionString"] as? String,
           !version.isEmpty {
            versionSuffix = "-v\(version)"
            log("▸ Version: \(version)")
        }
        
        let payloadDir = tempDir.appendingPathComponent("Payload")
        let ipaName = "\(appName)\(versionSuffix).ipa"
        let ipaURL = tempDir.appendingPathComponent(ipaName)
        
        do {
            try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: appURL,
                to: payloadDir.appendingPathComponent(appURL.lastPathComponent)
            )
            
            log("▸ Packaging \(ipaName)…")
            
            let _ = await runProcess(
                "/usr/bin/zip",
                args: ["-qr", ipaURL.path, "Payload"],
                workingDirectory: tempDir
            )
            
            let desktopIPA = FileManager.default
                .urls(for: .desktopDirectory, in: .userDomainMask).first?
                .appendingPathComponent(ipaName)
            
            if let desktopIPA = desktopIPA {
                if FileManager.default.fileExists(atPath: desktopIPA.path) {
                    try? FileManager.default.removeItem(at: desktopIPA)
                }
                try FileManager.default.moveItem(at: ipaURL, to: desktopIPA)
                
                let size = (try? FileManager.default
                    .attributesOfItem(atPath: desktopIPA.path)[.size] as? Int) ?? 0
                let sizeMB = Double(size) / 1_000_000
                
                log("")
                log("✓ \(ipaName) ready — \(String(format: "%.1f", sizeMB)) MB")
                log("  No signature, no UDID, no provisioning profile")
                log("  Saved to Desktop")
                
                resultIPA = desktopIPA
            } else {
                resultIPA = ipaURL
                log("✓ \(ipaName) ready")
            }
            
        } catch {
            fail("Packaging failed: \(error.localizedDescription)")
            return
        }
        
        isBuilding = false
    }
    
    private func fail(_ message: String) {
        errorMessage = message
        log("✗ \(message)")
        isBuilding = false
    }
    
    func clear() {
        projectURL = nil
        schemes = []
        selectedScheme = nil
        logOutput = ""
        resultIPA = nil
        errorMessage = nil
    }
    
    private func log(_ message: String) {
        logOutput += message + "\n"
    }
    
    private func runProcess(
        _ executable: String,
        args: [String],
        workingDirectory: URL? = nil,
        logLive: Bool = false
    ) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args
                if let wd = workingDirectory {
                    process.currentDirectoryURL = wd
                }
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                let outputData = NSMutableData()
                
                if logLive {
                    pipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if data.count > 0 {
                            outputData.append(data)
                            if let str = String(data: data, encoding: .utf8) {
                                let lines = str.components(separatedBy: .newlines)
                                for line in lines {
                                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                                    if trimmed.contains("error:") ||
                                       trimmed.contains("warning:") ||
                                       trimmed.hasPrefix("▸") ||
                                       trimmed.hasPrefix("** ") {
                                        Task { @MainActor in
                                            self.logOutput += trimmed + "\n"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    Task { @MainActor in
                        self.log("Process failed: \(error.localizedDescription)")
                    }
                }
                
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                outputData.append(remaining)
                
                let output = String(data: outputData as Data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }
}
