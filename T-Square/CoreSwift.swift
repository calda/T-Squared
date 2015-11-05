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
func delay(delay: Double, closure: ()->()) {
    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
    dispatch_after(time, dispatch_get_main_queue(), closure)
}

///play a CATransition for a UIView
func playTransitionForView(view: UIView, duration: Double, transition transitionName: String, subtype: String? = nil, timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)) {
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
    view.layer.addAnimation(transition, forKey: nil)
}

///dimiss a stack of View Controllers until a desired controler is found
func dismissController(controller: UIViewController, untilMatch controllerCheck: (UIViewController) -> Bool) {
    if controllerCheck(controller) {
        return //we made it to our destination
    }
    
    let superController = controller.presentingViewController
    controller.dismissViewControllerAnimated(false, completion: {
        if let superController = superController {
            dismissController(superController, untilMatch: controllerCheck)
        }
    })
}

///get the top most view controller of the current Application
func getTopController(application: UIApplicationDelegate) -> UIViewController? {
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
func sortOutletCollectionByTag<T : UIView>(inout collection: [T]!) {
    collection = (collection as NSArray).sortedArrayUsingDescriptors([NSSortDescriptor(key: "tag", ascending: true)]) as! [T]
}


///animates a back and forth shake
func shakeView(view: UIView) {
    let animations : [CGFloat] = [20.0, -20.0, 10.0, -10.0, 3.0, -3.0, 0]
    for i in 0 ..< animations.count {
        let frameOrigin = CGPointMake(view.frame.origin.x + animations[i], view.frame.origin.y)
        
        UIView.animateWithDuration(0.1, delay: NSTimeInterval(0.1 * Double(i)), options: [], animations: {
            view.frame.origin = frameOrigin
            }, completion: nil)
    }
}


///converts a String dictionary to a String array
func dictToArray(dict: [String : String]) -> [String] {
    var array: [String] = []
    
    for item in dict {
        let first = item.0.stringByReplacingOccurrencesOfString("~", withString: "|(#)|", options: [], range: nil)
        let second = item.1.stringByReplacingOccurrencesOfString("~", withString: "|(#)|", options: [], range: nil)
        let combined = "\(first)~\(second)"
        array.append(combined)
    }
    
    return array
}

///converts an array created by the dictToArray: function to the original dictionary
func arrayToDict(array: [String]) -> [String : String] {
    var dict: [String : String] = [:]
    
    for item in array {
        let splits = item.componentsSeparatedByString("~")
        let first = splits[0].stringByReplacingOccurrencesOfString("|(#)|", withString: "~", options: [], range: nil)
        let second = splits[1].stringByReplacingOccurrencesOfString("|(#)|", withString: "~", options: [], range: nil)
        dict.updateValue(second, forKey: first)
    }
    
    return dict
}


///short-form function to run a block synchronously on the main queue
func sync(closure: () -> ()) {
    dispatch_sync(dispatch_get_main_queue(), closure)
}

///short-form function to run a block asynchronously on the main queue
func async(closure: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), closure)
}


///open to this app's iOS Settings
func openSettings() {
    UIApplication.sharedApplication().openURL(NSURL(string:UIApplicationOpenSettingsURLString)!)
}


///returns trus if the current device is an iPad
func iPad() -> Bool {
    return UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad
}

///returns trus if the current device is an iPhone 4S
func is4S() -> Bool {
    return UIScreen.mainScreen().bounds.height == 480.0
}


///a more succinct function call to post a notification
func postNotification(name: String, object: AnyObject?) {
    NSNotificationCenter.defaultCenter().postNotificationName(name, object: object, userInfo: nil)
}

///Asynchonrously ownsamples the image view's image to match the view's size
func downsampleImageInView(imageView: UIImageView) {
    async() {
        let newSize = imageView.frame.size
        let screenScale = UIScreen.mainScreen().scale
        let scaleSize = CGSizeMake(newSize.width * screenScale, newSize.height * screenScale)
        
        if let original = imageView.image where original.size.width > scaleSize.width {
            UIGraphicsBeginImageContext(scaleSize)
            let context = UIGraphicsGetCurrentContext()
            //CGContextSetInterpolationQuality(context, kCGInterpolationHigh)
            CGContextSetShouldAntialias(context, true)
            original.drawInRect(CGRect(origin: CGPointZero, size: scaleSize))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            dispatch_async(dispatch_get_main_queue(), {
                imageView.image = newImage
            })
        }
    }
}

///Converts a URL to a CSV into an array of all of the lines in the CSV.
func csvToArray(url: NSURL) -> [String] {
    let string = try! String(contentsOfURL: url, encoding: NSUTF8StringEncoding)
    return string.componentsSeparatedByString("\r\n")
}


///Crops an image to a circle (if square) or an oval (if rectangular)
func cropImageToCircle(image: UIImage) -> UIImage {
    UIGraphicsBeginImageContext(image.size)
    let context = UIGraphicsGetCurrentContext()
    
    let radius = image.size.width / 2
    let imageCenter = CGPointMake(image.size.width / 2, image.size.height / 2)
    CGContextBeginPath(context)
    CGContextAddArc(context, imageCenter.x, imageCenter.y, radius, 0, CGFloat(2*M_PI), 0)
    CGContextClosePath(context)
    CGContextClip(context)
    
    CGContextScaleCTM(context, image.scale, image.scale)
    image.drawInRect(CGRect(origin: CGPointZero, size: image.size))
    
    let cropped = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return cropped
}

