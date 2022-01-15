import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:hkbus_app/components/map/controller.dart';

class Map extends StatefulWidget {
  const Map({Key? key}) : super(key: key);

  @override
  State<Map> createState() => MapState();
}

class MapState extends State<Map> {
  final MapController mapController = Get.put(MapController());

  @override
  void initState() {
    super.initState();
    mapController.onMapCreateStream.stream.listen((_) {
      mapController.setScreenHeight(MediaQuery.of(context).size.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    log('map build');
    return Obx(() => GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(22.327157, 114.122836), zoom: 10.5),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          trafficEnabled: true,
          compassEnabled: true,
          onMapCreated: (controller) => {
            mapController.onMapCreateStream.sink.add(controller),
            mapController.onMapCreateStream.sink.close()
          },
          onCameraMove: (position) =>
              mapController.onCameraMoveStream.sink.add(position),
          onCameraIdle: () => mapController.onCameraIdleStream.sink.add(null),
          padding: EdgeInsets.only(
              top: 55,
              bottom: mapController.screenHeight.value *
                  mapController.dragableSheetRatio.value),
          markers: mapController.markers.value,
          // markers: mapController.zoomLevel >= 14.5
          //     ? mapController.allMarkers.value
          //     : mapController.markers.value,
        ));
  }
}
