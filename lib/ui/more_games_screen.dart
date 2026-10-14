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
    // 아이폰은 앱스토어 번호가 있는 게임만(심사 지침 2.3.10 — 다른 스토어로 보내지 않는다)
    List<MoreGame> parse(String json) => MoreGames.visible(MoreGames.parse(json, lang: lang), ios: MoreGames.onIos);
    MoreGames.cached().then((c) {
      if (c != null && mounted && _games == null) setState(() => _games = parse(c));
    });
    MoreGames.fetch().then((f) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        if (f != null) _games = parse(f);
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
                          : FilledButton(onPressed: () => MoreGames.openStore(MoreGames.storeKey(g, ios: MoreGames.onIos)), child: Text(l.moreGet)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

/// 설정에 「개발자의 다른 게임」 줄을 보일지. 아이폰은 앱스토어에서 받을 다른 게임이 있을 때만 —
/// 빈 목록으로 가는 메뉴는 「준비 안 된 기능」으로 반려된다. 저장본으로 먼저 답하고([onAnswer]),
/// 하루가 지났으면 새로 받아 한 번 더 답한다. 새 게임이 앱스토어에 나오면 apps.json 에 번호만 더하면 된다.
Future<void> moreGamesAvailable(void Function(bool) onAnswer,
    {bool? ios, Future<String?> Function() cached = MoreGames.cached, Future<String?> Function() refresh = MoreGames.refreshIfStale}) async {
  if (!(ios ?? MoreGames.onIos)) return onAnswer(true);
  void apply(String? json) {
    if (json != null) onAnswer(MoreGames.hasOthers(MoreGames.parse(json), ios: true));
  }

  try {
    apply(await cached());
    apply(await refresh());
  } catch (_) {} // 못 읽으면 숨긴 채로 둔다
}
