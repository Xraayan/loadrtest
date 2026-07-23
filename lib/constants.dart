import 'package:flutter/material.dart';

const kPrimaryOrange = Color(0xFFE64A19);
const kLightBackground = Color(0xFFFDEEE9); // Light tint for the language screen

double routeMarkerSizeForZoom(double zoom) =>
    (28 + (zoom - 4) * 1.5).clamp(28.0, 52.0).toDouble();

double nearbyDriverMarkerSizeForZoom(double zoom) =>
    (routeMarkerSizeForZoom(zoom) * 0.75).clamp(22.0, 40.0).toDouble();
