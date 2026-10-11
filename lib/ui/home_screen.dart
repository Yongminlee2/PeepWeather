import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import 'report_view.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// 현재 위치 + 저장 도시를 옆으로 넘겨 본다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, this.onSatellite, this.afterLocate});
  final AppState state;
  final VoidCallback? afterLocate; // 위치 권한 창 다음에 할 일(알림 권한 요청)
  final void Function(BuildContext context, Place p)? onSatellite;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _pages = PageController();
  int _page = 0;
  bool _started = false;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// 앱으로 돌아왔을 때 오래된 자료면 다시 받는다(아침에 어젯밤 자료가 남아 있지 않게).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(_page);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    st.locate(lang, l.currentLocation).then((_) {
      widget.afterLocate?.call();
      _load(0);
    });
  }

  void _load(int i) {
    final ps = st.places;
    if (i >= 0 && i < ps.length && st.isStale(ps[i])) st.refresh(ps[i]);
  }

  Future<void> _search() async {
    final added = await Navigator.of(context).push<Place>(MaterialPageRoute(builder: (_) => SearchScreen(state: st)));
    if (added == null || !mounted) return;
    final i = st.places.indexWhere((p) => placeKey(p) == placeKey(added));
    if (i >= 0 && _pages.hasClients) _pages.jumpToPage(i);
    _load(i);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([st, st.settings]),
      builder: (context, _) {
        final ps = st.places;
        if (_page >= ps.length) _page = ps.isEmpty ? 0 : ps.length - 1;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.appTitle),
            actions: [
              IconButton(tooltip: l.search, icon: const Icon(Icons.search), onPressed: _search),
              IconButton(
                  tooltip: l.settings,
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => SettingsScreen(settings: st.settings)))),
            ],
          ),
          body: ps.isEmpty
              ? (st.locating || !_started ? const Center(child: CircularProgressIndicator()) : _NoLocation(onSearch: _search))
              : Column(children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: ps.length,
                      onPageChanged: (i) {
                        setState(() => _page = i);
                        _load(i);
                      },
                      itemBuilder: (context, i) => _PlacePage(st: st, place: ps[i], onSatellite: widget.onSatellite),
                    ),
                  ),
                  if (ps.length > 1)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < ps.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor),
                          ),
                      ]),
                    ),
                ]),
        );
      },
    );
  }
}

class _PlacePage extends StatelessWidget {
  const _PlacePage({required this.st, required this.place, this.onSatellite});
  final AppState st;
  final Place place;
  final void Function(BuildContext context, Place p)? onSatellite;

  @override
  Widget build(BuildContext context) {
    final r = st.reportFor(place);
    if (r == null) {
      return Center(
          child: st.isLoading(place)
              ? const CircularProgressIndicator()
              : FilledButton(onPressed: () => st.refresh(place), child: Text(AppLocalizations.of(context).retry)));
    }
    return RefreshIndicator(
      onRefresh: () => st.refresh(place, force: true),
      child: ReportView(
        report: r,
        fahrenheit: st.settings.fahrenheit,
        onSatellite: onSatellite == null ? null : () => onSatellite!(context, place),
      ),
    );
  }
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.onSearch});
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_off, size: 48),
          const SizedBox(height: 12),
          Text(l.locationNeeded, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search), label: Text(l.search)),
          TextButton(onPressed: Geolocator.openAppSettings, child: Text(l.openLocationSettings)),
        ]),
      ),
    );
  }
}
