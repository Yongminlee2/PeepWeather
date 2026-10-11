import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../more_games.dart';

/// 개발자의 다른 게임. 저장본을 바로 그리고, 새로 받으면 다시 그린다.
class MoreGamesScreen extends StatefulWidget {
  const MoreGamesScreen({super.key});
  @override
  State<MoreGamesScreen> createState() => _MoreGamesScreenState();
}

class _MoreGamesScreenState extends State<MoreGamesScreen> {
  List<MoreGame>? _games; // null = 아직 모름
  bool _fetching = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_games != null || !_fetching) return;
    final lang = Localizations.localeOf(context).languageCode;
    MoreGames.cached().then((c) {
      if (c != null && mounted && _games == null) setState(() => _games = MoreGames.parse(c, lang: lang));
    });
    MoreGames.fetch().then((f) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        if (f != null) _games = MoreGames.parse(f, lang: lang);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = _games;
    return Scaffold(
      appBar: AppBar(title: Text(l.moreGames)),
      body: list == null || list.isEmpty
          ? Center(child: Text(_fetching ? l.moreLoading : (list == null ? l.moreOffline : l.moreEmpty)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final g = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: FutureBuilder<File?>(
                            future: MoreGames.icon(g.icon),
                            builder: (_, s) => s.data == null
                                ? Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)
                                : Image.file(s.data!, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          if (g.desc.isNotEmpty) Text(g.desc, maxLines: 3, style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      g.self
                          ? Text(l.moreNow, style: TextStyle(color: Theme.of(context).colorScheme.primary))
                          : FilledButton(onPressed: () => MoreGames.openStore(g.id), child: Text(l.moreGet)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
