from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


def append_once(path: str, marker: str, content: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if marker in text:
        return
    file.write_text(text.rstrip() + '\n\n' + content.strip() + '\n', encoding='utf-8')


# Backend: wire configurable gamification endpoints into the existing auth/session model.
replace_once(
    'backend/app/main.py',
    "from .auth_store import AuthStore\nfrom .store import JsonWordStore\nfrom .user_data_store import UserDataStore\n",
    "from .auth_store import AuthStore\nfrom .gamification_store import GamificationStore\nfrom .store import JsonWordStore\nfrom .user_data_store import UserDataStore\n",
    'backend import',
)
replace_once(
    'backend/app/main.py',
    "user_data = UserDataStore()\n",
    "user_data = UserDataStore()\ngamification = GamificationStore()\n",
    'backend store instance',
)
replace_once(
    'backend/app/main.py',
    "class SettingsUpdate(BaseModel):\n    settings: dict[str, Any]\n",
    "class SettingsUpdate(BaseModel):\n    settings: dict[str, Any]\n\n\nclass RoundRewardClaim(BaseModel):\n    level: JlptLevel\n    chapter: int = Field(ge=0)\n    round_count: int = Field(ge=1)\n",
    'backend reward model',
)
replace_once(
    'backend/app/main.py',
    "@app.post('/api/words/{word_id}/explain')\ndef explain_word(word_id: str, user: dict = Depends(current_user)) -> dict[str, str]:\n",
    "@app.get('/api/account/leveling')\ndef get_account_leveling(user: dict = Depends(current_user)) -> dict:\n    return gamification.status(str(user['id']))\n\n\n@app.post('/api/account/attendance')\ndef claim_attendance(user: dict = Depends(current_user)) -> dict:\n    return gamification.claim_daily_attendance(str(user['id']))\n\n\n@app.post('/api/account/round-reward')\ndef claim_round_reward(\n    payload: RoundRewardClaim,\n    user: dict = Depends(current_user),\n) -> dict:\n    user_id = str(user['id'])\n    actual_round = user_data.rounds(user_id, payload.level).get(payload.chapter, 0)\n    if actual_round < payload.round_count:\n        raise HTTPException(status_code=409, detail='round completion is not recorded yet')\n    return gamification.award_round(\n        user_id,\n        level=payload.level,\n        chapter=payload.chapter,\n        round_count=payload.round_count,\n    )\n\n\n@app.post('/api/words/{word_id}/explain')\ndef explain_word(word_id: str, user: dict = Depends(current_user)) -> dict[str, str]:\n",
    'backend endpoints',
)

# Client round completion: preserve the old int API for migration, add a rewarded completion API for real study.
replace_once(
    'lib/src/services/study_progress_service.dart',
    "import 'api_service.dart';\nimport 'session_store.dart';\n",
    "import 'api_service.dart';\nimport 'gamification_service.dart';\nimport 'session_store.dart';\n\nclass RoundCompletionResult {\n  const RoundCompletionResult({required this.rounds, required this.reward});\n\n  final int rounds;\n  final ExperienceReward reward;\n}\n",
    'progress imports',
)
replace_once(
    'lib/src/services/study_progress_service.dart',
    "  Future<int> incrementRound(String level, int chapter) =>\n      _api.incrementRound(level, chapter);\n",
    "  Future<int> incrementRound(String level, int chapter) =>\n      _api.incrementRound(level, chapter);\n\n  Future<RoundCompletionResult> completeRound(\n    String level,\n    int chapter,\n  ) async {\n    final rounds = await _api.incrementRound(level, chapter);\n    final reward = await GamificationService.instance.awardRound(\n      level: level,\n      chapter: chapter,\n      roundCount: rounds,\n    );\n    return RoundCompletionResult(rounds: rounds, reward: reward);\n  }\n",
    'progress completion',
)

# App startup: claim attendance once per server-local day and only interrupt the user when it causes a level-up.
replace_once(
    'lib/src/app.dart',
    "import 'services/auth_service.dart';\nimport 'services/study_progress_service.dart';\nimport 'services/tts_service.dart';\n",
    "import 'services/auth_service.dart';\nimport 'services/gamification_service.dart';\nimport 'services/study_progress_service.dart';\nimport 'services/tts_service.dart';\n",
    'app gamification import',
)
replace_once(
    'lib/src/app.dart',
    "import 'theme/theme_controller.dart';\n",
    "import 'theme/theme_controller.dart';\nimport 'widgets/level_up_dialog.dart';\n",
    'app dialog import',
)
replace_once(
    'lib/src/app.dart',
    "    await _prepareUserSession();\n    if (!mounted) return;\n    setState(() {\n      _loading = false;\n      _authenticated = true;\n    });\n  }\n\n  Future<void> _prepareUserSession() async {\n",
    "    final attendance = await _prepareUserSession();\n    if (!mounted) return;\n    setState(() {\n      _loading = false;\n      _authenticated = true;\n    });\n    _showAttendanceLevelUp(attendance);\n  }\n\n  Future<ExperienceReward?> _prepareUserSession() async {\n",
    'app restore attendance',
)
replace_once(
    'lib/src/app.dart',
    "    await ThemeController.syncFromServer();\n  }\n\n  Future<void> _onAuthenticated() async {\n    setState(() => _loading = true);\n    await _prepareUserSession();\n    if (!mounted) return;\n    setState(() {\n      _loading = false;\n      _authenticated = true;\n    });\n  }\n",
    "    await ThemeController.syncFromServer();\n    try {\n      return await GamificationService.instance.claimDailyAttendance();\n    } catch (_) {\n      return null;\n    }\n  }\n\n  void _showAttendanceLevelUp(ExperienceReward? reward) {\n    if (reward == null || !reward.leveledUp) return;\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (mounted) LevelUpDialog.show(context, reward);\n    });\n  }\n\n  Future<void> _onAuthenticated() async {\n    setState(() => _loading = true);\n    final attendance = await _prepareUserSession();\n    if (!mounted) return;\n    setState(() {\n      _loading = false;\n      _authenticated = true;\n    });\n    _showAttendanceLevelUp(attendance);\n  }\n",
    'app login attendance',
)

# Settings: expose the prototype level values so the account system is visible and easy to verify.
replace_once(
    'lib/src/screens/settings_screen.dart',
    "import '../services/session_store.dart';\nimport '../services/tts_service.dart';\n",
    "import '../services/gamification_service.dart';\nimport '../services/session_store.dart';\nimport '../services/tts_service.dart';\n",
    'settings import',
)
replace_once(
    'lib/src/screens/settings_screen.dart',
    "  TtsVoiceOption? _selectedVoice;\n",
    "  TtsVoiceOption? _selectedVoice;\n  LevelingStatus? _leveling;\n",
    'settings state',
)
replace_once(
    'lib/src/screens/settings_screen.dart',
    "      final settings = await _tts.settings();\n      final voices = await _tts.japaneseVoices();\n      TtsVoiceOption? selected;\n",
    "      final settings = await _tts.settings();\n      final voices = await _tts.japaneseVoices();\n      LevelingStatus? leveling;\n      try {\n        leveling = await GamificationService.instance.fetchStatus();\n      } catch (_) {}\n      TtsVoiceOption? selected;\n",
    'settings load level',
)
replace_once(
    'lib/src/screens/settings_screen.dart',
    "        _selectedVoice = selected;\n        _loading = false;\n",
    "        _selectedVoice = selected;\n        _leveling = leveling;\n        _loading = false;\n",
    'settings assign level',
)
replace_once(
    'lib/src/screens/settings_screen.dart',
    "        const SizedBox(height: 22),\n        Text(\n          'TTS 설정',\n",
    "        if (_leveling != null) ...[\n          const SizedBox(height: 14),\n          _LevelingSummaryCard(status: _leveling!),\n        ],\n        const SizedBox(height: 22),\n        Text(\n          'TTS 설정',\n",
    'settings card placement',
)
replace_once(
    'lib/src/screens/settings_screen.dart',
    "class _SettingsCard extends StatelessWidget {\n",
    "class _LevelingSummaryCard extends StatelessWidget {\n  const _LevelingSummaryCard({required this.status});\n\n  final LevelingStatus status;\n\n  @override\n  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    return _SettingsCard(\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          Row(\n            children: [\n              Text(\n                'Lv.${status.level}',\n                style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                      color: scheme.primary,\n                      fontWeight: FontWeight.w900,\n                    ),\n              ),\n              const Spacer(),\n              Text(\n                '${status.experience} / ${status.xpRequired} XP',\n                style: Theme.of(context).textTheme.labelLarge?.copyWith(\n                      fontWeight: FontWeight.w800,\n                    ),\n              ),\n            ],\n          ),\n          const SizedBox(height: 10),\n          ClipRRect(\n            borderRadius: BorderRadius.circular(99),\n            child: LinearProgressIndicator(\n              minHeight: 8,\n              value: status.progress.clamp(0.0, 1.0),\n              backgroundColor: scheme.surfaceContainerHighest,\n            ),\n          ),\n          const SizedBox(height: 10),\n          Text(\n            '하루 첫 출석 +${status.dailyAttendanceXp} XP  ·  1회독 +${status.roundCompletionXp} XP',\n            style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                  color: scheme.onSurfaceVariant,\n                  fontWeight: FontWeight.w700,\n                ),\n          ),\n        ],\n      ),\n    );\n  }\n}\n\nclass _SettingsCard extends StatelessWidget {\n",
    'settings leveling widget',
)

# Study completion: award 30 XP (server configurable) and show a level-up popup when a threshold is crossed.
replace_once(
    'lib/src/screens/study_screen.dart',
    "import '../theme/theme_controller.dart';\n",
    "import '../theme/theme_controller.dart';\nimport '../widgets/level_up_dialog.dart';\nimport '../widgets/tts_pressable.dart';\n",
    'study widget imports',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "      final rounds = await _progress.incrementRound(\n        widget.level,\n        widget.chapter,\n      );\n",
    "      final completion = await _progress.completeRound(\n        widget.level,\n        widget.chapter,\n      );\n      final rounds = completion.rounds;\n",
    'study rewarded round',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "      final leave = await _showCompletionDialog(rounds);\n      if (leave && mounted) {\n",
    "      final leave = await _showCompletionDialog(\n        rounds,\n        completion.reward.xpGained,\n      );\n      if (completion.reward.leveledUp && mounted) {\n        await LevelUpDialog.show(context, completion.reward);\n      }\n      if (leave && mounted) {\n",
    'study level dialog',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "  Future<bool> _showCompletionDialog(int rounds) async {\n",
    "  Future<bool> _showCompletionDialog(int rounds, int xpGained) async {\n",
    'study completion signature',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "        final description = widget.isFinal\n            ? '${_words.length}개 단어의 알고 있음 상태를 초기화하고 $rounds회독으로 기록했어요.'\n            : '${_words.length}개 단어의 알고 있음 상태를 모두 해제하고 $rounds회독으로 기록했어요.';\n",
    "        final description = widget.isFinal\n            ? '${_words.length}개 단어의 알고 있음 상태를 초기화하고 $rounds회독으로 기록했어요.\\n+$xpGained XP'\n            : '${_words.length}개 단어의 알고 있음 상태를 모두 해제하고 $rounds회독으로 기록했어요.\\n+$xpGained XP';\n",
    'study completion XP text',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "                                child: GestureDetector(\n                                  behavior: HitTestBehavior.opaque,\n                                  onTap: () => _speakWord(current),\n                                  child: FittedBox(\n",
    "                                child: TtsPressable(\n                                  onPressed: () => _speakWord(current),\n                                  borderRadius: BorderRadius.circular(20),\n                                  child: FittedBox(\n",
    'study word press',
)
replace_once(
    'lib/src/screens/study_screen.dart',
    "                                  child: GestureDetector(\n                                    behavior: HitTestBehavior.opaque,\n                                    onTap: current.exampleJa.isEmpty\n                                        ? null\n                                        : () => _speakJapanese(current.exampleJa),\n                                    child: Text(\n",
    "                                  child: TtsPressable(\n                                    onPressed: () => _speakJapanese(current.exampleJa),\n                                    alignment: Alignment.centerLeft,\n                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),\n                                    child: Text(\n",
    'study example press',
)

# Detail screen TTS targets get the same visible press/scale feedback.
replace_once(
    'lib/src/screens/word_detail_screen_v2.dart',
    "import '../theme/theme_controller.dart';\n",
    "import '../theme/theme_controller.dart';\nimport '../widgets/tts_pressable.dart';\n",
    'detail press import',
)
replace_once(
    'lib/src/screens/word_detail_screen_v2.dart',
    "              GestureDetector(\n                behavior: HitTestBehavior.opaque,\n                onTap: () => _speakJapanese(\n                  item.reading.isNotEmpty ? item.reading : item.word,\n                ),\n                child: Row(\n",
    "              TtsPressable(\n                onPressed: () => _speakJapanese(\n                  item.reading.isNotEmpty ? item.reading : item.word,\n                ),\n                alignment: Alignment.centerLeft,\n                child: Row(\n",
    'detail related word press',
)
replace_once(
    'lib/src/screens/word_detail_screen_v2.dart',
    "                  GestureDetector(\n                    behavior: HitTestBehavior.opaque,\n                    onTap: () => _speakJapanese(item.exampleJa),\n                    child: Text(\n",
    "                  TtsPressable(\n                    onPressed: () => _speakJapanese(item.exampleJa),\n                    alignment: Alignment.centerLeft,\n                    child: Text(\n",
    'detail related example press',
)
replace_once(
    'lib/src/screens/word_detail_screen_v2.dart',
    "                  GestureDetector(\n                    behavior: HitTestBehavior.opaque,\n                    onTap: _speakWord,\n                    child: Column(\n",
    "                  TtsPressable(\n                    onPressed: _speakWord,\n                    alignment: Alignment.centerLeft,\n                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),\n                    child: Column(\n",
    'detail word press',
)
replace_once(
    'lib/src/screens/word_detail_screen_v2.dart',
    "            GestureDetector(\n              behavior: HitTestBehavior.opaque,\n              onTap: _word.exampleJa.isEmpty\n                  ? null\n                  : () => _speakJapanese(_word.exampleJa),\n              child: Container(\n",
    "            TtsPressable(\n              onPressed: () => _speakJapanese(_word.exampleJa),\n              padding: EdgeInsets.zero,\n              borderRadius: BorderRadius.circular(20),\n              child: Container(\n",
    'detail main example press',
)

print('leveling + TTS interaction migration applied')
