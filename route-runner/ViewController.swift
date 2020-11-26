//
//  ViewController.swift
//  route-runner
//
//  Created by Cameron Riu on 11/23/20.
//

import Mapbox
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

class ViewController: UIViewController, MGLMapViewDelegate {
	
	var mapView: NavigationMapView!
	var routeOptions: NavigationRouteOptions?
	var route: Route?

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
		
		mapView = NavigationMapView(frame: view.bounds)
		view.addSubview(mapView)
		
		//Set the map view delegate
		mapView.delegate = self
		
		//Display user location on the map
		mapView.showsUserLocation = true
		mapView.setUserTrackingMode(.follow, animated: true, completionHandler: nil)
		
		//Gesture recognizer for long press added to map view
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
		mapView.addGestureRecognizer(longPress)
	}
	
	@objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
		guard sender.state == .began else { return }
		
		//Converts long press point to map coords
		let point = sender.location(in: mapView)
		let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
		
		if let origin = mapView.userLocation?.coordinate {
			//Calculate the route from user location to destination
			let home = origin
			calculateRoute(from: origin, to: coordinate, to: home)
		} else {
			print("Failed to get user location, ensure location access is turned allowed.")
		}
	}

	func calculateRoute(from origin: CLLocationCoordinate2D, to point: CLLocationCoordinate2D, to home: CLLocationCoordinate2D) {
		
		//User location starting point
		let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
		
		//Point on map user long pressed
		let point = Waypoint(coordinate: point, coordinateAccuracy: -1, name: "Point")
		
		//User location once again to return running route to home
		let home = Waypoint(coordinate: home, coordinateAccuracy: -1, name: "Finish")
		
		//Specify the route is intended for walking/running
		let routeOptions = NavigationRouteOptions(waypoints: [origin, point, home], profileIdentifier: .walking)
		
		//Generation of the route object
		Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
			switch result {
			case .failure(let error):
				print(error.localizedDescription)
			case .success(let response):
				guard let route = response.routes?.first, let strongSelf = self else {
					return
				}
				strongSelf.route = route
				strongSelf.routeOptions = routeOptions
				
				//Draw the route on the map
				strongSelf.drawRoute(route: route)
				
				//Show the final destination waypoint
				strongSelf.mapView.showWaypoints(on: route)
				
				//Display callout on destination annotation
				if let annotation = strongSelf.mapView.annotations?.first as? MGLPointAnnotation {
					annotation.title = "Start Navigation"
					strongSelf.mapView.selectAnnotation(annotation, animated: true, completionHandler: nil)
				}
			}
		}
	}
	
	func drawRoute(route: Route) {
		guard let routeShape = route.shape, routeShape.coordinates.count > 0 else {
			return
		}
		//Convert the route coords into a polyline
		var routeCoordinates = routeShape.coordinates
		let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: UInt(routeCoordinates.count))
		
		//Reset the route shape to new route if another route already on the map
		if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource {
			source.shape = polyline
		} else {
			let source = MGLShapeSource(identifier: "route-source", features: [polyline], options: nil)
			
			//Customize route line color and width
			let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
			lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))
			lineStyle.lineWidth = NSExpression(forConstantValue: 3)
			
			//Add source and style layer of the route to map view
			mapView.style?.addSource(source)
			mapView.style?.addLayer(lineStyle)
		}
	}
	
	//Method allows annotations to show callouts when tapped
	func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
		return true
	}
	
	//Present the turn by turn navigation viewer when the callout is tapped
	func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
		guard let route = route, let routeOptions = routeOptions else {
			return
		}
		let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: routeOptions)
		navigationViewController.modalPresentationStyle = .fullScreen
		self.present(navigationViewController, animated: true, completion: nil)
	}
}
