//
//  ZLKeychainService.swift
//  T-Squared for Georgia Tech
//
//  Sourced from Stack Overflow
//  http://stackoverflow.com/questions/25513106/trying-to-use-keychainitemwrapper-by-apple-translated-to-swift
//

import Foundation
import Security

let TSUsernameKey = "edu.gatech.cal.t-squared-username"
let TSPasswordKey = "edu.gatech.cal.t-squared-password"

class ZLKeychainService: NSObject {
    
    var service = "edu.gatech.cal.t-squared"
    var keychainQuery :[NSString: AnyObject]! = nil
    
    func save(name name: NSString, value: NSString) -> OSStatus? {
        let statusAdd :OSStatus?
        
        guard let dataFromString: NSData = value.dataUsingEncoding(NSUTF8StringEncoding) else {
            return nil
        }
        
        keychainQuery = [
            kSecClass       : kSecClassGenericPassword,
            kSecAttrService : service,
            kSecAttrAccount : name,
            kSecValueData   : dataFromString]
        if keychainQuery == nil {
            return nil
        }
        
        SecItemDelete(keychainQuery as CFDictionaryRef)
        
        statusAdd = SecItemAdd(keychainQuery! as CFDictionaryRef, nil)
        
        return statusAdd;
    }
    
    func load(name name: NSString) -> String? {
        var contentsOfKeychain :String?
        
        keychainQuery = [
            kSecClass       : kSecClassGenericPassword,
            kSecAttrService : service,
            kSecAttrAccount : name,
            kSecReturnData  : kCFBooleanTrue,
            kSecMatchLimit  : kSecMatchLimitOne]
        if keychainQuery == nil {
            return nil
        }
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        
        if (status == errSecSuccess) {
            let retrievedData: NSData? = dataTypeRef as? NSData
            if let result = NSString(data: retrievedData!, encoding: NSUTF8StringEncoding) {
                contentsOfKeychain = result as String
            }
        }
        else {
            print("Nothing was retrieved from the keychain. Status code \(status)")
        }
        
        return contentsOfKeychain
    }
}

func savedCredentials() -> (username: String, password: String)? {
    let keychain = ZLKeychainService()
    let username = keychain.load(name: TSUsernameKey as NSString)
    let password = keychain.load(name: TSPasswordKey as NSString)
    if let username = username, let password = password {
        if username == "_NIL" && password == "_NIL" { return nil }
        return (username, password)
    }
    return nil
}

func saveCredentials(username optUsername: String?, password optPassword: String?) {
    let username = (optUsername ?? "_NIL") as NSString
    let password = (optPassword ?? "_NIL") as NSString
    let keychain = ZLKeychainService()
    keychain.save(name: TSUsernameKey, value: username)
    keychain.save(name: TSPasswordKey, value: password)
}
