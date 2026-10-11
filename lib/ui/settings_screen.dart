import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../settings.dart';
import 'format.dart';

const privacyUrl = 'https://yongminlee2.github.io/legal/peepweather/privacy.html';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, this.extra = const []});
  final Settings settings;
  final List<Widget> extra; // 예: 개발자의 다른 게임

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)));
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(children: [
          SwitchListTile(
              title: Text(l.fahrenheit), value: settings.fahrenheit, onChanged: (v) => settings.update((s) => s.fahrenheit = v)),
          header(l.alerts),
          SwitchListTile(
              title: Text(l.alertRain), value: settings.alertRain, onChanged: (v) => settings.update((s) => s.alertRain = v)),
          SwitchListTile(title: Text(l.alertAir), value: settings.alertAir, onChanged: (v) => settings.update((s) => s.alertAir = v)),
          SwitchListTile(
              title: Text(l.alertStorm), value: settings.alertStorm, onChanged: (v) => settings.update((s) => s.alertStorm = v)),
          header(l.savedPlaces),
          for (final p in settings.places)
            ListTile(
              title: Text(p.name),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => settings.update((s) => s.places = [...s.places]..remove(p)),
              ),
            ),
          header(l.attribution),
          for (final (text, url) in attributions.values)
            ListTile(dense: true, title: Text(text), onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
          ...extra,
          ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l.privacy),
              onTap: () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication)),
        ]),
      ),
    );
  }
}
