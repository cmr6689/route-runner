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
		mapView.delegate = self
		
		mapView.showsUserLocation = true
		mapView.setUserTrackingMode(.follow, animated: true, completionHandler: nil)
		
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
		mapView.addGestureRecognizer(longPress)
	}
	
	@objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
		guard sender.state == .began else { return }
		
		let point = sender.location(in: mapView)
		let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
		
		if let origin = mapView.userLocation?.coordinate {
			calculateRoute(from: origin, to: coordinate)
		} else {
			print("Failed to get user location, ensure location access is turned allowed.")
		}
	}

	func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
		let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
		let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")
		let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)
		
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
				strongSelf.drawRoute(route: route)
				strongSelf.mapView.showWaypoints(on: route)
				
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
		var routeCoordinates = routeShape.coordinates
		let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: UInt(routeCoordinates.count))
		
		if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource {
			source.shape = polyline
		} else {
			let source = MGLShapeSource(identifier: "route-source", features: [polyline], options: nil)
			let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
			lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))
			lineStyle.lineWidth = NSExpression(forConstantValue: 3)
			mapView.style?.addSource(source)
			mapView.style?.addLayer(lineStyle)
		}
	}
	
	func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
		return true
	}
	
	func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
		guard let route = route, let routeOptions = routeOptions else {
			return
		}
		let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: routeOptions)
		navigationViewController.modalPresentationStyle = .fullScreen
		self.present(navigationViewController, animated: true, completion: nil)
	}
}
