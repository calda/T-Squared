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
func playTransitionForView(view: UIView, duration: Double, transition transitionName: String) {
    playTransitionForView(view, duration: duration, transition: transitionName, subtype: nil)
}

///play a CATransition for a UIView
func playTransitionForView(view: UIView, duration: Double, transition transitionName: String, subtype: String? = nil) {
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
    
    transition.subtype = subtype!
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

//MARK: - Classes

///A touch gesture recognizer that sends events on both .Began (down) and .Ended (up)
class UITouchGestureRecognizer : UIGestureRecognizer {
    
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
    
    var count: Int {
        return array.count
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