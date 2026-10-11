import 'package:flutter/material.dart';

import '../app_state.dart';
import '../fetcher.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../sources/openweather.dart';
import 'format.dart';
import 'quick_cities.dart';
import 'theme.dart';

/// 도시 검색 → 고르면 저장 도시에 추가하고 그 장소를 돌려준다. 검색 전엔 자주 찾는 도시를 바로 넣을 수 있다.
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
    await addPlace(widget.state, p);
    if (mounted) Navigator.of(context).maybePop(p);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: w.ink),
            decoration: InputDecoration(
              hintText: l.searchHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: w.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: w.line)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: w.line)),
            ),
            onSubmitted: _search,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.error)),
                  ),
                if (_results case final rs? when rs.isNotEmpty)
                  for (final p in rs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.place_outlined, color: w.rain),
                      title: Text(p.name, style: TextStyle(color: w.ink)),
                      subtitle: Text(p.country, style: TextStyle(color: w.muted)),
                      onTap: () => _add(p),
                    )
                else ...[
                  Text(l.searchIntro, style: TextStyle(fontSize: 15, height: 1.6, color: w.muted)),
                  const SizedBox(height: 24),
                  Text(l.quickCities, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: w.ink)),
                  const SizedBox(height: 10),
                  QuickCityChips(onPick: _add),
                ],
              ]),
      ),
    );
  }
}
