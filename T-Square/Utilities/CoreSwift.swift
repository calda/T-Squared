//  CoreSwift.swift
//
//  A collection of core Swift functions and classes
//  Copyright (c) 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import UIKit.UIGestureRecognizerSubclass

//MARK: - Functions

///perform the closure function after a given delay
func delay(_ delay: Double, closure: @escaping ()->()) {
    let time = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter(deadline: time, execute: closure)
}

///play a CATransition for a UIView
func playTransitionForView(_ view: UIView, duration: Double, transition transitionName: String, subtype: String? = nil, timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)) {
    let transition = CATransition()
    transition.duration = duration
    transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
    transition.type = transitionName
    
    //run fix for transition subtype
    //subtypes don't take device orientation into account
    //let orientation = UIApplication.sharedApplication().statusBarOrientation
    //if orientation == .LandscapeLeft || orientation == .PortraitUpsideDown {
    //if subtype == kCATransitionFromLeft { subtype = kCATransitionFromRight }
    //else if subtype == kCATransitionFromRight { subtype = kCATransitionFromLeft }
    //else if subtype == kCATransitionFromTop { subtype = kCATransitionFromBottom }
    //else if subtype == kCATransitionFromBottom { subtype = kCATransitionFromTop }
    //}
    
    transition.subtype = subtype
    transition.timingFunction = timingFunction
    view.layer.add(transition, forKey: nil)
}

///dimiss a stack of View Controllers until a desired controler is found
func dismissController(_ controller: UIViewController, untilMatch controllerCheck: @escaping (UIViewController) -> Bool) {
    if controllerCheck(controller) {
        return //we made it to our destination
    }
    
    let superController = controller.presentingViewController
    controller.dismiss(animated: false, completion: {
        if let superController = superController {
            dismissController(superController, untilMatch: controllerCheck)
        }
    })
}

///get the top most view controller of the current Application
func getTopController(_ application: UIApplicationDelegate) -> UIViewController? {
    //find the top controller
    var topController: UIViewController?
    
    if let window = application.window, let root = window!.rootViewController {
        topController = root
        while topController!.presentedViewController != nil {
            topController = topController!.presentedViewController
        }
    }
    
    return topController
}

///sorts any [UIView]! by view.tag
func sortOutletCollectionByTag<T : UIView>(_ collection: inout [T]!) {
    collection = (collection as NSArray).sortedArray(using: [NSSortDescriptor(key: "tag", ascending: true)]) as! [T]
}


///animates a back and forth shake
func shakeView(_ view: UIView) {
    let animations : [CGFloat] = [20.0, -20.0, 10.0, -10.0, 3.0, -3.0, 0]
    for i in 0 ..< animations.count {
        let frameOrigin = CGPoint(x: view.frame.origin.x + animations[i], y: view.frame.origin.y)
        
        UIView.animate(withDuration: 0.1, delay: TimeInterval(0.1 * Double(i)), options: [], animations: {
            view.frame.origin = frameOrigin
            }, completion: nil)
    }
}


///converts a String dictionary to a String array
func dictToArray(_ dict: [String : String]) -> [String] {
    var array: [String] = []
    
    for item in dict {
        let first = item.0.replacingOccurrences(of: "~", with: "|(#)|", options: [], range: nil)
        let second = item.1.replacingOccurrences(of: "~", with: "|(#)|", options: [], range: nil)
        let combined = "\(first)~\(second)"
        array.append(combined)
    }
    
    return array
}

///converts an array created by the dictToArray: function to the original dictionary
func arrayToDict(_ array: [String]) -> [String : String] {
    var dict: [String : String] = [:]
    
    for item in array {
        let splits = item.components(separatedBy: "~")
        let first = splits[0].replacingOccurrences(of: "|(#)|", with: "~", options: [], range: nil)
        let second = splits[1].replacingOccurrences(of: "|(#)|", with: "~", options: [], range: nil)
        dict.updateValue(second, forKey: first)
    }
    
    return dict
}


///short-form function to run a block synchronously on the main queue
func sync(_ closure: () -> ()) {
    DispatchQueue.main.sync(execute: closure)
}

///short-form function to run a block asynchronously on the main queue
func async(_ closure: @escaping () -> ()) {
    DispatchQueue.main.async(execute: closure)
}


