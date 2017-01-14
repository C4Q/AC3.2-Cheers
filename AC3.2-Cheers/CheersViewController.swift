//
//  CheersViewController.swift
//  AC3.2-Cheers
//
//  Created by Annie Tung on 1/10/17.
//  Copyright © 2017 Marty Hernandez Avedon. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreData
import SKSplashView

class CheersViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, Tappable, UISearchBarDelegate {
    @IBOutlet weak var locationSearchBar: UISearchBar!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    var splashIcon: SKSplashIcon!
    var splashView: SKSplashView!
    var allVenues:[Venue] = []
    let geocoder: CLGeocoder = CLGeocoder()
    
    let locationManager: CLLocationManager = {
        let location: CLLocationManager = CLLocationManager()
        location.desiredAccuracy = kCLLocationAccuracyHundredMeters
        location.distanceFilter = 50.0
        return location
    }()
    
    var mainContext: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        splashIcon = SKSplashIcon(image: #imageLiteral(resourceName: "beerDarkGOLD"), animationType: SKIconAnimationType.ping)
        splashView = SKSplashView(splashIcon: splashIcon, backgroundColor: .white, animationType: SKSplashAnimationType.fade)
        view.addSubview(splashView)
        splashView.animationDuration = 5.0
        splashView.startAnimation()
        
        activityIndicator.isHidden = true
        locationManager.delegate = self
        mapView.delegate = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 300
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.register(UINib(nibName: "BasicCheersTableViewCell", bundle: nil),forCellReuseIdentifier: "cheers")
        locationSearchBar.delegate = self
        
    }
    
    override func viewDidAppear (_ animated: Bool) {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }
    
    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        let alertController = UIAlertController(title: "Oops!", message: "Our map isn't working right now!", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            print(error)
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
        print("map failed to load")
    }
    
    // MARK: - Networking
    
    func getData(location: CLLocation) {
        let userLong = String(location.coordinate.longitude)
        let userLat = String(location.coordinate.latitude)
        let endPoint = "https://api.foursquare.com/v2/venues/explore?ll=\(userLat),\(userLong)&oauth_token=RFQ43RJ4WUZSVKHUUEVX2DICWK23OAFJJXFIA222WPY25H02&v=20170110&section=drinks%20&query=happy%20hour"
        APIRequestManager.manager.getData(endPoint: endPoint) { (data: Data?) in
            if let validData = data {
                if let jsonData = try? JSONSerialization.jsonObject(with: validData, options: []) {
                    if let fullDict = jsonData as? [String: Any],
                        let response = fullDict["response"] as? [String:Any],
                        let groups = response["groups"] as? [[String:AnyObject]],
                        let items = groups[0]["items"] as? [[String: Any]] {
                        self.allVenues = Venue.parseVenue(from: items)
                        
                        DispatchQueue.main.async {
                            self.allVenues.sort(by: {$0.tier < $1.tier})
                            self.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }

    // MARK: - CoreLocation Delegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Authorized, start tracking!")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Denied or restricted, change in settings!")
        default:
            self.locationManager.requestAlwaysAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        guard let validLocation = locations.first else { return }
               getData(location: validLocation)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(validLocation.coordinate, 500, 500)
        mapView.setRegion(coordinateRegion, animated: true)
        let annotation: MKPointAnnotation = MKPointAnnotation()
        annotation.coordinate = validLocation.coordinate
        annotation.title = "This is you!"
        mapView.addAnnotation(annotation)
        let cirlceOverLay: MKCircle = MKCircle(center: annotation.coordinate, radius: 100.0)
        mapView.add(cirlceOverLay)
        geocoder.reverseGeocodeLocation(validLocation) { (placemark: [CLPlacemark]?, error: Error?) in
            if error != nil {
                dump(error!)
                return
            }
            dump(placemark)
            guard let _: CLPlacemark = placemark?.last else { return }
        }
    }
    
    // MARK: - Mapview Delegate
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let circleOverlayRenderer: MKCircleRenderer = MKCircleRenderer(circle: overlay as! MKCircle)
        circleOverlayRenderer.fillColor = UIColor.orange.withAlphaComponent(0.25)
        circleOverlayRenderer.strokeColor = .orange
        circleOverlayRenderer.lineWidth = 3.0
        return circleOverlayRenderer
    }
    
    // MARK: - TableView Delegate & Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allVenues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cheers", for: indexPath) as! BasicCheersTableViewCell
        
        let venue = allVenues[indexPath.row]
        
        let currencySymbol: Character
        if let unwrapLocalCurrencySymbol = NSLocale.current.currencySymbol {
            currencySymbol = Character(unwrapLocalCurrencySymbol)
        } else {
            currencySymbol = "$"
        }
        if cell.faveIt != nil {
            cell.faveIt.isSelected = venue.favorite
        }
        if cell.delegate == nil {
            cell.delegate = self 
        }
        cell.venueName.text = venue.name
        cell.distance.text = venue.distanceFormatted()
        cell.pricing.text = String(repeatElement(currencySymbol, count: Int(venue.tier)))
        cell.popularTimes.text = venue.status
        
        return cell
        
    }
    
    // Cell Fave Button
    
    // allows us to know which fave button was clicked in which cell
    func cellTapped(cell: UITableViewCell) {
        self.favoriteButtonClicked(at: tableView.indexPath(for: cell)!)
    }
    
    func favoriteButtonClicked(at index: IndexPath) {
        let currentVenue = allVenues[index.row]
        
        if mainContext.hasChanges {
            try! mainContext.save()
        }
        
        currentVenue.favorite = !currentVenue.favorite
            if currentVenue.favorite {
                let alertController = UIAlertController(title: "Cheers!", message: "You added \(currentVenue.name) to your favorites!", preferredStyle: UIAlertControllerStyle.alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                    print("OK")
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                print("added to faves")
            } else {
                let alertController = UIAlertController(title: "Jeers!", message: "You removed \(currentVenue.name) from favorites!", preferredStyle: UIAlertControllerStyle.alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                    print("OK")
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                print("removed from faves")
            }
        
    }
    
    // MARK: SearchBar Delegate Methods 
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        let geoCoder = CLGeocoder()
        // guard let validText = searchBar.text else {return}
        geoCoder.geocodeAddressString(searchBar.text!) { (placemarks:[CLPlacemark]?, error: Error?) in
            if(error != nil){
                print(error ?? "Error!!")
            }
            if let placemark = placemarks?.first {
                guard let location = placemark.location else {return}
                self.getData(location: location)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
     // MARK: - Navigation
     
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier:"showDetails", sender: tableView)
    }
}
