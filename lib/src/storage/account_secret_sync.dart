import '../account/webrtc_account.dart';
import 'account_secret_store.dart';

/// Keeps SIP passwords out of the account metadata record.
///
/// Account JSON never carries `password`; passwords live in
/// [AccountSecretStore]. Records saved by older releases still contain the
/// password in clear: [hydrate] moves it into the secret store and reports
/// that the metadata must be rewritten without it.
class AccountSecretSync {
  AccountSecretSync(this._secrets);

  final AccountSecretStore _secrets;

  Future<({List<WebRtcAccount> accounts, bool migrated})> hydrate(
    List<WebRtcAccount> stored,
  ) async {
    var migrated = false;
    final accounts = <WebRtcAccount>[];
    for (final account in stored) {
      if (account.password.isNotEmpty) {
        await _secrets.writePassword(account.id, account.password);
        migrated = true;
        accounts.add(account);
        continue;
      }
      final password = await _secrets.readPassword(account.id) ?? '';
      accounts.add(account.copyWith(password: password));
    }
    return (accounts: accounts, migrated: migrated);
  }

  Future<void> save(
    List<WebRtcAccount> accounts, {
    required Iterable<String> previousIds,
  }) async {
    final currentIds = <String>{};
    for (final account in accounts) {
      currentIds.add(account.id);
      if (account.password.isEmpty) {
        await _secrets.deletePassword(account.id);
      } else {
        await _secrets.writePassword(account.id, account.password);
      }
    }
    for (final id in previousIds) {
      if (!currentIds.contains(id)) await _secrets.deletePassword(id);
    }
  }
}
