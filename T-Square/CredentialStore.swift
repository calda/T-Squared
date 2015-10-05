//
//  CryptoStore.swift
//  T-Square
//
//  Created by Cal on 10/3/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import CryptoSwift

//Key (key.secure) and IV (IV.secure) are 16-byte UTF8 strings used to encrypt and decrypt user credentials.
//These files should never be commited to a public repository, as that would compromise the security of the encryption.
//If the keys are lost, some transition strategy will be necessary. (The app crashes when attempting to decrypt with an invalid key.)

var SECURE_KEY: [UInt8] {
    get {
        let keyPath = NSBundle.mainBundle().pathForResource("key", ofType: "secure")!
        let key = try! NSString(contentsOfFile: keyPath, encoding: NSUTF8StringEncoding) as String
        return Array(key.utf8)
    }
}

var SECURE_IV: [UInt8] {
    get {
        let IVPath = NSBundle.mainBundle().pathForResource("IV", ofType: "secure")!
        let IV = try! NSString(contentsOfFile: IVPath, encoding: NSUTF8StringEncoding) as String
        return Array(IV.utf8)
    }
}

func encryptString(string: String) -> NSData {
    let data = Array(string.utf8)
    
    let key = SECURE_KEY
    let iv = SECURE_IV
    
    let encrypted = try! AES(key: key, iv: iv, blockMode: .CBC)?.encrypt(data, padding: PKCS7())
    return NSData(bytes: encrypted!, length: encrypted!.count)
}

func decryptData(data: NSData) -> String {
    let key = SECURE_KEY
    let iv = SECURE_IV
    
    //convert data to byte array
    let count = data.length / sizeof(UInt8)
    var bytes = [UInt8](count: count, repeatedValue: 0)
    data.getBytes(&bytes, length: data.length)
    
    let decrypted = try! AES(key: key, iv: iv, blockMode: .CBC)?.decrypt(bytes, padding: PKCS7())
    
    //convert bytes to string
    let string = NSString(bytes: decrypted!, length: decrypted!.count, encoding: NSUTF8StringEncoding)!
    return string as String
}

func savedCredentials() -> (username: String, password: String)? {
    if let usernameData = NSUserDefaults.standardUserDefaults().dataForKey(TSUsernamePath),
       let passwordData = NSUserDefaults.standardUserDefaults().dataForKey(TSPasswordPath) {
            return (decryptData(usernameData), decryptData(passwordData))
    }
    return nil
}
