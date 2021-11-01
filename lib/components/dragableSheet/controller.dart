import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hkbus_app/components/map/controller.dart';
import 'dart:developer';
import 'dart:async';

class DragableSheetController extends GetxController {
  final MapController _mapController = Get.find<MapController>();

  var sheetScrollController = Rxn<ScrollController>();
  var nearCenterStops = RxList<dynamic>();

  var selectedStop = RxMap<String, dynamic>();

  @override
  void onInit() {
    initStopsUpdateListener();
    super.onInit();
  }

  void initStopsUpdateListener() {
    void updateNearStops() {
      nearCenterStops.value = [];
      for (final stop in _mapController.stopDB.value) {
        if (stop['distanceToCenter'] < 500 && stop['name_zh_hk'] != null) {
          nearCenterStops.value.add(stop);
        }
      }

      nearCenterStops.value.sort(
          (a, b) => a['distanceToCenter'].compareTo(b['distanceToCenter']));
      nearCenterStops.refresh();
    }

    Future mapCreated =
        _mapController.onMapCreateStream.stream.listen((_) => {}).asFuture();
    Future dbLoaded =
        _mapController.onDBLoadedStream.stream.listen((_) => {}).asFuture();

    Future.wait([mapCreated, dbLoaded]).then((_) =>
        Timer(const Duration(milliseconds: 150), () => updateNearStops()));

    _mapController.onCameraIdleStream.stream.listen((_) {
      updateNearStops();
    });
  }

  void setScrollController(_scrollController) =>
      sheetScrollController.value = _scrollController;

  List getRouteFromStop(Map<String, dynamic> stop) {
    List routes = [];
    for (final route in stop['routeStops']) {
      if (route['route_unique_ID'] != null) {
        var r =
            _mapController.routeDB.value[route['route_unique_ID'].toString()];
        var contain = routes.where(
            (element) => element['routeName_zh_hk'] == r['routeName_zh_hk']);
        if (contain.isEmpty) {
          routes.add(r);
        }
      }
    }

    return routes;
  }
}
