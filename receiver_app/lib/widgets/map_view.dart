import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_data.dart';

class LiveMapView extends StatelessWidget {
  final LocationDataModel? location;
  final bool isLoading;
  final Function(GoogleMapController) onMapCreated;

  const LiveMapView({
    super.key,
    required this.location,
    required this.isLoading,
    required this.onMapCreated,
  });

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(17.385044, 78.486671),
    zoom: 15,
  );

  Set<Marker> _buildMarkers() {
    if (location == null) return {};
    return {
      Marker(
        markerId: const MarkerId('sender_X'),
        position: LatLng(location!.latitude, location!.longitude),
        infoWindow: InfoWindow(
          title: "📍 X",
          snippet: "Accuracy: ${location!.accuracy.toStringAsFixed(1)} m",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: hasLocation
                ? CameraPosition(
                    target: LatLng(location!.latitude, location!.longitude),
                    zoom: 16,
                  )
                : _defaultCameraPosition,
            onMapCreated: onMapCreated,
            markers: _buildMarkers(),
            myLocationButtonEnabled: false,
            myLocationEnabled: false, // Receiver does NOT request own location
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),
          if (isLoading)
            Container(
              color: Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
