import SwiftUI

/// Onboarding flow for first-time setup and permission requests
struct OnboardingView: View {
    @Environment(ConnectionState.self) private var connectionState
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var currentStep = 0
    
    private let totalSteps = 4
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .padding(.horizontal)
                .padding(.top)
            
            // Content based on current step
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep(onNext: nextStep)
                case 1:
                    PermissionsStep(permissionManager: permissionManager, onNext: nextStep, onBack: previousStep)
                case 2:
                    ConnectionStep(connectionState: connectionState, onNext: nextStep, onBack: previousStep)
                case 3:
                    CompleteStep(onFinish: completeOnboarding)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 450)
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }
    
    private func completeOnboarding() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.completeOnboarding()
        }
        dismissWindow(id: "onboarding")
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Welcome to GardenBridge")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("GardenBridge connects your Mac to the Clawdbot Gateway, enabling AI assistants to help you with:")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "calendar", text: "Calendar & Reminders")
                FeatureRow(icon: "person.2", text: "Contacts")
                FeatureRow(icon: "folder", text: "Files & Documents")
                FeatureRow(icon: "terminal", text: "System Commands")
                FeatureRow(icon: "photo", text: "Screen Capture & Camera")
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Button("Get Started") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
                .frame(height: 20)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStep: View {
    let permissionManager: PermissionManager
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Grant Permissions")
                .font(.title)
                .fontWeight(.bold)
            
            Text("GardenBridge needs certain permissions to help AI assistants interact with your Mac. You can grant permissions now or later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            ScrollView {
                VStack(spacing: 8) {
                    OnboardingPermissionRow(
                        name: "Calendar",
                        description: "Read and create calendar events",
                        status: permissionManager.calendarStatus,
                        action: { Task { await permissionManager.requestCalendarAccess() } }
                    )
                    
                    OnboardingPermissionRow(
                        name: "Contacts",
                        description: "Look up contact information",
                        status: permissionManager.contactsStatus,
                        action: { Task { await permissionManager.requestContactsAccess() } }
                    )
                    
                    OnboardingPermissionRow(
                        name: "Reminders",
                        description: "Read and create reminders",
                        status: permissionManager.remindersStatus,
                        action: { Task { await permissionManager.requestRemindersAccess() } }
                    )
                    
                    OnboardingPermissionRow(
                        name: "Accessibility",
                        description: "Control UI elements",
                        status: permissionManager.accessibilityStatus,
                        action: { permissionManager.openAccessibilitySettings() },
                        opensSettings: true
                    )
                    
                    OnboardingPermissionRow(
                        name: "Screen Recording",
                        description: "Capture screen content",
                        status: permissionManager.screenCaptureStatus,
                        action: { permissionManager.requestScreenCaptureAccess() },
                        opensSettings: true
                    )
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            
            Spacer()
            
            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Continue") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 40)
            
            Spacer()
                .frame(height: 20)
        }
        .padding()
    }
}

struct OnboardingPermissionRow: View {
    let name: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    var opensSettings: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if status == .authorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(opensSettings ? "Open Settings" : "Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Connection Step

struct ConnectionStep: View {
    let connectionState: ConnectionState
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        @Bindable var state = connectionState
        
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
            
            Text("Connect to Gateway")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Configure the connection to your Clawdbot Gateway. The default settings work for a local Gateway installation.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Host:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("127.0.0.1", text: $state.gatewayHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                
                HStack {
                    Text("Port:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("18789", value: $state.gatewayPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                
                Toggle("Auto-connect on launch", isOn: $state.autoConnect)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Continue") {
                    connectionState.saveSettings()
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 40)
            
            Spacer()
                .frame(height: 20)
        }
        .padding()
    }
}

// MARK: - Complete Step

struct CompleteStep: View {
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("GardenBridge is ready to connect to the Clawdbot Gateway. Look for the leaf icon in your menu bar to manage your connection.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "menubar.rectangle", text: "Click the menu bar icon to see connection status")
                TipRow(icon: "gear", text: "Use Settings to manage permissions")
                TipRow(icon: "arrow.clockwise", text: "The app will auto-reconnect if disconnected")
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Button("Finish Setup") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
                .frame(height: 20)
        }
        .padding()
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(ConnectionState())
        .environment(PermissionManager())
}