///open to this app's iOS Settings
func openSettings() {
    UIApplication.shared.openURL(URL(string:UIApplicationOpenSettingsURLString)!)
}


///returns trus if the current device is an iPad
func iPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad
}

///returns trus if the current device is an iPhone 4S
func is4S() -> Bool {
    return UIScreen.main.bounds.height == 480.0
}


///a more succinct function call to post a notification
func postNotification(_ name: String, object: AnyObject?) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: name), object: object, userInfo: nil)
}

///Asynchonrously ownsamples the image view's image to match the view's size
func downsampleImageInView(_ imageView: UIImageView) {
    async() {
        let newSize = imageView.frame.size
        let screenScale = UIScreen.main.scale
        let scaleSize = CGSize(width: newSize.width * screenScale, height: newSize.height * screenScale)
        
        if let original = imageView.image, original.size.width > scaleSize.width {
            UIGraphicsBeginImageContext(scaleSize)
            let context = UIGraphicsGetCurrentContext()
            //CGContextSetInterpolationQuality(context, kCGInterpolationHigh)
            context!.setShouldAntialias(true)
            original.draw(in: CGRect(origin: CGPoint.zero, size: scaleSize))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            DispatchQueue.main.async(execute: {
                imageView.image = newImage
            })
        }
    }
}

///Converts a URL to a CSV into an array of all of the lines in the CSV.
func csvToArray(_ url: URL) -> [String] {
    let string = try! String(contentsOf: url, encoding: String.Encoding.utf8)
    return string.components(separatedBy: "\r\n")
}


///Crops an image to a circle (if square) or an oval (if rectangular)
func cropImageToCircle(_ image: UIImage) -> UIImage {
    UIGraphicsBeginImageContext(image.size)
    let context = UIGraphicsGetCurrentContext()
    
    let radius = image.size.width / 2
    let imageCenter = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
    context!.beginPath()
    context?.addArc(center: CGPoint.init(x: imageCenter.x, y: imageCenter.y), radius: radius, startAngle: 0, endAngle: CGFloat(2 * CGFloat.pi), clockwise: false)
    context!.closePath()
    context!.clip()
    
    context!.scaleBy(x: image.scale, y: image.scale)
    image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
    
    let cropped = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return cropped!
}

///Determines the height required to display the text in the given label
func heightForText(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
    let context = NSStringDrawingContext()
    let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    let rect = text.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: [.font : font], context: context)
    return rect.height
}

///changes the color of all HTTP links to the specified color
func attributedStringWithHighlightedLinks(_ string: String, linkColor: UIColor) -> NSAttributedString {

    let attributed = NSMutableAttributedString(string: string)
    for (_, linkRange) in linksInText(string) {
        attributed.addAttribute(.foregroundColor, value: linkColor, range: linkRange)
    }
    
    return attributed
}

///returns a list of all HTTP links in the given string
func linksInText(_ string: String) -> [(text: String, range: NSRange)] {
    
    var text = string as NSString
    var links: [(text: String, range: NSRange)] = []
    
    while text.contains("http://") || text.contains("www.") || text.contains("https://") {
        var idRange = text.range(of: "http://")
        if idRange.location == NSNotFound { idRange = text.range(of: "https://") }
        if idRange.location == NSNotFound { idRange = text.range(of: "www.") }
        
        if idRange.location != NSNotFound {
            //find entire word that contains link ID
            let wordStart = idRange.location
            var wordEnd = idRange.location + idRange.length
            
            func nextIsWhitespace() -> Bool {
                if wordEnd == text.length { return false }
                
                let currentEnd = text.stringAtIndex(wordEnd)
                return currentEnd.isWhitespace() || currentEnd == ")"
            }
            
            while !nextIsWhitespace() && (wordEnd != text.length) {
                wordEnd += 1;
            }
            
            let linkRange = NSMakeRange(wordStart, wordEnd - wordStart)
            let link = text.substring(with: linkRange)
            text = text.replacingCharacters(in: linkRange, with: link.uppercased()) as NSString
            links.append((text: link, range: linkRange))
        }
    }
    
    return links
}

///converts "http://www.google.com/search/page/saiojdfghadlsifuhlaisdf" to "google.com"
func websiteForLink(_ string: String) -> String {
    var stripped = (string as NSString).replacingOccurrences(of: "http://", with: "")
    stripped = (stripped as NSString).replacingOccurrences(of: "https://", with: "")
    stripped = (stripped as NSString).replacingOccurrences(of: "www.", with: "")
    return stripped.components(separatedBy: "/")[0]
}

