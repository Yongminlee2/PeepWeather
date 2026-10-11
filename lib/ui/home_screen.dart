import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import 'report_view.dart';
import 'quick_cities.dart';
import 'search_screen.dart';
import 'theme.dart';
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

  Future<void> _pick(Place p) async {
    await addPlace(st, p);
    if (!mounted) return;
    final i = st.places.indexWhere((x) => placeKey(x) == placeKey(p));
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
              ? (st.locating || !_started ? _Waiting(l.locating) : _NoLocation(onSearch: _search, onPick: _pick))
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
      // 받아오는 동안에도 같은 하늘 카드에 장소 이름을 먼저 보여 준다
      final l = AppLocalizations.of(context);
      final loading = st.isLoading(place);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          height: 260,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF24508A), Color(0xFF4A80B4)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
            const Spacer(),
            if (loading)
              Row(children: [
                const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                const SizedBox(width: 12),
                Text(l.loadingSources, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9))),
              ])
            else
              FilledButton(
                onPressed: () => st.refresh(place),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Wx.light.ink),
                child: Text(l.retry),
              ),
          ]),
        ),
      ]);
    }
    return RefreshIndicator(
      onRefresh: () => st.refresh(place, force: true),
      child: ReportView(
        report: r,
        ledger: st.ledgerFor(place),
        fahrenheit: st.settings.fahrenheit,
        onSatellite: onSatellite == null ? null : () => onSatellite!(context, place),
      ),
    );
  }
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.onSearch, required this.onPick});
  final VoidCallback onSearch;
  final void Function(Place p) onPick;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      // 첫 화면과 같은 하늘 카드 — 위치가 없어도 바로 도시를 고를 수 있게
      Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: const [Color(0xFF24508A), Color(0xFF4A80B4)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_off_outlined, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          Text(l.whereWeather, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          Text(l.locationNeeded, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 18),
          QuickCityChips(onPick: onPick, onDark: true),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: Text(l.search),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: wx(context).ink),
            ),
            TextButton(
              onPressed: Geolocator.openAppSettings,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(l.openLocationSettings),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

/// 기다리는 동안(위치 확인·권한 창 뒤)에도 빈 화면 대신 하늘 카드.
class _Waiting extends StatelessWidget {
  const _Waiting(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          height: 260,
          padding: const EdgeInsets.all(20),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF24508A), Color(0xFF4A80B4)]),
          ),
          child: Row(children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
            const SizedBox(width: 12),
            Flexible(child: Text(text, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9)))),
          ]),
        ),
      ]);
}