///Determines the height required to display the text in the given label
func heightForText(text: String, width: CGFloat, font: UIFont) -> CGFloat {
    let context = NSStringDrawingContext()
    let size = CGSizeMake(width, CGFloat.max)
    let rect = text.boundingRectWithSize(size, options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName : font], context: context)
    return rect.height
}

///changes the color of all HTTP links to the specified color
func attributedStringWithHighlightedLinks(string: String, linkColor: UIColor) -> NSAttributedString {

    let attributed = NSMutableAttributedString(string: string)
    for (_, linkRange) in linksInText(string) {
        attributed.addAttribute(NSForegroundColorAttributeName, value: linkColor, range: linkRange)
    }
    
    return attributed
}

///returns a list of all HTTP links in the given string
func linksInText(string: String) -> [(text: String, range: NSRange)] {
    
    var text = string as NSString
    var links: [(text: String, range: NSRange)] = []
    
    while text.containsString("http://") || text.containsString("www.") || text.containsString("https://") {
        var idRange = text.rangeOfString("http://")
        if idRange.location == NSNotFound { idRange = text.rangeOfString("https://") }
        if idRange.location == NSNotFound { idRange = text.rangeOfString("www.") }
        
        if idRange.location != NSNotFound {
            //find entire word that contains link ID
            let wordStart = idRange.location
            var wordEnd = idRange.location + idRange.length
            
            func nextIsWhitespace() -> Bool {
                if wordEnd == text.length { return false }
                
                let currentEnd = text.stringAtIndex(wordEnd)
                return currentEnd.isWhitespace()
            }
            
            while !nextIsWhitespace() && (wordEnd != text.length) {
                wordEnd++;
            }
            
            let linkRange = NSMakeRange(wordStart, wordEnd - wordStart)
            let link = text.substringWithRange(linkRange)
            text = text.stringByReplacingCharactersInRange(linkRange, withString: link.uppercaseString)
            links.append(text: link, range: linkRange)
        }
    }
    
    return links
}

///converts "http://www.google.com/search/page/saiojdfghadlsifuhlaisdf" to "google.com"
func websiteForLink(string: String) -> String {
    var stripped = (string as NSString).stringByReplacingOccurrencesOfString("http://", withString: "")
    stripped = (stripped as NSString).stringByReplacingOccurrencesOfString("https://", withString: "")
    stripped = (stripped as NSString).stringByReplacingOccurrencesOfString("www.", withString: "")
    return stripped.componentsSeparatedByString("/")[0]
}

//MARK: - Classes

///A touch gesture recognizer that sends events on both .Began (down) and .Ended (up)
class UITouchGestureRecognizer : UITapGestureRecognizer {
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesBegan(touches, withEvent: event)
        self.state = .Began
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesMoved(touches, withEvent: event)
        self.state = .Began
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesEnded(touches, withEvent: event)
        self.state = .Ended
    }
    
}

///A basic class to manage Location access
class LocationManager : NSObject, CLLocationManagerDelegate {
    
    var waitingForAuthorization: [(completion: (CLLocation) -> (), failure: LocationFailureReason -> ())] = []
    var waitingForUpdate: [(completion: (CLLocation) -> (), failure: LocationFailureReason -> ())] = []
    var manager = CLLocationManager()
    
    ///Manager must be kept as a strong reference at the class-level.
    init(accuracy: CLLocationAccuracy) {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = accuracy
    }
    
    func getCurrentLocation(completion: (CLLocation) -> (), failure: LocationFailureReason -> () ) {
        let auth = CLLocationManager.authorizationStatus()
        if auth == .Restricted || auth == .Denied {
            failure(.PermissionsDenied)
            return
        }
        
        if auth == .NotDetermined {
            waitingForAuthorization.append(completion: completion, failure: failure)
            manager.requestWhenInUseAuthorization()
            return
        }
        
        updateLocationIfEnabled(completion, failure: failure)
        
    }
    
    func getCurrentLocation(completion: (CLLocation) -> ()) {
        getCurrentLocation(completion, failure: { error in })
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        for (completion, failure) in waitingForAuthorization {
            if status == .AuthorizedWhenInUse {
                updateLocationIfEnabled(completion, failure: failure)
            }
            else {
                failure(.PermissionsDenied)
            }
        }
        waitingForAuthorization = []
    }
    
    private func updateLocationIfEnabled(completion: (CLLocation) -> (), failure: LocationFailureReason -> ()) {
        if !CLLocationManager.locationServicesEnabled() {
            failure(.LocationServicesDisabled)
            return
        }
        
        waitingForUpdate.append(completion: completion, failure: failure)
        manager.startUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        for (completion, _) in waitingForUpdate {
            completion(location)
        }
        waitingForUpdate = []
        manager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        for (_, failure) in waitingForUpdate {
            failure(.Error(error))
        }
        waitingForUpdate = []
        manager.stopUpdatingLocation()
    }
    
}