//MARK: - Classes

///A touch gesture recognizer that sends events on both .Began (down) and .Ended (up)
class UITouchGestureRecognizer : UITapGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.state = .began
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.state = .began
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.state = .ended
    }
    
}

///A basic class to manage Location access
class LocationManager : NSObject, CLLocationManagerDelegate {
    
    var waitingForAuthorization: [(completion: (CLLocation) -> (), failure: (LocationFailureReason) -> ())] = []
    var waitingForUpdate: [(completion: (CLLocation) -> (), failure: (LocationFailureReason) -> ())] = []
    var manager = CLLocationManager()
    
    ///Manager must be kept as a strong reference at the class-level.
    init(accuracy: CLLocationAccuracy) {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = accuracy
    }
    
    func getCurrentLocation(_ completion: @escaping (CLLocation) -> (), failure: @escaping (LocationFailureReason) -> () ) {
        let auth = CLLocationManager.authorizationStatus()
        if auth == .restricted || auth == .denied {
            failure(.permissionsDenied)
            return
        }
        
        if auth == .notDetermined {
            waitingForAuthorization.append((completion: completion, failure: failure))
            manager.requestWhenInUseAuthorization()
            return
        }
        
        updateLocationIfEnabled(completion, failure: failure)
        
    }
    
    func getCurrentLocation(_ completion: @escaping (CLLocation) -> ()) {
        getCurrentLocation(completion, failure: { error in })
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        for (completion, failure) in waitingForAuthorization {
            if status == .authorizedWhenInUse {
                updateLocationIfEnabled(completion, failure: failure)
            }
            else {
                failure(.permissionsDenied)
            }
        }
        waitingForAuthorization = []
    }
    
    fileprivate func updateLocationIfEnabled(_ completion: @escaping (CLLocation) -> (), failure: @escaping (LocationFailureReason) -> ()) {
        if !CLLocationManager.locationServicesEnabled() {
            failure(.locationServicesDisabled)
            return
        }
        
        waitingForUpdate.append((completion: completion, failure: failure))
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        for (completion, _) in waitingForUpdate {
            completion(location)
        }
        waitingForUpdate = []
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        for (_, failure) in waitingForUpdate {
            failure(.error(error as NSError))
        }
        waitingForUpdate = []
        manager.stopUpdatingLocation()
    }
    
}

enum LocationFailureReason {
    case permissionsDenied
    case locationServicesDisabled
    case error(NSError)
}

///Standard Stack data structure

struct Stack<T> {
    
    var array : [T] = []
    
    mutating func push(_ push: T) {
        array.append(push)
    }
    
    mutating func pop() -> T? {
        if array.count == 0 { return nil }
        let count = array.count
        let pop = array[count - 1]
        array.removeLast()
        return pop
    }
    
    var top: T? {
        if array.count == 0 { return nil }
        return array[count - 1]
    }
    
    var count: Int {
        return array.count
    }
    
}

