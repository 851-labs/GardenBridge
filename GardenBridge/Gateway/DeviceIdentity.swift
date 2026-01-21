import Foundation
import CryptoKit

/// Manages device identity and cryptographic operations for gateway pairing
/// Uses file-based storage in Application Support to avoid Keychain permission prompts
actor DeviceIdentity {
    private var privateKey: P256.Signing.PrivateKey?
    private var deviceId: String?
    
    private var keyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("GardenBridge", isDirectory: true)
        return appDir.appendingPathComponent(".device_key")
    }
    
    init() {
        Task {
            await loadOrCreateIdentity()
        }
    }
    
    /// Gets the device ID (fingerprint of public key)
    func getDeviceId() async -> String {
        if let id = deviceId {
            return id
        }
        await loadOrCreateIdentity()
        return deviceId ?? UUID().uuidString
    }
    
    /// Gets the public key as base64 string
    func getPublicKey() async -> String? {
        guard let privateKey = privateKey else {
            await loadOrCreateIdentity()
            return self.privateKey?.publicKey.rawRepresentation.base64EncodedString()
        }
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }
    
    /// Signs a message (nonce + timestamp) for challenge response
    func sign(nonce: String, timestamp: Int64) async -> (signature: String, signedAt: Int64)? {
        guard let privateKey = privateKey else {
            return nil
        }
        
        let message = "\(nonce):\(timestamp)"
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        
        do {
            let signature = try privateKey.signature(for: messageData)
            return (signature.rawRepresentation.base64EncodedString(), timestamp)
        } catch {
            print("Failed to sign message: \(error)")
            return nil
        }
    }
    
    /// Creates DeviceInfo for connect request
    func createDeviceInfo(nonce: String? = nil, timestamp: Int64? = nil) async -> DeviceInfo {
        let id = await getDeviceId()
        let publicKey = await getPublicKey()
        
        var signature: String?
        var signedAt: Int64?
        var signedNonce: String?
        
        if let nonce = nonce, let ts = timestamp {
            if let signed = await sign(nonce: nonce, timestamp: ts) {
                signature = signed.signature
                signedAt = signed.signedAt
                signedNonce = nonce
            }
        }
        
        return DeviceInfo(
            id: id,
            publicKey: publicKey,
            signature: signature,
            signedAt: signedAt,
            nonce: signedNonce
        )
    }
    
    // MARK: - Private Methods
    
    private func loadOrCreateIdentity() async {
        // Try to load existing key from file
        if let existingKey = loadKeyFromFile() {
            privateKey = existingKey
            deviceId = generateDeviceId(from: existingKey.publicKey)
            return
        }
        
        // Create new key and save to file
        let newKey = P256.Signing.PrivateKey()
        privateKey = newKey
        deviceId = generateDeviceId(from: newKey.publicKey)
        
        saveKeyToFile(newKey)
    }
    
    private func generateDeviceId(from publicKey: P256.Signing.PublicKey) -> String {
        let hash = SHA256.hash(data: publicKey.rawRepresentation)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    
    private func loadKeyFromFile() -> P256.Signing.PrivateKey? {
        do {
            let keyData = try Data(contentsOf: keyFileURL)
            return try P256.Signing.PrivateKey(rawRepresentation: keyData)
        } catch {
            // File doesn't exist or key is invalid
            return nil
        }
    }
    
    private func saveKeyToFile(_ key: P256.Signing.PrivateKey) {
        let keyData = key.rawRepresentation
        
        do {
            // Create directory if needed
            let directory = keyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Write key data with restricted permissions
            try keyData.write(to: keyFileURL, options: [.atomic, .completeFileProtection])
            
            // Set file to be hidden and owner-only readable
            try FileManager.default.setAttributes([
                .posixPermissions: 0o600
            ], ofItemAtPath: keyFileURL.path)
        } catch {
            print("Failed to save key to file: \(error)")
        }
    }
}
