import XCTest

class SecurityHelper {
    func verify(url: URL) {
        let checkFlags = SecCSFlags(rawValue: kSecCSCheckNestedCode)

        var staticCode: SecStaticCode?
        var err: OSStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        XCTAssertEqual(err, noErr)
        XCTAssertNotNil(staticCode)

        let requirement: SecRequirement? = nil
        var error: Unmanaged<CFError>?
        err = SecStaticCodeCheckValidityWithErrors(staticCode!,
                                                   checkFlags,
                                                   requirement,
                                                   &error)
        XCTAssertNil(error)
        XCTAssertEqual(err, errSecSuccess)
        
        var secCodeInfoCFDict:  CFDictionary?
        let codeSigning = SecCSFlags(rawValue: kSecCSSigningInformation)
        err = SecCodeCopySigningInformation(
            staticCode!, codeSigning, &secCodeInfoCFDict
        )
        XCTAssertEqual(err, errSecSuccess)
        XCTAssertNotNil(secCodeInfoCFDict)
        let signature = secCodeInfoCFDict as? [String: Any]
        XCTAssertNotNil(signature)
        verify(codeSign: signature!)
        let executable = signature!["main-executable"] as? URL
        XCTAssertNotNil(executable)
        XCTAssertEqual(executable, url.appendingPathComponent("/Contents/MacOS/SpartaConnect"))
    }
    
    func verify(codeSign: [String: Any]) {
        let date = codeSign["signing-time"] as? Date
        XCTAssertGreaterThan(date!, DateComponents(calendar: Calendar(identifier: .gregorian), year: 2020, month: 06, day: 1).date!)
        XCTAssertEqual("com.spartascience.SpartaConnect", codeSign["identifier"] as? String)
        XCTAssertEqual("GB9B5L6A6K", codeSign["teamid"] as? String)
    }
}
