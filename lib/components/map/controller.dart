import 'dart:developer';
import 'dart:convert' hide Codec;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:hkbus_app/components/map/place.dart';
import 'dart:ui';

Future<Uint8List> getBytesFromAsset(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  Codec codec = await instantiateImageCodec(data.buffer.asUint8List(),
      targetWidth: width);
  FrameInfo fi = await codec.getNextFrame();
  return (await fi.image.toByteData(format: ImageByteFormat.png))!
      .buffer
      .asUint8List();
}

class MapController extends GetxController {
  var mapController = Rxn<GoogleMapController>();
  var dragableSheetRatio = 0.4.obs;
  var screenHeight = 0.0.obs;
  var zoomLevel = 10.5.obs;
  var currentPosition = Rxn<Position>();
  var mapCenterPosition = Rxn<LatLng>();

  // marker related variable
  var markers = <Marker>{}.obs;
  var placeItems = <Place>[].obs;
  var clusterManager = Rxn<ClusterManager>();
  var busIcon = Rxn<Uint8List>();

  // DB realted
  var loadingDB = true.obs;
  var stopDB = RxList<dynamic>();
  var routeDB = RxMap<String, dynamic>();

  //api event
  StreamController<void> onDBLoadedStream = StreamController<void>.broadcast();

  //map event
  StreamController<GoogleMapController> onMapCreateStream =
      StreamController<GoogleMapController>.broadcast();

  StreamController<CameraPosition> onCameraMoveStream =
      StreamController<CameraPosition>.broadcast();

  StreamController<void> onCameraIdleStream =
      StreamController<void>.broadcast();

  @override
  void onInit() {
    initMapController();
    initPositionListerner();
    initCurrentPositionCamera();
    initZoomLevelListerner();
    initMapCenterPositionListerner();
    initMarkerCluster();
    initStopDistanceUpdate();
    initPlaceItems();
    loadMapResources();

    fetchDB();
    super.onInit();
  }

  void initMapController() => {
        onMapCreateStream.stream.listen((_controller) {
          mapController.value = _controller;
        })
      };

  // Handle position changes
  void initPositionListerner() => {
        Geolocator.getPositionStream().listen((Position position) {
          currentPosition.value = position;
          // currentPosition.refresh();
        })
      };

  void initCurrentPositionCamera() => {
        onMapCreateStream.stream.listen((_mapController) {
          Timer(
              const Duration(milliseconds: 150),
              () => _mapController.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                      target: LatLng(currentPosition.value!.latitude,
                          currentPosition.value!.longitude),
                      zoom: 14.5))));
        })
      };

  void initZoomLevelListerner() => {
        onMapCreateStream.stream.listen((_mapController) {
          onCameraIdleStream.stream.listen((_) async {
            zoomLevel.value = await _mapController.getZoomLevel();
          });
        }),
      };

  void initMapCenterPositionListerner() => {
        onCameraMoveStream.stream.listen((_cameraPosition) {
          mapCenterPosition.value = _cameraPosition.target;
        })
      };

  void initMarkerCluster() {
    void updateMarkers(Set<Marker> _markers) {
      markers.value = _markers;
    }

    Future<BitmapDescriptor> _getMarkerBitmap(int size, String text) async {
      final PictureRecorder pictureRecorder = PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint1 = Paint()..color = Colors.blue;
      final Paint paint2 = Paint()..color = Colors.white;

      canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2.2, paint2);
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2.8, paint1);
      TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
      painter.text = TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size / 3,
            color: Colors.white,
            fontWeight: FontWeight.normal),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
      );

      final img = await pictureRecorder.endRecording().toImage(size, size);
      final data =
          await img.toByteData(format: ImageByteFormat.png) as ByteData;

      return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
    }

    Future<Marker> _markerBuilder(Cluster<Place> cluster) async {
      return Marker(
          markerId: MarkerId(cluster.getId()),
          position: cluster.location,
          icon: cluster.isMultiple
              ? await _getMarkerBitmap(75, cluster.count.toString())
              : BitmapDescriptor.fromBytes(busIcon.value!));
    }

    clusterManager.value = ClusterManager<Place>(
        placeItems.value, updateMarkers,
        markerBuilder: _markerBuilder);

    onMapCreateStream.stream.listen((_controller) {
      clusterManager.value!.setMapId(_controller.mapId);
    });

    onCameraMoveStream.stream.listen((_position) {
      clusterManager.value!.onCameraMove(_position);
    });

    onCameraIdleStream.stream.listen((_) {
      clusterManager.value!.updateMap();
    });
  }

  void initStopDistanceUpdate() {
    void updateStopDistance() {
      for (final stop in stopDB.value) {
        double distanceToCenter = Geolocator.distanceBetween(
            mapCenterPosition.value!.latitude,
            mapCenterPosition.value!.longitude,
            stop['lat'],
            stop['lng']);

        double distanceToCurrent = Geolocator.distanceBetween(
            currentPosition.value!.latitude,
            currentPosition.value!.longitude,
            stop['lat'],
            stop['lng']);

        stop['distanceToCenter'] = distanceToCenter;
        stop['distanceToCurrent'] = distanceToCurrent;
      }
    }

    // only trigger when both stream closed
    Future mapCreated = onMapCreateStream.stream.listen((_) => {}).asFuture();
    Future dbLoaded = onDBLoadedStream.stream.listen((_) => {}).asFuture();

    Future.wait([mapCreated, dbLoaded]).then((_) =>
        Timer(const Duration(milliseconds: 150), () => updateStopDistance()));

    onCameraIdleStream.stream.listen((_) {
      updateStopDistance();
    });
  }

  void loadMapResources() async {
    onMapCreateStream.stream.listen((_mapController) async {
      _mapController.setMapStyle(
          await rootBundle.loadString('lib/resources/map_dark.json'));
    });

    busIcon.value = await getBytesFromAsset('lib/resources/bus_icon.jpg', 90);
  }

  void fetchDB() async {
    String stopURL =
        'https://raw.githubusercontent.com/samuelcwfovo/BusETA_Crewer/main/stops.json';
    String routeURL =
        'https://raw.githubusercontent.com/samuelcwfovo/BusETA_Crewer/main/routes.json';

    var stopResult = Dio().get(stopURL);
    var routeResult = Dio().get(routeURL);

    stopDB.value = jsonDecode((await stopResult).data);
    routeDB.value = jsonDecode((await routeResult).data);

    loadingDB.value = false;

    onDBLoadedStream.sink.add(null);
    onDBLoadedStream.sink.close();
  }

  void initPlaceItems() {
    onDBLoadedStream.stream.listen((_) {
      var _placeItems = [
        for (final stop in stopDB.value)
          Place(latLng: LatLng(stop['lat'], stop['lng']))
      ];

      clusterManager.value!.setItems(_placeItems);
    });
  }

  void setScreenHeight(double _height) => screenHeight.value = _height;

  void centerCamera() => mapController.value!.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
          target: mapCenterPosition.value!, zoom: zoomLevel.value)));
}
