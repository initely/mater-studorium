import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import 'account_conflict_dialog.dart';
import 'account_notifier.dart';

/// Блок «Аккаунт» в настройках (T21, M1, US11): статус (аноним или Google с
/// почтой), кнопка «Привязать Google», сообщение о результате и диалог
/// конфликта «этот Google уже используется».
class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  var _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Итог мог прийти до открытия настроек (web: страница перезагружается
    // после возврата из Google): диалог показываем и в этом случае.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showConflictIfNeeded(ref.read(accountProvider).phase),
    );
  }

  Future<void> _showConflictIfNeeded(AccountPhase phase) async {
    if (!mounted || _dialogOpen || phase != AccountPhase.conflict) return;
    _dialogOpen = true;
    final notifier = ref.read(accountProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AccountConflictDialog(),
    );
    _dialogOpen = false;
    if (confirmed ?? false) {
      await notifier.confirmMerge();
    } else {
      await notifier.declineMerge();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(accountProvider);
    ref.listen(
      accountProvider.select((s) => s.phase),
      (_, phase) => unawaited(_showConflictIfNeeded(phase)),
    );

    final user = state.user;
    final anonymous = user?.isAnonymous ?? false;
    final String title;
    final String? subtitle;
    if (!state.available) {
      title = l10n.accountNoBackend;
      subtitle = null;
    } else if (user == null) {
      title = l10n.accountSigningIn;
      subtitle = null;
    } else if (anonymous) {
      title = l10n.accountAnonymousTitle;
      subtitle = l10n.accountAnonymousSubtitle;
    } else {
      final email = user.email;
      title = email == null || email.isEmpty
          ? l10n.accountLinkedNoEmailTitle
          : l10n.accountLinkedTitle(email);
      subtitle = l10n.accountLinkedSubtitle;
    }
    final working = state.phase == AccountPhase.working;
    final notice = state.notice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Semantics(
            header: true,
            child: Text(
              l10n.settingsAccountSection,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ),
        ListTile(
          key: const Key('account-status'),
          leading: Icon(
            anonymous || user == null
                ? Icons.account_circle_outlined
                : Icons.verified_user_outlined,
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        ),
        if (state.available && anonymous)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              key: const Key('account-link-google'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: working
                  ? null
                  : () => unawaited(
                      ref.read(accountProvider.notifier).linkGoogle(),
                    ),
              icon: working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(
                working ? l10n.accountLinkOpening : l10n.accountLinkButton,
              ),
            ),
          ),
        if (state.strandedFromUserId != null && !anonymous && user != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilledButton.tonalIcon(
              key: const Key('account-retry-merge'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: working
                  ? null
                  : () => unawaited(
                      ref.read(accountProvider.notifier).retryMerge(),
                    ),
              icon: const Icon(Icons.sync),
              label: Text(l10n.accountRetryMerge),
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                key: const Key('account-notice'),
                _noticeText(l10n, notice),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isProblem(notice) ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static bool _isProblem(AccountNotice notice) => switch (notice) {
    AccountNotice.linked || AccountNotice.signedInExisting => false,
    _ => true,
  };

  static String _noticeText(AppLocalizations l10n, AccountNotice notice) =>
      switch (notice) {
        AccountNotice.linked => l10n.accountNoticeLinked,
        AccountNotice.signedInExisting => l10n.accountNoticeSignedInExisting,
        AccountNotice.cancelled => l10n.accountNoticeCancelled,
        AccountNotice.unavailable => l10n.accountNoticeUnavailable,
        AccountNotice.network => l10n.accountNoticeNetwork,
        AccountNotice.failed => l10n.accountNoticeFailed,
        AccountNotice.mergeNotConfirmed => l10n.accountNoticeMergeNotConfirmed,
        AccountNotice.mergeFailed => l10n.accountNoticeMergeFailed,
      };
}