///Pushing and Poping delegates on a Table View
class TableViewStackController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var tableView: UITableView!
    var delegateStack: Stack<(delegate: StackableTableDelegate, contentOffset: CGPoint)> = Stack()
    var currentDelegate: StackableTableDelegate!
    
    func popDelegate() {
        if let (newDelegate, offset) = delegateStack.pop() {
            pushDelegate(newDelegate, isBack: true, atOffset: offset)
        }
    }
    
    func pushDelegate(_ delegate: StackableTableDelegate, hasBeenUpdatedToNewLoadFormat: Bool) {
        pushDelegate(delegate, isBack: false, atOffset: CGPoint.zero)
    }
    
    fileprivate func pushDelegate(_ delegate: StackableTableDelegate, isBack: Bool, atOffset offset: CGPoint?) {
        if let currentDelegate = tableView.delegate as? StackableTableDelegate, !isBack {
            let delegateInfo = (delegate: currentDelegate, contentOffset: self.tableView.contentOffset)
            delegateStack.push(delegateInfo)
        }
        currentDelegate = delegate //store a strong reference of the delegate
        tableView.delegate = delegate
        tableView.dataSource = delegate
        tableView.reloadData()
        
        //restore to the previous offset
        //but only if the content size hasn't gotten smaller than the previous offset
        let contentHeight = tableView.contentSize.height + tableView.contentInset.top + tableView.contentInset.bottom
        if (offset?.y ?? 0) <= contentHeight - tableView.frame.height {
            tableView.contentOffset = offset ?? CGPoint.zero
        }
        
        unhighlightAllCells()
        
        let subtype = isBack ? kCATransitionFromLeft : kCATransitionFromRight
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(tableView, duration: 0.4, transition: kCATransitionPush, subtype: subtype, timingFunction: timingFunction)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("numberOfRowsInSection must be implemented by the subclass")
        return 0
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("cellForRowAtIndexPath must be implemented by the subclass")
        return UITableViewCell()
    }
    
    func processTouchInTableView(_ touch: CGPoint, state: UIGestureRecognizerState) {
        for cell in tableView.visibleCells {
            let delegate = tableView.delegate as? StackableTableDelegate
            
            if let index = tableView.indexPath(for: cell) {
                if cell.frame.contains(touch) {
                    
                    //ignore touch is commanded by the delagate
                    if delegate?.shouldIgnoreTouch?(touch, inCell: cell) != true {
                    
                        if state == .ended {
                            if let processSelectedCellWithTouch = delegate?.processSelectedCellWithTouch {
                                let touchInView = cell.convert(touch, from: tableView)
                                processSelectedCellWithTouch(index, touchInView)
                            } else {
                                delegate?.processSelectedCell(index)
                            }
                            
                            delegate?.animateSelection(cell, indexPath: index, selected: false)
                            return
                        }
                        else {
                            if delegate?.canHighlightCell(index) == true {
                                delegate?.animateSelection(cell, indexPath: index, selected: true)
                                continue
                            }
                        }
                        
                    }
                }
                
                if delegate?.canHighlightCell(index) == true {
                    delegate?.animateSelection(cell, indexPath: index, selected: false)
                }
            }
        }
    }
    
    func unhighlightAllCells() {
        guard let delegate = tableView.delegate as? StackableTableDelegate else { return }
        for cell in tableView.visibleCells {
            let indexPath = tableView.indexPath(for: cell)!
            if delegate.canHighlightCell(indexPath) {
                delegate.animateSelection(cell, indexPath: tableView.indexPath(for: cell)!, selected: false)
            }
        }
    }
    
}

@objc protocol StackableTableDelegate : UITableViewDelegate, UITableViewDataSource {
    
    func processSelectedCell(_ index: IndexPath)
    @objc optional func processSelectedCellWithTouch(_ index: IndexPath, _ touchLocationInCell: CGPoint)
    func canHighlightCell(_ index: IndexPath) -> Bool
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool)
    func loadCachedData()
    func loadData()
    func isFirstLoad() -> Bool
    @objc optional func shouldIgnoreTouch(_ location: CGPoint, inCell: UITableViewCell) -> Bool
    @objc optional func getTitle() -> String
    @objc optional func getBackButtonImage() -> UIImage
    @objc optional func scrollViewDidScroll(_ scrollView: UIScrollView)
    
}

///This class fixes the weird bug where iPad Table View Cells always default to a white background
class TransparentTableView : UITableView {
    
    override func dequeueReusableCell(withIdentifier identifier: String) -> UITableViewCell? {
        let cell = super.dequeueReusableCell(withIdentifier: identifier)
        cell?.backgroundColor = cell?.backgroundColor
        return cell
    }
    
}

//MARK: - Standard Library Extensions

extension Array {
    ///Returns a copy of the array in random order
    func shuffled() -> [Element] {
        var list = self
        for i in 0..<(list.count - 1) {
            let j = Int(arc4random_uniform(UInt32(list.count - i))) + i
            list.swapAt(i, j)
        }
        return list
    }
}

extension Int {
    ///Converts an integer to a standardized three-character string. 1 -> 001. 99 -> 099. 123 -> 123.
    func threeCharacterString() -> String {
        let start = "\(self)"
        let length = start.length
        if length == 1 { return "00\(start)" }
        else if length == 2 { return "0\(start)" }
        else { return start }
    }
}

extension NSObject {
    ///Short-hand function to register a notification observer
    func observeNotification(_ name: String, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: NSNotification.Name(rawValue: name), object: nil)
    }
}

