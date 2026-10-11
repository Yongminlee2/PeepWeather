import 'package:flutter/material.dart';

import '../app_state.dart';
import '../fetcher.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../sources/openweather.dart';
import 'format.dart';

/// 도시 검색 → 고르면 저장 도시에 추가하고 그 장소를 돌려준다.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});
  final AppState state;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Place>? _results;
  String? _error;
  bool _busy = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final rs = await owmSearch(widget.state.fetcher, q.trim(), Localizations.localeOf(context).languageCode);
      if (!mounted) return; // 검색 중에 화면을 닫았으면
      setState(() {
        _results = rs;
        _error = rs.isEmpty ? l.noResults : null;
      });
    } on FetchError catch (e) {
      if (mounted) setState(() => _error = failText(l, e.fail));
    } catch (_) {
      if (mounted) setState(() => _error = l.failParse);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(Place p) async {
    final s = widget.state.settings;
    if (!s.places.any((x) => placeKey(x) == placeKey(p))) {
      await s.update((s) => s.places = [...s.places, p]);
    }
    if (mounted) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l.searchHint, border: InputBorder.none),
          onSubmitted: _search,
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _results == null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.searchIntro, style: const TextStyle(fontSize: 15, height: 1.6)),
                    )
                  : ListView(children: [
                  for (final p in _results ?? const <Place>[])
                    ListTile(
                      leading: const Icon(Icons.location_city),
                      title: Text(p.name),
                      subtitle: Text('${p.country} · ${p.lat.toStringAsFixed(2)}, ${p.lon.toStringAsFixed(2)}'),
                      onTap: () => _add(p),
                    ),
                ]),
    );
  }
}
