//
//  MessageEncryptionService.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import Foundation
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import Security

enum MessageEncryptionError: Error {
    case missingCurrentUser
    case missingRecipientPublicKey(String)
    case missingEncryptedContent
    case missingWrappedKey
    case invalidBase64
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
}

struct EncryptedMessagePayload {
    let encryptedContent: String
    let encryptedReplyingToText: String?
    let encryptedMessageKeys: [String: String]
    let senderPublicKey: String
    let encryptionVersion: Int
    let encryptionScheme: String
}

struct EncryptedAttachmentPayload {
    let encryptedData: Data
    let encryptedMessageKeys: [String: String]
    let senderPublicKey: String
    let encryptionVersion: Int
    let encryptionScheme: String
}

actor MessageEncryptionService {
    private let database = Firestore.firestore()
    private let keychainService = "com.bubble.message-encryption"
    private let encryptionVersion = 1
    private let encryptionScheme = "cryptokit-curve25519-aesgcm-v1"

    func ensureCurrentUserPublicKeyIsPublished() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }

        let publicKey = try currentPrivateKey().publicKey.rawRepresentation.base64EncodedString()
        let userRef = database.collection("users").document(uid)
        let snapshot = try await userRef.getDocument()

        if snapshot.data()?["encryptionPublicKey"] as? String != publicKey {
            try await userRef.setData(["encryptionPublicKey": publicKey], merge: true)
        }
    }

    func encryptText(
        _ text: String,
        replyingToText: String? = nil,
        chatID: String,
        messageID: String,
        participantIDs: [String]
    ) async throws -> EncryptedMessagePayload {
        guard let senderID = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }

        try await ensureCurrentUserPublicKeyIsPublished()

        let recipients = Array(Set(participantIDs + [senderID]))
        let messageKey = SymmetricKey(size: .bits256)
        let contentData = Data(text.utf8)
        let contentAAD = authenticatedData(kind: "content", chatID: chatID, messageID: messageID, senderID: senderID)
        let sealedContent = try AES.GCM.seal(contentData, using: messageKey, authenticating: contentAAD)
        guard let combinedContent = sealedContent.combined else {
            throw MessageEncryptionError.missingEncryptedContent
        }

        let encryptedReplyingToText: String?
        if let replyingToText, !replyingToText.isEmpty {
            let replyAAD = authenticatedData(kind: "replying-to-text", chatID: chatID, messageID: messageID, senderID: senderID)
            let sealedReply = try AES.GCM.seal(Data(replyingToText.utf8), using: messageKey, authenticating: replyAAD)
            guard let combinedReply = sealedReply.combined else {
                throw MessageEncryptionError.missingEncryptedContent
            }
            encryptedReplyingToText = combinedReply.base64EncodedString()
        } else {
            encryptedReplyingToText = nil
        }

        let wrappedKeyPayload = try await wrapMessageKey(
            messageKey,
            recipients: recipients,
            chatID: chatID,
            messageID: messageID,
            senderID: senderID
        )

        return EncryptedMessagePayload(
            encryptedContent: combinedContent.base64EncodedString(),
            encryptedReplyingToText: encryptedReplyingToText,
            encryptedMessageKeys: wrappedKeyPayload.encryptedKeys,
            senderPublicKey: wrappedKeyPayload.senderPublicKey,
            encryptionVersion: encryptionVersion,
            encryptionScheme: encryptionScheme
        )
    }

    func encryptAttachmentData(
        _ data: Data,
        chatID: String,
        messageID: String,
        participantIDs: [String]? = nil
    ) async throws -> EncryptedAttachmentPayload {
        guard let senderID = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }

        try await ensureCurrentUserPublicKeyIsPublished()

        let participants: [String]
        if let participantIDs {
            participants = participantIDs
        } else {
            let chatSnapshot = try await database.collection("chats").document(chatID).getDocument()
            participants = chatSnapshot.data()?["participants"] as? [String] ?? []
        }
        let recipients = Array(Set(participants + [senderID]))
        let attachmentKey = SymmetricKey(size: .bits256)
        let aad = authenticatedData(kind: "attachment-data", chatID: chatID, messageID: messageID, senderID: senderID)
        let sealedData = try AES.GCM.seal(data, using: attachmentKey, authenticating: aad)
        guard let encryptedData = sealedData.combined else {
            throw MessageEncryptionError.missingEncryptedContent
        }

        let wrappedKeyPayload = try await wrapMessageKey(
            attachmentKey,
            recipients: recipients,
            chatID: chatID,
            messageID: messageID,
            senderID: senderID
        )

        return EncryptedAttachmentPayload(
            encryptedData: encryptedData,
            encryptedMessageKeys: wrappedKeyPayload.encryptedKeys,
            senderPublicKey: wrappedKeyPayload.senderPublicKey,
            encryptionVersion: encryptionVersion,
            encryptionScheme: encryptionScheme
        )
    }

    func decryptAttachmentData(_ data: Data, message: MessageModel, chatID: String) throws -> Data {
        let attachmentKey = try unwrapMessageKey(for: message, chatID: chatID)
        let aad = authenticatedData(kind: "attachment-data", chatID: chatID, messageID: message.id, senderID: message.senderUserID)
        let sealedData = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedData, using: attachmentKey, authenticating: aad)
    }

    func decrypt(_ message: MessageModel, chatID: String) throws -> MessageModel {
        guard message.encryptionVersion == encryptionVersion else { return message }
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }
        guard let encryptedContent = message.encryptedContent,
              let encryptedContentData = Data(base64Encoded: encryptedContent) else {
            throw MessageEncryptionError.invalidBase64
        }
        guard let wrappedKey = message.encryptedMessageKeys?[currentUserID],
              let wrappedKeyData = Data(base64Encoded: wrappedKey) else {
            throw MessageEncryptionError.missingWrappedKey
        }
        let messageKey = try unwrapMessageKey(
            wrappedKeyData: wrappedKeyData,
            currentUserID: currentUserID,
            message: message,
            chatID: chatID
        )

        let contentAAD = authenticatedData(kind: "content", chatID: chatID, messageID: message.id, senderID: message.senderUserID)
        let sealedContent = try AES.GCM.SealedBox(combined: encryptedContentData)
        let decryptedData = try AES.GCM.open(sealedContent, using: messageKey, authenticating: contentAAD)
        let decryptedText = String(decoding: decryptedData, as: UTF8.self)

        var decryptedReplyingToText: String?
        if let encryptedReplyingToText = message.encryptedReplyingToText,
           let encryptedReplyingToTextData = Data(base64Encoded: encryptedReplyingToText) {
            let replyAAD = authenticatedData(kind: "replying-to-text", chatID: chatID, messageID: message.id, senderID: message.senderUserID)
            let sealedReply = try AES.GCM.SealedBox(combined: encryptedReplyingToTextData)
            let decryptedReplyData = try AES.GCM.open(sealedReply, using: messageKey, authenticating: replyAAD)
            decryptedReplyingToText = String(decoding: decryptedReplyData, as: UTF8.self)
        }

        var decryptedMessage = message
        decryptedMessage.content = decryptedText
        if let decryptedReplyingToText {
            decryptedMessage.replyingToText = decryptedReplyingToText
        }
        return decryptedMessage
    }

    private func wrapMessageKey(
        _ messageKey: SymmetricKey,
        recipients: [String],
        chatID: String,
        messageID: String,
        senderID: String
    ) async throws -> (encryptedKeys: [String: String], senderPublicKey: String) {
        let recipientPublicKeys = try await fetchPublicKeys(for: recipients)
        let messageKeyData = messageKey.withUnsafeBytes { Data($0) }
        let privateKey = try currentPrivateKey()
        var encryptedKeys: [String: String] = [:]

        for recipientID in recipients {
            guard let publicKeyString = recipientPublicKeys[recipientID],
                  let publicKeyData = Data(base64Encoded: publicKeyString) else {
                throw MessageEncryptionError.missingRecipientPublicKey(recipientID)
            }

            let recipientPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
            let wrappingKey = try wrappingKey(
                privateKey: privateKey,
                peerPublicKey: recipientPublicKey,
                senderID: senderID,
                recipientID: recipientID
            )
            let keyAAD = authenticatedData(kind: "message-key", chatID: chatID, messageID: messageID, senderID: senderID, recipientID: recipientID)
            let sealedKey = try AES.GCM.seal(messageKeyData, using: wrappingKey, authenticating: keyAAD)
            guard let combinedKey = sealedKey.combined else {
                throw MessageEncryptionError.missingWrappedKey
            }
            encryptedKeys[recipientID] = combinedKey.base64EncodedString()
        }

        return (encryptedKeys, privateKey.publicKey.rawRepresentation.base64EncodedString())
    }

    private func unwrapMessageKey(for message: MessageModel, chatID: String) throws -> SymmetricKey {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }
        guard let wrappedKey = message.encryptedMessageKeys?[currentUserID],
              let wrappedKeyData = Data(base64Encoded: wrappedKey) else {
            throw MessageEncryptionError.missingWrappedKey
        }

        return try unwrapMessageKey(
            wrappedKeyData: wrappedKeyData,
            currentUserID: currentUserID,
            message: message,
            chatID: chatID
        )
    }

    private func unwrapMessageKey(
        wrappedKeyData: Data,
        currentUserID: String,
        message: MessageModel,
        chatID: String
    ) throws -> SymmetricKey {
        guard let senderPublicKeyString = message.senderPublicKey,
              let senderPublicKeyData = Data(base64Encoded: senderPublicKeyString) else {
            throw MessageEncryptionError.invalidBase64
        }

        let senderPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderPublicKeyData)
        let privateKey = try currentPrivateKey()
        let wrappingKey = try wrappingKey(
            privateKey: privateKey,
            peerPublicKey: senderPublicKey,
            senderID: message.senderUserID,
            recipientID: currentUserID
        )

        let keyAAD = authenticatedData(kind: "message-key", chatID: chatID, messageID: message.id, senderID: message.senderUserID, recipientID: currentUserID)
        let sealedKey = try AES.GCM.SealedBox(combined: wrappedKeyData)
        let messageKeyData = try AES.GCM.open(sealedKey, using: wrappingKey, authenticating: keyAAD)
        return SymmetricKey(data: messageKeyData)
    }

    private func fetchPublicKeys(for userIDs: [String]) async throws -> [String: String] {
        var keys: [String: String] = [:]

        for userID in userIDs {
            let snapshot = try await database.collection("users").document(userID).getDocument()
            if let key = snapshot.data()?["encryptionPublicKey"] as? String {
                keys[userID] = key
            }
        }

        return keys
    }

    private func wrappingKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey,
        senderID: String,
        recipientID: String
    ) throws -> SymmetricKey {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("BubbleMessageEncryptionSaltV1".utf8),
            sharedInfo: Data("sender:\(senderID)|recipient:\(recipientID)".utf8),
            outputByteCount: 32
        )
    }

    private func authenticatedData(kind: String, chatID: String, messageID: String, senderID: String, recipientID: String? = nil) -> Data {
        var parts = [
            "scheme=\(encryptionScheme)",
            "kind=\(kind)",
            "chatID=\(chatID)",
            "messageID=\(messageID)",
            "senderID=\(senderID)"
        ]

        if let recipientID {
            parts.append("recipientID=\(recipientID)")
        }

        return Data(parts.joined(separator: "|").utf8)
    }

    private func currentPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw MessageEncryptionError.missingCurrentUser
        }

        if let data = try readPrivateKeyData(for: uid) {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try storePrivateKeyData(privateKey.rawRepresentation, for: uid)
        return privateKey
    }

    private func readPrivateKeyData(for userID: String) throws -> Data? {
        let query = keychainQuery(for: userID).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { current, _ in current }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw MessageEncryptionError.keychainReadFailed(status)
        }

        return result as? Data
    }

    private func storePrivateKeyData(_ data: Data, for userID: String) throws {
        let baseQuery = keychainQuery(for: userID)
        SecItemDelete(baseQuery as CFDictionary)

        let item = baseQuery.merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { current, _ in current }

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MessageEncryptionError.keychainWriteFailed(status)
        }
    }

    private func keychainQuery(for userID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "message-key-agreement-\(userID)"
        ]
    }
}
