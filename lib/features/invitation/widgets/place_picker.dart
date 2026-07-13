import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/aurora_theme.dart';

/// 12 kategorinin tamamı bu bileşenin 3 konfigürasyonudur (tek-çatı tasarım):
/// MEKAN (OSM+küratörlü+havuz) / ŞEHİR (destinasyon) / MARKA (hediye).
enum PlacePickerMode { venue, destination, brand }

class PlaceSuggestion {
  final String id;
  final String name;
  final String source;
  final String? category;
  final String? street;
  final String? housenumber;
  final String? metro;
  final String? district;
  final String? website;
  final String? countryRu;
  final double? lat;
  final double? lng;

  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.source,
    this.category,
    this.street,
    this.housenumber,
    this.metro,
    this.district,
    this.website,
    this.countryRu,
    this.lat,
    this.lng,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        id: json['id'] as String,
        name: json['name'] as String,
        source: json['source'] as String? ?? 'osm',
        category: json['category'] as String?,
        street: json['street'] as String?,
        housenumber: json['housenumber'] as String?,
        metro: json['metro'] as String?,
        district: json['district'] as String?,
        website: json['website'] as String?,
        countryRu: json['country_ru'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );

  String? get address {
    if (street == null || street!.isEmpty) return null;
    return housenumber == null || housenumber!.isEmpty
        ? street
        : '$street, $housenumber';
  }

  /// Şube ayırt etme satırı: destinasyonda ülke, mekânda metro/semt + adres.
  String get subtitle {
    if (countryRu != null && countryRu!.isNotEmpty) return countryRu!;
    final ctx = (metro != null && metro!.isNotEmpty) ? metro : district;
    final parts = <String>[
      if (ctx != null && ctx.isNotEmpty) ctx,
      if (address != null) address!,
    ];
    return parts.join(' · ');
  }
}

/// Autocomplete alan: yazdıkça suggest_places RPC'den öneri, seçim
/// [onSelected] ile bildirilir. Serbest metin her zaman geçerli kalır —
/// seçimden sonra metin değişirse seçim otomatik düşer (onSelected(null)).
class PlacePicker extends StatefulWidget {
  final TextEditingController controller;
  final PlacePickerMode mode;
  final String? cityId;
  final String? category;
  final String labelText;
  final String hintText;
  final ValueChanged<PlaceSuggestion?> onSelected;

  const PlacePicker({
    super.key,
    required this.controller,
    required this.mode,
    required this.labelText,
    required this.hintText,
    required this.onSelected,
    this.cityId,
    this.category,
  });

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  Timer? _debounce;
  int _queryToken = 0;
  List<PlaceSuggestion> _results = const [];
  PlaceSuggestion? _selected;
  final _listKey = GlobalKey();

  void _revealResults() {
    // Klavye + sabit CTA listeyi gizleyebilir — görünür alana kaydır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _listKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          alignment: 0.5,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    if (_selected != null && text != _selected!.name) {
      _selected = null;
      widget.onSelected(null);
    }
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2 || _selected != null) {
      if (_results.isNotEmpty) setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final token = ++_queryToken;
    try {
      final rows = await Supabase.instance.client.rpc(
        'suggest_places',
        params: {
          'p_q': q,
          'p_kind': widget.mode.name,
          'p_city_id': widget.cityId,
          'p_category': widget.category,
          'p_limit': 6,
        },
      );
      if (!mounted || token != _queryToken) return;
      setState(() => _results = (rows as List)
          .map((r) => PlaceSuggestion.fromJson(r as Map<String, dynamic>))
          .toList());
      if (_results.isNotEmpty) _revealResults();
    } catch (_) {
      // Öneri gelmemesi engel değil — serbest metin yolu her zaman açık.
      if (mounted && token == _queryToken) {
        setState(() => _results = const []);
      }
    }
  }

  void _select(PlaceSuggestion s) {
    _selected = s;
    widget.controller.text = s.name;
    widget.controller.selection =
        TextSelection.collapsed(offset: s.name.length);
    setState(() => _results = const []);
    widget.onSelected(s);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            color: AuroraTheme.textPrimary,
            height: 1.4,
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: Icon(
              widget.mode == PlacePickerMode.brand
                  ? Icons.card_giftcard_outlined
                  : widget.mode == PlacePickerMode.destination
                      ? Icons.flight_takeoff_outlined
                      : Icons.location_on_outlined,
              color: AuroraTheme.textMuted,
            ),
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            key: _listKey,
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _results.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AuroraTheme.glassBorder),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _select(_results[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _results[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AuroraTheme.textPrimary,
                            ),
                          ),
                          if (_results[i].subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _results[i].subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12.5,
                                color: AuroraTheme.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