enum LocationFailureReason {
    case PermissionsDenied
    case LocationServicesDisabled
    case Error(NSError)
}

///Standard Stack data structure

struct Stack<T> {
    
    var array : [T] = []
    
    mutating func push(push: T) {
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
    
    func pushDelegate(delegate: StackableTableDelegate, hasBeenUpdatedToNewLoadFormat: Bool) {
        pushDelegate(delegate, isBack: false, atOffset: CGPointZero)
    }
    
    private func pushDelegate(delegate: StackableTableDelegate, isBack: Bool, atOffset offset: CGPoint?) {
        if let currentDelegate = tableView.delegate as? StackableTableDelegate where !isBack {
            let delegateInfo = (delegate: currentDelegate, contentOffset: self.tableView.contentOffset)
            delegateStack.push(delegateInfo)
        }
        currentDelegate = delegate //store a strong reference of the delegate
        tableView.delegate = delegate
        tableView.dataSource = delegate
        tableView.reloadData()
        tableView.contentOffset = offset ?? CGPointZero
        unhighlightAllCells()
        
        let subtype = isBack ? kCATransitionFromLeft : kCATransitionFromRight
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(tableView, duration: 0.4, transition: kCATransitionPush, subtype: subtype, timingFunction: timingFunction)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("numberOfRowsInSection must be implemented by the subclass")
        return 0
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        print("cellForRowAtIndexPath must be implemented by the subclass")
        return UITableViewCell()
    }
    
    func processTouchInTableView(touch: CGPoint, state: UIGestureRecognizerState) {
        for cell in tableView.visibleCells {
            let delegate = tableView.delegate as? StackableTableDelegate
            if let index = tableView.indexPathForCell(cell) {
                if cell.frame.contains(touch) {
                    
                    if state == .Ended {
                        delegate?.processSelectedCell(index)
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
                
                if delegate?.canHighlightCell(index) == true {
                    delegate?.animateSelection(cell, indexPath: index, selected: false)
                }
            }
        }
    }
    
    func unhighlightAllCells() {
        guard let delegate = tableView.delegate as? StackableTableDelegate else { return }
        for cell in tableView.visibleCells {
            let indexPath = tableView.indexPathForCell(cell)!
            if delegate.canHighlightCell(indexPath) {
                delegate.animateSelection(cell, indexPath: tableView.indexPathForCell(cell)!, selected: false)
            }
        }
    }
    
}

@objc protocol StackableTableDelegate : UITableViewDelegate, UITableViewDataSource {
    
    func processSelectedCell(index: NSIndexPath)
    func canHighlightCell(index: NSIndexPath) -> Bool
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool)
    func loadCachedData()
    func loadData()
    func isFirstLoad() -> Bool
    optional func getTitle() -> String
    optional func getBackButtonImage() -> UIImage
    optional func scrollViewDidScroll(scrollView: UIScrollView)
    
}

///This class fixes the weird bug where iPad Table View Cells always default to a white background
class TransparentTableView : UITableView {
    
    override func dequeueReusableCellWithIdentifier(identifier: String) -> UITableViewCell? {
        let cell = super.dequeueReusableCellWithIdentifier(identifier)
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
            swap(&list[i], &list[j])
        }
        return list
    }
}

extension Int {
    ///Converts an integer to a standardized three-character string. 1 -> 001. 99 -> 099. 123 -> 123.
    func threeCharacterString() -> String {
        let start = "\(self)"
        let length = start.characters.count
        if length == 1 { return "00\(start)" }
        else if length == 2 { return "0\(start)" }
        else { return start }
    }
}

extension NSObject {
    ///Short-hand function to register a notification observer
    func observeNotification(name: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: name, object: nil)
    }
}

extension NSDate {
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
        
        let dateString = NSDateFormatter.localizedStringFromDate(self, dateStyle: .MediumStyle, timeStyle: .NoStyle)
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
    
    static func animateWithDuration(duration: NSTimeInterval, delay: NSTimeInterval, usingSpringWithDamping damping: CGFloat, animations: () -> ()) {
        UIView.animateWithDuration(duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: 0.0, options: [], animations: animations, completion: nil)
    }
    
}

extension String {
    
    var length: Int {
        return (self as NSString).length
    }
    
    func asDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
    
    func percentStringAsDouble() -> Double? {
        if let displayedNumber = (self as NSString).substringToIndex(self.length - 1).asDouble() {
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
    
}

extension NSString {
    
    func stringAtIndex(index: Int) -> String {
        let char = self.characterAtIndex(index)
        return "\(Character(UnicodeScalar(char)))"
    }
    
    func countOccurancesOfString(string: String) -> Int {
        let strCount = self.length - self.stringByReplacingOccurrencesOfString(string, withString: "").length
        return strCount / string.length
    }
    
}

extension NSBundle {
    
    static var applicationVersionNumber: String {
        if let version = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Version Number Not Available"
    }
    
    static var applicationBuildNumber: String {
        if let build = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Build Number Not Available"
    }
    
}