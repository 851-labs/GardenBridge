import Foundation
import CryptoKit
import Security

/// Manages device identity and cryptographic operations for gateway pairing
actor DeviceIdentity {
    private let keyTag = "com.851labs.GardenBridge.deviceKey"
    private var privateKey: P256.Signing.PrivateKey?
    private var deviceId: String?
    
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
        // Try to load existing key from keychain
        if let existingKey = loadKeyFromKeychain() {
            privateKey = existingKey
            deviceId = generateDeviceId(from: existingKey.publicKey)
            return
        }
        
        // Create new key and save to keychain
        let newKey = P256.Signing.PrivateKey()
        privateKey = newKey
        deviceId = generateDeviceId(from: newKey.publicKey)
        
        saveKeyToKeychain(newKey)
    }
    
    private func generateDeviceId(from publicKey: P256.Signing.PublicKey) -> String {
        let hash = SHA256.hash(data: publicKey.rawRepresentation)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    
    private func loadKeyFromKeychain() -> P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let keyData = item as? Data else {
            return nil
        }
        
        do {
            return try P256.Signing.PrivateKey(rawRepresentation: keyData)
        } catch {
            print("Failed to load key from keychain: \(error)")
            return nil
        }
    }
    
    private func saveKeyToKeychain(_ key: P256.Signing.PrivateKey) {
        let keyData = key.rawRepresentation
        
        // Delete any existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Save new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save key to keychain: \(status)")
        }
    }
}
