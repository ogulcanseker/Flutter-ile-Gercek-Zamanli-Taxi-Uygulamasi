import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatefulWidget {
  final LatLng? center;
  final Set<Polyline>? polylines;
  final LatLng musteriKonum;
  final LatLng taksiKonum;
  const MapWidget({
    super.key,
    this.center,
    this.polylines,
    required this.musteriKonum,
    required this.taksiKonum,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0369, 28.9850),
    zoom: 15,
  );

  BitmapDescriptor _taksiIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.center != null &&
        widget.center != oldWidget.center &&
        _controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newLatLng(widget.center!),
      );
    }
  }

  Future<void> _loadCustomMarkerIcon() async {
    _taksiIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(24, 24)),
      'assets/taxi.png',
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('musteri'),
        position: widget.musteriKonum,
        infoWindow: const InfoWindow(title: 'Müşteri (Taksim Meydanı)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
      Marker(
        markerId: const MarkerId('taksi1'),
        position: widget.taksiKonum,
        infoWindow: const InfoWindow(title: 'Taksi'),
        icon: _taksiIcon,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GoogleMap(
        initialCameraPosition: _initialPosition,
        onMapCreated: (controller) => _controller = controller,
        myLocationEnabled: false,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        mapType: MapType.normal,
        markers: _buildMarkers(),
        polylines: widget.polylines ?? {},
      ),
    );
  }
}
