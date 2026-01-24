import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/data/model/global/response_model/response_model.dart';
import 'package:ovorideuser/data/model/location/prediction.dart';
import 'package:ovorideuser/data/repo/location/location_search_repo.dart';

class LocationService {
  LocationSearchRepo repo = Get.find();
  TextEditingController pickupController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  int selectedIndex = 0;

  void getLocation() async {}

  //ADDRESS search+

  bool isSearched = false;
  List<Prediction> allPredictions = [];
  Future<void> searchYourAddress({String locationName = ''}) async {
    try {
      ResponseModel? response;
      PlacesAutocompleteResponse? subscriptionResponse;
      if (locationName.isNotEmpty) {
        allPredictions.clear();
        response = await repo.searchAddressByLocationName(text: locationName);

        subscriptionResponse = PlacesAutocompleteResponse.fromJson(
            jsonDecode(response!.responseJson));
      } else {
        allPredictions.clear();
        return;
      }
      if (subscriptionResponse.predictions!.isNotEmpty) {
        allPredictions.clear();
        allPredictions.addAll(subscriptionResponse.predictions!);
      }
    } catch (e) {
      printX(e.toString());
    }
  }
}
