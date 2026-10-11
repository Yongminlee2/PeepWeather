import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../settings.dart';
import 'format.dart';
import 'more_games_screen.dart';
import 'theme.dart';

const privacyUrl = 'https://yongminlee2.github.io/legal/peepweather/privacy.html';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    void open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    SwitchListTile toggle(String t, bool v, void Function(Settings, bool) set) => SwitchListTile(
          title: Text(t, style: TextStyle(color: w.ink)),
          value: v,
          onChanged: (x) => settings.update((s) => set(s, x)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            _Group(children: [toggle(l.fahrenheit, settings.fahrenheit, (s, x) => s.fahrenheit = x)]),
            _Group(title: l.alerts, children: [
              toggle(l.alertRain, settings.alertRain, (s, x) => s.alertRain = x),
              toggle(l.alertAir, settings.alertAir, (s, x) => s.alertAir = x),
              toggle(l.alertStorm, settings.alertStorm, (s, x) => s.alertStorm = x),
            ]),
            _Group(title: l.savedPlaces, children: [
              if (settings.places.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.noPlaces, style: TextStyle(height: 1.5, color: w.muted)),
                ),
              for (final p in settings.places)
                ListTile(
                  leading: Icon(Icons.place_outlined, color: w.rain),
                  title: Text(p.name, style: TextStyle(color: w.ink)),
                  trailing: IconButton(
                    tooltip: l.delete,
                    icon: Icon(Icons.delete_outline, color: w.muted),
                    onPressed: () => settings.update((s) => s.places = [...s.places]..remove(p)),
                  ),
                ),
            ]),
            _Group(title: l.about, children: [
              // 출처 목록은 길어서 접어 둔다
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(Icons.public, color: w.muted),
                  title: Text(l.attribution, style: TextStyle(color: w.ink)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final (text, url) in attributions.values)
                      InkWell(
                        onTap: () => open(url),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(text, style: TextStyle(fontSize: 13, color: w.muted, decoration: TextDecoration.underline)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                  leading: Icon(Icons.apps, color: w.muted),
                  title: Text(l.moreGames, style: TextStyle(color: w.ink)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoreGamesScreen()))),
              ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: w.muted),
                  title: Text(l.privacy, style: TextStyle(color: w.ink)),
                  onTap: () => open(privacyUrl)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// 설정 묶음: 제목 + 흰 바탕 둥근 상자 안에 줄들(줄 사이 가는 선).
class _Group extends StatelessWidget {
  const _Group({this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final w = wx(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: w.muted)),
          ),
        // Material 이어야 줄을 눌렀을 때 물결이 보인다
        Material(
          color: w.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: w.line),
                children[i],
              ],
          ]),
        ),
      ]),
    );
  }
}
