from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'Could not find typography target: {label}')
    return text.replace(old, new, 1)


def ensure_import(text: str, after: str) -> str:
    target = "import '../theme/app_typography.dart';\n"
    if target in text:
        return text
    if after not in text:
        raise RuntimeError(f'Could not place typography import after {after!r}')
    return text.replace(after, after + target, 1)


def patch_study() -> None:
    path = Path('lib/src/screens/study_screen.dart')
    text = path.read_text()
    text = ensure_import(text, "import '../services/tts_service.dart';\n")

    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                                          color: scheme.onSurfaceVariant,\n                                          fontWeight: FontWeight.w600,\n                                        ),""",
        """style: AppTypography.japanese(\n                                          Theme.of(context).textTheme.titleLarge,\n                                        ).copyWith(\n                                          color: scheme.onSurfaceVariant,\n                                        ),""",
        'study reading',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.displayLarge?.copyWith(\n                                            fontSize: 68,\n                                            fontWeight: FontWeight.w900,\n                                            letterSpacing: -2.2,\n                                          ),""",
        """style: AppTypography.japanese(\n                                            Theme.of(context).textTheme.displayLarge,\n                                          ).copyWith(\n                                            fontSize: 68,\n                                            height: 1.12,\n                                            letterSpacing: -0.6,\n                                          ),""",
        'study main Japanese word',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                                            height: 1.55,\n                                            fontWeight: FontWeight.w600,\n                                          ),""",
        """style: AppTypography.japanese(\n                                            Theme.of(context).textTheme.titleLarge,\n                                          ).copyWith(\n                                            height: 1.60,\n                                          ),""",
        'study Japanese example',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.bodyLarge?.copyWith(\n                                            color: scheme.onSurfaceVariant,\n                                            height: 1.5,\n                                          ),""",
        """style: AppTypography.japanese(\n                                            Theme.of(context).textTheme.bodyLarge,\n                                          ).copyWith(\n                                            color: scheme.onSurfaceVariant,\n                                            height: 1.55,\n                                          ),""",
        'study example reading',
    )
    path.write_text(text)


def patch_favorites() -> None:
    path = Path('lib/src/screens/favorites_screen.dart')
    text = path.read_text()
    text = ensure_import(text, "import '../services/api_service.dart';\n")

    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                            fontWeight: FontWeight.w900,\n                          ),""",
        """style: AppTypography.japanese(\n                            Theme.of(context).textTheme.titleMedium,\n                          ),""",
        'favorite Japanese word',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                              color: scheme.onSurfaceVariant,\n                            ),""",
        """style: AppTypography.japanese(\n                            Theme.of(context).textTheme.bodySmall,\n                          ).copyWith(\n                            color: scheme.onSurfaceVariant,\n                          ),""",
        'favorite reading',
    )
    path.write_text(text)


def patch_detail() -> None:
    path = Path('lib/src/screens/word_detail_screen_v2.dart')
    text = path.read_text()
    text = ensure_import(text, "import '../services/tts_service.dart';\n")

    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.headlineMedium?.copyWith(\n                              fontWeight: FontWeight.w900,\n                            ),""",
        """style: AppTypography.japanese(\n                              Theme.of(context).textTheme.headlineMedium,\n                            ),""",
        'related word modal Japanese word',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                                color: scheme.onSurfaceVariant,\n                              ),""",
        """style: AppTypography.japanese(\n                                Theme.of(context).textTheme.titleMedium,\n                              ).copyWith(\n                                color: scheme.onSurfaceVariant,\n                              ),""",
        'related word modal reading',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                            height: 1.55,\n                            fontWeight: FontWeight.w700,\n                          ),""",
        """style: AppTypography.japanese(\n                            Theme.of(context).textTheme.titleMedium,\n                          ).copyWith(\n                            height: 1.60,\n                          ),""",
        'related word modal example',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.displaySmall?.copyWith(\n                                fontWeight: FontWeight.w900,\n                                letterSpacing: -1.2,\n                              ),""",
        """style: AppTypography.japanese(\n                                Theme.of(context).textTheme.displaySmall,\n                              ).copyWith(\n                                height: 1.15,\n                                letterSpacing: -0.4,\n                              ),""",
        'detail main Japanese word',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                                  color: scheme.onSurfaceVariant,\n                                  fontWeight: FontWeight.w600,\n                                ),""",
        """style: AppTypography.japanese(\n                                  Theme.of(context).textTheme.titleLarge,\n                                ).copyWith(\n                                  color: scheme.onSurfaceVariant,\n                                ),""",
        'detail reading',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                                  height: 1.55,\n                                  fontWeight: FontWeight.w700,\n                                ),""",
        """style: AppTypography.japanese(\n                                  Theme.of(context).textTheme.titleMedium,\n                                ).copyWith(\n                                  height: 1.60,\n                                ),""",
        'detail Japanese example',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                                    color: scheme.onSurfaceVariant,\n                                    height: 1.5,\n                                  ),""",
        """style: AppTypography.japanese(\n                                    Theme.of(context).textTheme.bodyMedium,\n                                  ).copyWith(\n                                    color: scheme.onSurfaceVariant,\n                                    height: 1.55,\n                                  ),""",
        'detail example reading',
    )
    text = replace_required(
        text,
        """style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                      fontWeight: FontWeight.w900,\n                    ),""",
        """style: AppTypography.japanese(\n                      Theme.of(context).textTheme.titleMedium,\n                    ),""",
        'related tile Japanese word',
    )
    path.write_text(text)


def main() -> None:
    patch_study()
    patch_favorites()
    patch_detail()
    print('Japanese typography migration applied.')


if __name__ == '__main__':
    main()
