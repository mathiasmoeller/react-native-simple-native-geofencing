//
//  IOSGeofenceManager.swift
//  RNSimpleNativeGeofencing
//
//  Created by Fabian Puch on 13.01.19.
//  Copyright © 2019 Facebook. All rights reserved.
//

import Foundation
import CoreLocation
import UserNotifications

@available(iOS 12.0, *)
@objc(RNSimpleNativeGeofencing)
class RNSimpleNativeGeofencing: NSObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    
    
    //MARK: - Init / Setup
    
    static let sharedInstance = RNSimpleNativeGeofencing()
    
    let locationManager = CLLocationManager()
    var notificationCenter: UNUserNotificationCenter!
    
    var currentActiveGeofences : [CLCircularRegion] = []
    var currentGeofences: [CLCircularRegion] = []
    
    var didEnterTitle = ""
    var didEnterBody = ""
    var didExitTitle = ""
    var didExitBody = ""
    var startTrackingTitle = ""
    var startTrackingBody = ""
    var stopTrackingTitle = ""
    var stopTrackingBody = ""
    
    var notifyEnter = true
    var notifyExit = false
    var notifyStart = false
    var notifyStop = false
    
    
    
    fileprivate func allwaysInit() {
        
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        
        self.notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        
    }
    
    
    //MARK: -  Public Interface
    
    @objc(initNotification:)
    func initNotification(settings:NSDictionary) -> Void {
        
        DispatchQueue.main.async {
            
            print("\n\n\n\ninitNotification\n\n\n\n")
            
            self.allwaysInit()
            
            self.notifyEnter = settings.value(forKeyPath: "enter.notify") as? Bool ?? true
            self.notifyExit = settings.value(forKeyPath: "exit.notify") as? Bool ?? true
            self.notifyStart = settings.value(forKeyPath: "start.notify") as? Bool ?? true
            self.notifyStop = settings.value(forKeyPath: "stop.notify") as? Bool ?? true
            
            
            self.didEnterTitle = settings.value(forKeyPath: "enter.title") as? String ?? "Be careful!"
            self.didEnterBody = settings.value(forKeyPath: "enter.description") as? String ?? "It may be dangerous in the area where you are currently staying."
            self.didExitTitle = settings.value(forKeyPath: "exit.title") as? String ?? ""
            self.didExitBody = settings.value(forKeyPath: "exit.description") as? String ?? ""
            self.startTrackingTitle = settings.value(forKeyPath: "start.title") as? String ?? ""
            self.startTrackingBody = settings.value(forKeyPath: "start.description") as? String ??  ""
            self.stopTrackingTitle = settings.value(forKeyPath: "stop.title") as? String ?? ""
            self.stopTrackingBody = settings.value(forKeyPath: "stop.description") as? String ??  ""
            
        }
        
    }
    
    @objc(addGeofence:duration:)
    func addGeofence(geofence:NSDictionary, duration:Int) -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            guard let lat = geofence.value(forKey: "latitude") as? Double else {
                return
            }
            
            guard let lon = geofence.value(forKey: "longitude") as? Double else {
                return
            }
            
            guard let radius = geofence.value(forKey: "radius") as? Double else {
                return
            }
            
            guard let id = geofence.value(forKey: "key") as? String else {
                return
            }
            
            let geofenceRegionCenter = CLLocationCoordinate2D(
                latitude: lat,
                longitude: lon
            )
            
            let geofenceRegion = CLCircularRegion(
                center: geofenceRegionCenter,
                radius: CLLocationDistance(radius),
                identifier: id
            )
            
            if self.notifyEnter {
                geofenceRegion.notifyOnEntry = true
            }else{
                geofenceRegion.notifyOnEntry = false
            }
            
            if self.notifyExit {
                geofenceRegion.notifyOnExit = true
            }else{
                geofenceRegion.notifyOnExit = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(duration)) {
                self.removeGeofence(geofenceKey: id)
            }
            
            self.currentGeofences.append(geofenceRegion)
            
            
        }
        
    }
    
    
    @objc(addGeofences:monitoringGeofence:duration:)
    func addGeofences(geofencesArray:NSArray, geofence:NSDictionary, duration:Int) -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            
            //add small geofences
            for geofence in geofencesArray {
                
                guard let geo = geofence as? NSDictionary else {
                    return
                }
                
                self.addGeofence(geofence: geo, duration: duration)
                
            }
            
            //monitoring boarder (needs specific ID)
            self.addGeofence(geofence: geofence, duration: duration)
            
            
            self.startMonitoring()
            
        }
        
    }
    
    
    @objc(updateGeofences:monitoringGeofence:duration:)
    func updateGeofences(geofencesArray:NSArray, geofence:NSDictionary, duration:Int) -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            self.removeAllGeofences()
            
            //add small geofences
            for geofence in geofencesArray {
                
                guard let geo = geofence as? NSDictionary else {
                    return
                }
                
                self.addGeofence(geofence: geo, duration: duration)
                
            }
            
            //monitoring boarder (needs specific ID)
            self.addGeofence(geofence: geofence, duration: duration)
            
            
            self.startMonitoring()
            
            
        }
        
    }
    
    
    @objc(addMonitoringBorder:duration:)
    func addMonitoringBorder(geofence:NSDictionary, duration:Int) -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            //monitoring boarder (needs specific ID)
            self.addGeofence(geofence: geofence, duration: duration)
            
            self.startMonitoring()
        }
        
    }
    
    
    @objc(removeMonitoringBorder)
    func removeMonitoringBorder() -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            var count = 0
            for geo in self.currentActiveGeofences {
                if geo.identifier == "border"{
                    self.locationManager.stopMonitoring(for: geo)
                    self.currentActiveGeofences.remove(at: count)
                }
                count = count + 1;
            }
            
            var count2 = 0
            for geo in self.currentGeofences {
                if geo.identifier == "border"{
                    self.currentGeofences.remove(at: count2)
                }
                count2 = count2 + 1;
            }
        }
        
    }
    
    
    @objc(removeAllGeofences)
    func removeAllGeofences() -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            for geo in self.currentActiveGeofences {
                
                self.locationManager.stopMonitoring(for: geo)
                
            }
            
            self.currentActiveGeofences = []
            self.currentGeofences = []
            
            
        }
        
    }
    
    
    @objc(removeGeofence:)
    func removeGeofence(geofenceKey:String) -> Void {
        
        DispatchQueue.main.async {
            
            self.allwaysInit()
            
            var count = 0
            for geo in self.currentActiveGeofences {
                if geo.identifier == geofenceKey{
                    self.locationManager.stopMonitoring(for: geo)
                    self.currentActiveGeofences.remove(at: count)
                }
                count = count + 1;
            }
            
            var count2 = 0
            for geo in self.currentGeofences {
                if geo.identifier == geofenceKey{
                    self.currentGeofences.remove(at: count2)
                }
                count2 = count2 + 1;
            }
            
            
        }
        
    }
    
    
    @objc(startMonitoring)
    func startMonitoring() -> Void {
        
        DispatchQueue.main.async {
            
            print("\n\n\n\nstartMonitoring()\n\n\n\n")
            
            self.allwaysInit()
            
            for geo in self.currentGeofences {
                
                self.locationManager.startMonitoring(for: geo)
                self.currentActiveGeofences.append(geo)
                
            }
            
            self.currentGeofences = []
            
            if self.notifyStart {
                self.notifyStart(started: true)
            }
            
            
        }
        
    }
    
    
    @objc(stopMonitoring)
    func stopMonitoring() -> Void {
        
        DispatchQueue.main.async {
            
            print("\n\n\n\nstopMonitoring\n\n\n\n")
            
            self.allwaysInit()
            
            for geo in self.currentActiveGeofences {
                
                self.locationManager.stopMonitoring(for: geo)
                
            }
            
            self.currentActiveGeofences = []
            if self.notifyStop {
                self.notifyStart(started: false)
            }
            
        }
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    //MARK: - Setup Notifications
    
    private func handleEvent(region: CLRegion!, didEnter: Bool) {
        
        if region.identifier == "border" {
            
            //TODO trigger
            if didEnter {
                print("enter the boarder")
            }else{
                print("left the boarder")
            }
            
            
            
        }else{
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            
            if didEnter {
                content.title = self.didEnterTitle
                content.body = self.didEnterBody
            }else{
                content.title = self.didExitTitle
                content.body = self.didExitBody
            }
            
            
            let timeInSeconds: TimeInterval = 0.1
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeInSeconds,
                repeats: false
            )
            
            let identifier = region.identifier
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            notificationCenter.add(request, withCompletionHandler: { (error) in
                if error != nil {
                    print("Error adding notification with identifier: \(identifier)")
                }
            })
        }
        
        
    }
    
    
    private func notifyStart(started: Bool) {
        
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        
        
        if started {
            content.title = self.startTrackingTitle
            content.body = self.startTrackingBody
        }else{
            content.title = self.stopTrackingTitle
            content.body = self.startTrackingBody
        }
        
        
        let timeInSeconds: TimeInterval = 0.1
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInSeconds,
            repeats: false
        )
        
        let identifier = self.randomString(length: 20)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request, withCompletionHandler: { (error) in
            if error != nil {
                print("Error adding notification with identifier: \(identifier)")
            }
        })
    }
    
    
    
    
    //MARK: - Location Delegate Methodes
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            
            self.handleEvent(region:region, didEnter: true)
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            
            self.handleEvent(region:region, didEnter: false)
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status != .authorizedAlways {
            print("Geofence will not Work, because of missing Authorization")
        }
    }
    
    
    
    //MARK: - Notification Delegate Methodes
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // when app is onpen and in foregroud
        completionHandler(.alert)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // get the notification identifier to respond accordingly
        let identifier = response.notification.request.identifier
        
        print(identifier)
    }
    
    
    
    
    
    //MARK: - helper Functions
    
    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0...length-1).map{ _ in letters.randomElement()! })
    }
    
    
}
