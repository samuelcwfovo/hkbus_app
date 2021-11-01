import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:hkbus_app/components/dragableSheet/controller.dart';
import 'package:get/get.dart';
import 'package:hkbus_app/components/map/controller.dart';

class DragableSheet extends StatefulWidget {
  const DragableSheet({Key? key}) : super(key: key);

  @override
  State<DragableSheet> createState() => DragableSheetState();
}

class DragableSheetState extends State<DragableSheet> {
  final MapController _mapController = Get.find<MapController>();
  final DragableSheetController dragableSheetController =
      Get.put(DragableSheetController());

  @override
  Widget build(BuildContext context) {
    log('sheet build');
    return GestureDetector(
      onVerticalDragEnd: (detail) {
        log('vertical');
      },
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          _mapController.dragableSheetRatio.value = notification.extent;
          _mapController.centerCamera();
          return true;
        },
        child: DraggableScrollableSheet(
          maxChildSize: .7,
          initialChildSize: .4,
          minChildSize: .25,
          builder: (context, _scrollController) {
            dragableSheetController.setScrollController(_scrollController);
            return (ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      color: Color(0x96202124)),
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * .7),
                      child: DragableSheetContentView()),
                ),
              ),
            ));
          },
        ),
      ),
    );
  }
}

class DragableSheetContentView extends StatelessWidget {
  DragableSheetContentView({Key? key}) : super(key: key);

  final dragableSheetController = Get.find<DragableSheetController>();

  @override
  Widget build(BuildContext context) {
    // return Obx(() => dragableSheetController.selectedStop.value.isEmpty
    //     ? const CustomTabBarView()
    //     : StopDetailView());

    return Obx(() => Stack(
          children: <Widget>[
            Visibility(
                visible: dragableSheetController.selectedStop.value.isEmpty,
                maintainState: true,
                child: const CustomTabBarView()),
            Visibility(
                visible: dragableSheetController.selectedStop.value.isNotEmpty,
                child: StopDetailView()),
          ],
        ));
  }
}

class CustomTabBarView extends StatelessWidget {
  const CustomTabBarView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                const TabBar(tabs: [
                  Tab(
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.grey,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.favorite_border,
                      color: Colors.grey,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.search,
                      color: Colors.grey,
                    ),
                  )
                ]),
                Expanded(
                  child: TabBarView(children: [
                    RouteTabView(),
                    const Icon(Icons.directions_transit),
                    const Icon(Icons.directions_bike),
                  ]),
                )
              ],
            ),
          ),
        )
      ],
    );
  }
}

class RouteTabView extends StatelessWidget {
  RouteTabView({Key? key}) : super(key: key);

  final dragableSheetController = Get.find<DragableSheetController>();
  final mapController = Get.find<MapController>();

  Widget zoomRequire() {
    return SingleChildScrollView(
      controller: dragableSheetController.sheetScrollController.value,
      child: Column(children: [
        Container(
          constraints: const BoxConstraints(minWidth: double.infinity),
          margin: const EdgeInsets.only(top: 10, bottom: 5),
          padding:
              const EdgeInsets.only(top: 10, bottom: 10, left: 8, right: 8),
          decoration: const BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.all(Radius.circular(5))),
          child: const Text('請放大地圖以檢視路線資訊',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }

  Widget stopList() {
    return Obx(() => ListView.builder(
        padding: const EdgeInsets.only(top: 5, bottom: 5),
        controller: dragableSheetController.sheetScrollController.value,
        itemCount: dragableSheetController.nearCenterStops.value.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => dragableSheetController.selectedStop.value =
                dragableSheetController.nearCenterStops.value[index],
            child: Container(
              margin: const EdgeInsets.only(top: 5, bottom: 5),
              padding:
                  const EdgeInsets.only(top: 5, bottom: 5, left: 8, right: 8),
              decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.all(Radius.circular(15))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, bottom: 5),
                        child: Text(
                          dragableSheetController.nearCenterStops.value[index]
                              ['name_zh_hk'],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Text(
                        dragableSheetController.nearCenterStops
                                .value[index]['distanceToCurrent']
                                .ceil()
                                .toString() +
                            "米",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      )
                    ],
                  ),
                  Wrap(
                      children: stopRoutes(
                          dragableSheetController.nearCenterStops.value[index]))
                ],
              ),
            ),
          );
        }));
  }

  List<Widget> stopRoutes(Map<String, dynamic> stop) {
    return dragableSheetController
        .getRouteFromStop(stop)
        .map((route) => Container(
              margin: const EdgeInsets.only(top: 2, bottom: 2, right: 3),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              decoration: const BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Text(
                route['routeName_zh_hk'],
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    log('RouteTabView build');
    return Obx(
        () => mapController.zoomLevel.value > 14 ? stopList() : zoomRequire());
  }
}

class StopDetailView extends StatelessWidget {
  StopDetailView({Key? key}) : super(key: key);

  final dragableSheetController = Get.find<DragableSheetController>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => {
        dragableSheetController.selectedStop.value = <String, dynamic>{},
        log(dragableSheetController.selectedStop.value.toString())
      },
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                Text(
                  dragableSheetController.selectedStop.value['name_zh_hk'],
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),

                //to Make Text Center
                const Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
