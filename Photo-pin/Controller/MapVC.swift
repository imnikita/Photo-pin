//
//  ViewController.swift
//  Photo-pin
//
//  Created by Nikita Popov on 14.02.2021.
//

import UIKit
import Alamofire
import AlamofireImage
import MapKit
import CoreLocation

class MapVC: UIViewController, UIGestureRecognizerDelegate {

    

    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var mapViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var locationButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var pullUpView: UIView!
    
    var locationManager = CLLocationManager()
    let regionRadius: Double = 1000
    
    var spinner: UIActivityIndicatorView?
    var progressLable: UILabel!
    
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView: UICollectionView?
    
    var imageUrlArray = [String]()
    var imageArray = [UIImage]()
    
    
    var screeSize = UIScreen.main.bounds
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        configureLocationServises()
        addDoubleTap()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView?.register(PhotoCell.self, forCellWithReuseIdentifier: "photoCell")
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = #colorLiteral(red: 0.9999960065, green: 1, blue: 1, alpha: 1)
        
        pullUpView.addSubview(collectionView!)
        
        
    }
    
    func addDoubleTap(){
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(dropPin(sender:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        mapView.addGestureRecognizer(doubleTap)
    }
    
    func addSwipe(){
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(animateViewDown))
        swipe.direction = .down
        pullUpView.addGestureRecognizer(swipe)
    }
    
  
    
    func animateViewUp(){
        mapViewBottomConstraint.constant = 300
        locationButtonConstraint.constant = -15
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
        
    }
    
    @objc func animateViewDown(){
        cancelAllSessions()
        mapViewBottomConstraint.constant = 0
        locationButtonConstraint.constant = -35
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func addSpinner(){
        spinner = UIActivityIndicatorView()
        spinner?.center = CGPoint(x: (screeSize.width / 2) - ((spinner?.frame.width)! / 2), y: 150)
        spinner?.style = .large
        spinner?.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        spinner?.startAnimating()
        collectionView?.addSubview(spinner!)
    }
    
    func removeSpinner(){
        if spinner != nil{
            spinner?.removeFromSuperview()
        }
      }
    
    func addProgressLable(){
        progressLable = UILabel()
        progressLable.frame = CGRect(x: (screeSize.width / 2) - 120, y: 175, width: 240, height: 40)
        progressLable.font = UIFont(name: "Avenir Next", size: 18)
        progressLable.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        progressLable.textAlignment = .center
        
        collectionView?.addSubview(progressLable)
    }
    
    func  removeProgressLable(){
        if progressLable != nil{
            progressLable.removeFromSuperview()
        }
    }
    
    
    @IBAction func centerMapButtonPressed(_ sender: Any) {
        if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse{
            centerMapOnUserLocation()
        }
    }
}

// MARK: - MapKitViewDelegate extension

extension MapVC: MKMapViewDelegate{
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation{
            return nil
        }
        
        let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "droppablePin")
        pinAnnotation.pinTintColor = #colorLiteral(red: 0.9771530032, green: 0.7062081099, blue: 0.1748393774, alpha: 1)
        pinAnnotation.animatesDrop = true
        return pinAnnotation
    }
    
    func centerMapOnUserLocation(){
        guard let coordinate = locationManager.location?.coordinate else{ return }
        let coordinateRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    @objc func dropPin(sender: UITapGestureRecognizer){
        removePin()
        removeSpinner()
        removeProgressLable()
        cancelAllSessions()
        
        imageArray = []
        imageUrlArray = []
        collectionView?.reloadData()

        animateViewUp()
        addSwipe()
        addSpinner()
        addProgressLable()
        
        
        let touchPoint = sender.location(in: mapView)
        let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        let annotation = DroppablePin(coordinate: touchCoordinate, identifier: "droppablePin")
        mapView.addAnnotation(annotation)
        
        let coordinateRegion = MKCoordinateRegion(center:  touchCoordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        
        retreiveUrls(forAnotation: annotation) { (finished) in
            if finished{
                self.retreiveImages { (finished) in
                    if finished{
                        self.removeSpinner()
                        self.removeProgressLable()
                        self.collectionView?.reloadData()
                    }
                }
            }
        }
    }
    
    func removePin(){
        for annotation in mapView.annotations{
            mapView.removeAnnotation(annotation)
        }
    }
    
    
    func retreiveUrls(forAnotation anotation: DroppablePin, completionHandler: @escaping (_ status: Bool) -> () ){
        
        AF.request(flickrUrl(forApiKey: apiKey, withAnnotation: anotation, andNumberOfPhotos: 40)).responseJSON { (response) in
            guard let json = response.value as? [String: Any] else{ return }
            let photoDict = json["photos"] as! [String: Any]
            let photosDictArray = photoDict["photo"] as! [[String: Any]]
            for photo in photosDictArray{
                let postUrl = "https://live.staticflickr.com/\(photo["server"]!)/\(photo["id"]!)_\(photo["secret"]!)_b_d.jpeg"
                self.imageUrlArray.append(postUrl)
            }
            completionHandler(true)
        }
    }
    
    func retreiveImages(handler: @escaping (_ status: Bool) -> ()){
        
        for url in imageUrlArray{
            AF.request(url).responseImage { (response) in
                guard let image = response.value else{ return }
                self.imageArray.append(image)
                self.progressLable.text = "\(self.imageArray.count)/40 IMAGES DOWNLOADED"
                
                if self.imageArray.count == self.imageUrlArray.count{
                    handler(true)
                }
            }
        }
        
    }
    
    
    func cancelAllSessions(){
        Alamofire.Session.default.session.getTasksWithCompletionHandler { (sessionDataTask, sessionUploadTask, sessionDownloadTask) in
            sessionDataTask.forEach({ $0.cancel() })
            sessionDownloadTask.forEach({ $0.cancel() })
        }
    }
    
    
    
}

// MARK: - LocationManagerDelegate extension

extension MapVC: CLLocationManagerDelegate{
    func configureLocationServises(){
        if locationManager.authorizationStatus == .notDetermined{
            locationManager.requestAlwaysAuthorization()
        } else {
            return
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        centerMapOnUserLocation()
    }
    
}


// MARK: -  Extensions UICollectionViewDelegate, UICollectionViewDataSource

extension MapVC: UICollectionViewDelegate, UICollectionViewDataSource{
   
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imageArray.count
    }
    

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCell else{
            return UICollectionViewCell() }
        
        let imageView = UIImageView(image: imageArray[indexPath.row])
        cell.addSubview(imageView)
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let popVC = storyboard?.instantiateViewController(identifier: "PopVC") as? PopVC else { return }
        popVC.initData(forImage: imageArray[indexPath.row])
        present(popVC, animated: true, completion: nil)
    }
    
}

