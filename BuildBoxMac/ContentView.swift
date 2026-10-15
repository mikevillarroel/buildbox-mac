import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var builder = IPABuilder()
    @State private var showingProjectPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("BuildBox Mac")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(6)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("XCODE PROJECT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: { showingProjectPicker = true }) {
                            HStack {
                                if let url = builder.projectURL {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Select project folder or drag it here…")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            if let provider = providers.first {
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    if let url = url {
                                        DispatchQueue.main.async {
                                            builder.selectProjectFolder(url)
                                        }
                                    }
                                }
                                return true
                            }
                            return false
                        }
                        Text("Pick the folder containing the .xcodeproj, or drag it here")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCHEME")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $builder.selectedScheme) {
                            ForEach(builder.schemes, id: \.self) { scheme in
                                Text(scheme).tag(scheme as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(builder.schemes.isEmpty)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        Task { await builder.build() }
                    }) {
                        HStack {
                            Spacer()
                            if builder.isBuilding {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text("Building…")
                            } else {
                                Image(systemName: "hammer.fill")
                                Text("Build Unsigned IPA")
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(builder.canBuild ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!builder.canBuild || builder.isBuilding)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BUILD LOG")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(builder.logOutput)
                                .font(.system(.body, design: .monospaced))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(height: 140)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    if let ipaURL = builder.resultIPA {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(ipaURL.lastPathComponent)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([ipaURL])
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "folder.fill")
                                        Text("Show in Finder")
                                        Spacer()
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    builder.clear()
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "trash.fill")
                                        Text("Clear")
                                        Spacer()
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if let error = builder.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ABOUT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image("profile")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Miguel Villarroel")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Developer")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Link(destination: URL(string: "https://x.com/GOT_MUNCH1ES")!) {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                }
                                Link(destination: URL(string: "https://instagram.com/mikevillarroel")!) {
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(LinearGradient(colors: [.orange, .red, .purple], startPoint: .leading, endPoint: .trailing))
                                        .clipShape(Circle())
                                }
                            }
                            
                            Divider()
                            
                            HStack(spacing: 12) {
                                Text("🤖")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("MikeBorg")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Collaborator")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        
                        HStack(spacing: 12) {
                            Spacer()
                            Link(destination: URL(string: "https://paypal.me/mikevillarroel")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                    Text("PayPal")
                                }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0, green: 0.44, blue: 0.73))
                                    .cornerRadius(10)
                            }
                            Link(destination: URL(string: "https://cash.app/$mikevillarroel")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.square.fill")
                                    Text("Cash App")
                                }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingProjectPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                builder.selectProjectFolder(url)
            }
        }
    }
}