extension Date {
    ///converts to a "10 seconds ago" / "1 day ago" syntax
    func agoString() -> String {
        let deltaTime = -self.timeIntervalSinceNow
        
        //in the past
        if deltaTime > 0 {
            if deltaTime < 60 {
                return "just now"
            }
            if deltaTime < 3600 { //less than an hour
                let amount = Int(deltaTime/60.0)
                let plural = amount == 1 ? "" : "s"
                return "\(amount) minute\(plural) ago"
            }
            else if deltaTime < 86400 { //less than a day
                let amount = Int(deltaTime/3600.0)
                let plural = amount == 1 ? "" : "s"
                return "\(amount) hour\(plural) ago"
            }
            else if deltaTime < 432000 { //less than five days
                let amount = Int(deltaTime/86400.0)
                let plural = amount == 1 ? "" : "s"
                if amount == 1 {
                    return "Yesterday"
                }
                return "\(amount) day\(plural) ago"
            }
        }
        
        //in the future
        if deltaTime < 0 {
            if deltaTime > -60 {
                return "just now"
            }
            if deltaTime > -3600 { //in less than an hour
                let amount = -Int(deltaTime/60.0)
                let plural = amount == 1 ? "" : "s"
                return "in \(amount) minute\(plural)"
            }
            else if deltaTime > -86400 { //in less than a day
                let amount = -Int(deltaTime/3600.0)
                let plural = amount == 1 ? "" : "s"
                return "in \(amount) hour\(plural)"
            }
            else if deltaTime > -432000 { //in less than five days
                let amount = -Int(deltaTime/86400.0)
                let plural = amount == 1 ? "" : "s"
                if amount == 1 {
                    return "Tomorrow"
                }
                return "in \(amount) day\(plural)"
            }
        }
        
        let dateString = DateFormatter.localizedString(from: self, dateStyle: .medium, timeStyle: .none)
        return "on \(dateString)"
        
    }
    
}

extension UITableViewCell {
    //hides the line seperator of the cell
    func hideSeparator() {
        self.separatorInset = UIEdgeInsetsMake(0, self.frame.size.width * 2.0, 0, 0)
    }
    
    //re-enables the line seperator of the cell
    func showSeparator() {
        self.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0)
    }
}

extension UIView {
    
    static func animateWithDuration(_ duration: TimeInterval, delay: TimeInterval, usingSpringWithDamping damping: CGFloat, animations: @escaping () -> ()) {
        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: 0.0, options: [], animations: animations, completion: nil)
    }
    
}

extension String {
    
    var length: Int {
        return (self as NSString).length
    }
    
    func asDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
    
    func percentStringAsDouble() -> Double? {
        if let displayedNumber = (self as NSString).substring(to: self.length - 1).asDouble() {
            return displayedNumber / 100.0
        }
        return nil
    }
    
    func isWhitespace() -> Bool {
        return self == " " || self == "\n" || self == "\r" || self == "\r\n" || self == "\t"
            || self == "\u{A0}" || self == "\u{2007}" || self == "\u{202F}" || self == "\u{2060}" || self == "\u{FEFF}"
        //there are lots of whitespace characters apparently
        //http://www.fileformat.info/info/unicode/char/00a0/index.htm
    }
    
    mutating func prepareForURL(isFullURL: Bool = false) {
        self = self.preparedForURL(isFullURL: isFullURL)
    }
    
    func preparedForURL(isFullURL: Bool = false) -> String {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) ?? self
    }
    
}

extension NSString {
    
    func stringAtIndex(_ index: Int) -> String {
        let char = self.character(at: index)
        return "\(Character(UnicodeScalar(char)!))"
    }
    
    func countOccurancesOfString(_ string: String) -> Int {
        if string.length == 0 { return 0 }
        
        let strCount = self.length - self.replacingOccurrences(of: string, with: "").length
        return strCount / string.length
    }
    
}

extension Bundle {
    
    static var applicationVersionNumber: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Version Number Not Available"
    }
    
    static var applicationBuildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Build Number Not Available"
    }
    
}

extension Timer {
    
    class func scheduleAfter(_ delay: TimeInterval, handler: @escaping () -> ()) -> Timer {
        let fireDate = delay + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, { _ in handler() })
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, CFRunLoopMode.commonModes)
        
        return timer!
    }
    
}
