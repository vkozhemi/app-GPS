 //
//  ViewController.swift
//  find address
//
//  Created by Volodymyr KOZHEMIAKIN on 1/26/19.
//  Copyright © 2019 Volodymyr KOZHEMIAKIN. All rights reserved.
//

import UIKit
import MapKit

class customPin: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(pinTitle: String, pinSubTitle: String, location: CLLocationCoordinate2D) {
        self.title = pinTitle
        self.subtitle = pinSubTitle
        self.coordinate = location
    }
}

enum SearchState {
    case source
    case destination
}




class ViewController: UIViewController, MKMapViewDelegate, UITextFieldDelegate, MKLocalSearchCompleterDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var sourceCancel: UIButton!
    @IBOutlet weak var destCancel: UIButton!
    @IBOutlet weak var destStackView: UIStackView!
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        hideSearch()
    }
    
    lazy var formatter:DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
    
    
    var route:MKPolyline?
    
    var sourceAnnotation:Annot?
    var destAnnotation:Annot?
    
    var locationManager = CLLocationManager()
    var locateUser = false {
        didSet {
            if locateUser {
                locateButton.setTitle("Stop locating", for: .normal)
            }
            else {
                locateButton.setTitle("Locate me", for: .normal)
            }
        }
    }
    
    @IBAction func textFieldDidChange(_ sender: UITextField) {
        guard let t = sender.text,
            t != "" else {return}
        searchCompleter.queryFragment = t
    }
    
    lazy var searchCompleter: MKLocalSearchCompleter = {
        let s = MKLocalSearchCompleter()
        s.delegate = self
        return s
    }()
    
    
    var searchItems:[MKLocalSearchCompletion] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    var state = SearchState.source {
        didSet {
            if state == .source {
                destStackView.isHidden = true
                segmentedControl.isHidden = true
            }
            else {
                destStackView.isHidden = false
                segmentedControl.isHidden = false
            }
        }
    }
    
    var source:MKMapItem? {
        didSet {
            drawPathIfNeeded()
            if source == nil {
                destStackView.isHidden = true
                segmentedControl.isHidden = true
                segmentedControl.setTitle("Driving", forSegmentAt: 0)
                segmentedControl.setTitle("Walking", forSegmentAt: 1)
            }
            else {
                locateUser = false
                destStackView.isHidden = false
                segmentedControl.isHidden = false
            }
        }
    }
    var destination:MKMapItem? {
        didSet {
            drawPathIfNeeded()
            if destination != nil {
                swapButton.isHidden = false
                locateUser = false
            }
            else {
                segmentedControl.setTitle("Driving", forSegmentAt: 0)
                segmentedControl.setTitle("Walking", forSegmentAt: 1)
                swapButton.isHidden = true
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    @IBOutlet weak var sourceTextField: UITextField!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var myMapView: MKMapView!
    @IBAction func transportTypeChanged(_ sender: Any) {
        drawPathIfNeeded()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        showUserLocation()
        sourceTextField.clearButtonMode = .whileEditing
        destinationTextField.clearButtonMode = .whileEditing
        self.map.mapType = .mutedStandard
    }
    
    @IBAction func showUserLocation() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locateUser = true
            locationManager.requestWhenInUseAuthorization()
        }
        else if locateUser {
            locateUser = false
            locationManager.stopUpdatingLocation()
        }
        else {
            locateUser = true
            zoomToCoordinate(map.userLocation.coordinate)
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways) || (status == .authorizedWhenInUse) {
            locateUser = true
            zoomToCoordinate(map.userLocation.coordinate)
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locateUser {
            zoomToCoordinate(map.userLocation.coordinate)
        }
    }
    
    @IBAction func swiped(_ sender: Any) {
        hideSearch()
    }
    
    func hideSearch() {
        UIView.animate(withDuration: 0.5) {
            self.tableView.alpha = 0.0
            self.myMapView.alpha = 1.0
            self.sourceTextField.resignFirstResponder()
            self.destinationTextField.resignFirstResponder()
        }
        self.destCancel.isHidden = true
        self.sourceCancel.isHidden = true
    }
    
    func drawPathIfNeeded() {
        guard let s = source,
            let dest = destination else {return}
        if let r = route {
            myMapView.remove(r)
        }
        let directionRequest = MKDirectionsRequest()
        directionRequest.source = s
        directionRequest.destination = dest
        if segmentedControl.selectedSegmentIndex == 0 {
            directionRequest.transportType = .automobile
        }
        else {
            directionRequest.transportType = .walking
        }
        let direction = MKDirections(request: directionRequest)
        direction.calculate { (response, error) in
            if let e = error {
                ErrorReporter.showError(e.localizedDescription, from: self)
            }
            else if let directionResponse = response {
                let route = directionResponse.routes[0]
                self.myMapView.add(route.polyline, level: .aboveRoads)
                self.route = route.polyline
                if self.segmentedControl.selectedSegmentIndex == 0 {
                    self.segmentedControl.setTitle("Driving (\(self.formatter.string(from: route.expectedTravelTime)!))", forSegmentAt: 0)
                }
                else {
                    self.segmentedControl.setTitle("Walking (\(self.formatter.string(from: route.expectedTravelTime)!))", forSegmentAt: 1)
                }
                
                let rect = self.myMapView.mapRectThatFits(route.polyline.boundingMapRect, edgePadding: UIEdgeInsetsMake(70, 70, 70, 70))
                
                self.myMapView.setRegion(MKCoordinateRegionForMapRect(rect), animated: true)
            }
            else {
                ErrorReporter.showError("No response for route!", from: self)
            }
            
        }
        self.myMapView.delegate = self
    }
    
    //Mark: - MapKit delegates
    func mapView(_ myMapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 3.0
        return renderer
    }
    
    @IBAction func mapTypeChanged(_ sender: UIButton) {
        hideSearch()
        let alert = UIAlertController(title: "Map type", message: "", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Map", style: .default, handler: { (action) in
            self.map.mapType = .mutedStandard
        }))
        alert.addAction(UIAlertAction(title: "Satellite", style: .default, handler: { (action) in
            self.map.mapType = .satellite
        }))
        alert.addAction(UIAlertAction(title: "Hybrid", style: .default, handler: { (action) in
            self.map.mapType = .hybrid
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    @IBOutlet weak var locateButton: UIButton!
    @IBAction func locate(_ sender: UIButton) {
        hideSearch()
        locateUser = !locateUser
    }
    
    @IBOutlet weak var swapButton: UIButton!
    @IBAction func swap(_ sender: UIButton) {
        hideSearch()
        if let r = route {
            map.remove(r)
        }
        let a = source
        let b = sourceTextField.text
        source = nil
        let c = destination
        destination = a
        sourceTextField.text = destinationTextField.text
        destinationTextField.text = b
        source = c
    }
    
    
}
 
// MARK: -
// MARK: Table View
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchItems.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath)
        var mes = searchItems[indexPath.row].title
        if searchItems[indexPath.row].subtitle != "" {
            mes += ", \(searchItems[indexPath.row].subtitle)"
        }
        cell.textLabel?.text = mes
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let searchRequest = MKLocalSearchRequest(completion: searchItems[indexPath.row])
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        activeSearch.start {[weak self] (response, error) in
            guard let s = self else {return}
            if let e = error {
                ErrorReporter.showError(e.localizedDescription, from: s)
            }
            if let res = response {
                guard let s = self else {return}
                // remove annotations
                if let item = res.mapItems.first {
                    if s.sourceTextField.isFirstResponder {
                        s.sourceTextField.text = s.searchItems[indexPath.row].title
                        self?.source = item
                        self?.state = .destination
                        self?.sourceTextField.resignFirstResponder()
                        self?.showAnnotation(item: item, isSource: true)
                    }
                    else {
                        s.destinationTextField.text = s.searchItems[indexPath.row].title
                        self?.destination = item
                        self?.destinationTextField.resignFirstResponder()
                        self?.showAnnotation(item: item, isSource: false)
                    }
                    self?.hideSearch()
                    self?.searchItems=[]
                }
                else {
                    ErrorReporter.showError("No results", from: s)
                }
            } else {
                ErrorReporter.showError("No response", from: s)
            }
        }
    }
    
    
 }
 
 // MARK: -
 // MARK: Search
 
 extension ViewController {
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        if let t = textField.text {
            if t != "" {
                searchCompleter.queryFragment = t
            }
        }
        if textField == self.sourceTextField {
            self.sourceCancel.isHidden = false
        }
        else {
            self.destCancel.isHidden = false
        }
        UIView.animate(withDuration: 0.5) {
            self.map.alpha = 0
            self.tableView.alpha = 1
            
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        var isEmpty = false
        if let t = textField.text {
            if t == "" {
                isEmpty = true
            }
        }
        else {
            isEmpty = true
        }
        if isEmpty {
            if textField == sourceTextField {
                if let a = sourceAnnotation {
                    map.removeAnnotation(a)
                }
                source = nil
            }
            if let a = destAnnotation {
                map.removeAnnotation(a)
            }
            if let r = route {
                map.remove(r)
            }
            destination = nil
            destinationTextField.text = ""
        }
    }
    
    func showAnnotation(item:MKMapItem, isSource:Bool) {
        let a = Annot(title: item.placemark.name, subtitle: item.placemark.countryCode, coordinate: item.placemark.coordinate)
        if isSource {
            if let old = sourceAnnotation {
                map.removeAnnotation(old)
            }
            sourceAnnotation = a
        }
        else {
            if let old = destAnnotation {
                map.removeAnnotation(old)
            }
            destAnnotation = a
        }
        map.addAnnotation(a)
        zoomToCoordinate(item.placemark.coordinate)
        
    }
    
    func zoomToCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let regionRadius: CLLocationDistance = 1000
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate,
                                                                  regionRadius * 2.0, regionRadius * 2.0)
        map.setRegion(coordinateRegion, animated: true)
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchItems = completer.results
    }
    
 }
 
 class Annot:NSObject, MKAnnotation {
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D
    
    init(title:String?, subtitle:String?, coordinate:CLLocationCoordinate2D) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        super.init()
    }
 }
 

