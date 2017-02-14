//
//  MapViewController.swift
//  oldNYC-iOS
//
//  Created by Orian Breaux and Christina Leuci.
//  Copyright © 2016 OldNYC. All rights reserved.
//

import UIKit
import CoreLocation
import Mapbox
import SwiftyJSON
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class MapViewController: UIViewController,
                         MGLMapViewDelegate,
                         CLLocationManagerDelegate {

    fileprivate var foregroundNotification : NSObjectProtocol!
    
    var mapView : MGLMapView!
    var lastTappedLocationData = [[String : Any]]()
    var lastTappedLocationName : String = ""
    let locationManager = CLLocationManager()

    @IBOutlet weak var mapBrandingLogo: UIImageView!
    @IBOutlet weak var menuButton : UIButton!
    @IBAction func tappedMenuButton(_ sender: AnyObject) {
        performSegue(withIdentifier: "toMenu", sender: nil)
    }
    @IBOutlet weak var centerOnUserButton : UIButton!
    @IBAction func tappedCenterOnUserbutton(_ sender: UIButton) {
        
        let fromCamera = mapView.camera
        
        let toCamera = MGLMapCamera(lookingAtCenter: (mapView.userLocation?.coordinate)!, fromDistance: fromCamera.altitude, pitch: 0, heading: 0)

        mapView.setCamera(toCamera, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear), completionHandler: {() -> Void in self.mapView.setUserTrackingMode(.follow, animated:false)})
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated:false)
        self.navigationController?.navigationBar.barStyle = UIBarStyle.black
        self.navigationController?.navigationBar.tintColor = UIColor.white
    }
    
    override func viewDidAppear(_ animated: Bool) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.lightStyleURL(withVersion: 9))
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Place marker annotations on map.
        generateMarkersFromJSON()
        
        // Configure map settings.
        mapView.showsUserLocation = true
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // Set the map's center coordinate over NYC.
        let startingLocation:CLLocation = CLLocation(latitude: 40.71356, longitude: -73.99084)
        mapView.setCenter(CLLocationCoordinate2D(latitude: startingLocation.coordinate.latitude, longitude: startingLocation.coordinate.longitude), zoomLevel:12, animated:false)
        mapView.minimumZoomLevel = 10
        mapView.maximumZoomLevel = 18
        
        view.addSubview(mapView)
        view.bringSubview(toFront: menuButton)
        view.bringSubview(toFront: mapBrandingLogo)
        
        mapView.delegate = self
        
        locationManager.requestWhenInUseAuthorization()
        
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.startUpdatingLocation()
        }
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            foregroundNotification = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main) {
                [unowned self] notification in
                
                print("app is in foreground")
                
                if let currentCoordinates : CLLocationCoordinate2D = self.locationManager.location?.coordinate {
                    print(currentCoordinates)
                    self.isUserInNYC(currentCoordinates, completion: { (answer) in
                        if answer == true {
                            print(currentCoordinates)
                            //self.centerOnUserLocation(currentCoordinates)
                            self.view.bringSubview(toFront: self.centerOnUserButton)
                        } else if answer == false {
                            self.view.sendSubview(toBack: self.centerOnUserButton)
                        }
                    })
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    
    deinit {
        // make sure to remove the observer when this view controller is dismissed/deallocated
        NotificationCenter.default.removeObserver(foregroundNotification)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            //if let currentCoordinates = CLLocationCoordinate2D(latitude: 40.761850, longitude: -73.887072)
            if let currentCoordinates : CLLocationCoordinate2D = manager.location?.coordinate {
                self.isUserInNYC(currentCoordinates, completion: { (answer) in
                    if answer == true {
                        self.centerOnUserLocation(currentCoordinates)
                        self.view.bringSubview(toFront: self.centerOnUserButton)
                    } else if answer == false {
                        self.view.sendSubview(toBack: self.centerOnUserButton)
                    }
                })
            }
        }
    }
    
    
//********** FUNCTIONS FOR GENERATING MAP UI **********//
    
    // Read markers.json, and generate markers for each coordinate.
    func generateMarkersFromJSON() {
        if let path = Bundle.main.path(forResource: "markers", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: NSData.ReadingOptions.mappedIfSafe)
                let jsonObj = JSON(data: data)
                if jsonObj != JSON.null {
                    var markers = [MGLPointAnnotation]()
                    
                    // Create markers for each item.
                    for item in jsonObj["markers"].arrayValue {
                        let lat = item["latitude"].double
                        let lon = item["longitude"].double
                        let title = item["marker_title"].stringValue
                        
                        // Add markers to annotations array.
                        let marker = MGLPointAnnotation()
                        marker.coordinate = CLLocationCoordinate2DMake(lat!, lon!)
                        marker.title = title
                        
                        markers.append(marker)
                    }
                    // Add all markers to map at once.
                    mapView.addAnnotations(markers)
                    
                } else {
                    print("could not get json from file")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
    }
    
    // Define and use custom marker style.
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "LocationMarker")
        
        if annotationImage == nil {
            let image = UIImage(named: "LocationMarker")
            annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "LocationMarker")
        }
        
        return annotationImage
    }
    
    // When user taps on marker annotation, retrieve image information for given location.
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        let tappedLat = String(format:"%2.6f", annotation.coordinate.latitude)
        let tappedLon = String(format:"%2.6f", annotation.coordinate.longitude)
        
        lastTappedLocationName = annotation.title!!

        let jsonPath = "by-location/" + tappedLat + tappedLon
        
        if let path = Bundle.main.path(forResource: jsonPath, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: NSData.ReadingOptions.mappedIfSafe)
                let jsonObj = JSON(data: data)
                if jsonObj != JSON.null {
                    
                    self.setLastTappedLocationData(jsonObj)
                    self.performSegue(withIdentifier: "toGallery", sender: self)
                    
                } else {
                    print("could not get json from file")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
        
        mapView.deselectAnnotation(annotation, animated: false)
    }
    
    func mapView(_ mapView: MGLMapView, didDeselect annotation: MGLAnnotation) {
    }
    
    func getLastTappedLocationData() -> [[String : Any]] {
        return lastTappedLocationData
    }
    
    func setLastTappedLocationData(_ jsonObj : JSON) {
        self.lastTappedLocationData.removeAll()
        
        // For each image in location's JSON data, save attributes into dictionary.
        for (key,subJson):(String,JSON) in jsonObj {
            var dict = [String : Any]()
            
            dict["photoID"] = key
            dict["width"] = subJson["width"].double
            dict["height"] = subJson["width"].double
            dict["image_url"] = subJson["image_url"].stringValue
            dict["thumb_url"] = subJson["thumb_url"].stringValue
            dict["title"] = subJson["title"].stringValue
            
            if(subJson["date"].stringValue == ""){
                dict["date"] = "No Date"
            } else {
                dict["date"] = subJson["date"].stringValue
            }
            
            dict["folder"] = subJson["folder"].stringValue
            dict["description"] = subJson["text"].stringValue
            dict["rotation"] = subJson["rotation"].double
            
            self.lastTappedLocationData.append(dict)
        }
        
        // Sort "image" elements in lastTappedLocationData by year
        lastTappedLocationData.sort{ ($0["date"] as? String) < ($1["date"] as? String) }
    }
    
    func isUserInNYC(_ currentCoordinates: CLLocationCoordinate2D, completion: @escaping (_ answer: Bool?) -> Void) {
        let location = CLLocation(latitude: currentCoordinates.latitude, longitude: currentCoordinates.longitude)
        let geocoder = CLGeocoder()
        
        print("-> Finding user address...") // debugging
        
        geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error)->Void in
            var placemark:CLPlacemark!
            
            if error == nil && placemarks!.count > 0 {
                placemark = placemarks![0] as CLPlacemark
                
                print("Locality:" + placemark.locality!) // debugging
                //print(placemark.administrativeArea) // debugging
                print("subAdmin:" + placemark.subAdministrativeArea!) // debugging
                print("subLocality:" + placemark.subLocality!) // debugging
                //print(placemark.ocean) // debugging
                //print(placemark.inlandWater) // debugging
                
                if (placemark.locality == "New York" && placemark.inlandWater == nil) {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        })
    }
    
    func centerOnUserLocation(_ currentCoordinates: CLLocationCoordinate2D) {
        let fromCamera = self.mapView.camera
        let toCamera = MGLMapCamera(lookingAtCenter: currentCoordinates, fromDistance: fromCamera.altitude, pitch: 0, heading: 0)
        
        self.mapView.setCamera(toCamera, withDuration: 0.75, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear), completionHandler: {() -> Void in
            self.mapView.setZoomLevel(14, animated: true)
            
            //self.mapView.setUserTrackingMode(.Follow, animated:false)
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender:Any!){
        if (segue.identifier == "toGallery"){
            let svc = segue.destination as! PhotoGalleryViewController;
            svc.lastTappedLocationDataPassed = self.lastTappedLocationData
            svc.lastTappedLocationName = self.lastTappedLocationName
            let backItem = UIBarButtonItem()
            backItem.title = ""
            navigationItem.backBarButtonItem = backItem
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any!) -> Bool {
        if identifier == "toGallery"{
            if (self.lastTappedLocationData.isEmpty == true){
                return false
            }
        }
        return true
    }
    
    override var prefersStatusBarHidden : Bool {
        return true;
    }
}
