import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';

/// 주소를 검색하고 확인하면 [AddressResult]를 pop으로 반환
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<AddressResult> _results = [];
  bool _searching = false;
  AddressResult? _selected; // 확정된 주소

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 600), () => _doSearch(value));
  }

  Future<void> _doSearch(String query) async {
    final results = await GeocodingService.search(query);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  void _selectAddress(AddressResult result) {
    setState(() {
      _selected = result;
      _results = [];
      _ctrl.text = result.shortName;
    });
    _focus.unfocus();
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('배달 주소 검색',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── 검색창 ────────────────────────────────────────────────────────
          Container(
            color: Colors.orange,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: '도로명, 건물명, 지번 검색...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() {
                              _results = [];
                              _selected = null;
                            });
                            _focus.requestFocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                ),
              ),
            ),
          ),

          // ── 검색 결과 목록 ────────────────────────────────────────────────
          if (_searching)
            const LinearProgressIndicator(
                color: Colors.orange, minHeight: 2),

          if (_results.isNotEmpty)
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.orange, size: 18),
                      ),
                      title: Text(
                        r.shortName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        r.displayName,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectAddress(r),
                    );
                  },
                ),
              ),
            )

          // ── 선택된 주소 지도 미리보기 ──────────────────────────────────────
          else if (_selected != null)
            Expanded(
              child: Column(
                children: [
                  // 지도
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter:
                                LatLng(_selected!.lat, _selected!.lng),
                            initialZoom: 16,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.delivery.customer',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(
                                    _selected!.lat, _selected!.lng),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: const Text('배달지',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const Icon(Icons.location_on,
                                        color: Colors.orange, size: 36),
                                  ],
                                ),
                              ),
                            ]),
                          ],
                        ),
                        // 다시 검색 버튼
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selected = null);
                              _focus.requestFocus();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search,
                                      size: 14, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text('다시 검색',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 선택 주소 확인 바
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            const Text('선택된 주소',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selected!.shortName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selected!.displayName,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _confirm,
                            child: const Text('이 주소로 배달받기',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )

          // ── 빈 화면 안내 ──────────────────────────────────────────────────
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_searching,
                        size: 72, color: Colors.grey.shade200),
                    const SizedBox(height: 16),
                    Text('도로명, 건물명, 지번으로 검색하세요',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('예) 광화문, 강남대로 1, 역삼동',
                        style: TextStyle(
                            color: Colors.grey.shade300, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
