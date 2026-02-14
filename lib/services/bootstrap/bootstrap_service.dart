import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';
import '../storage/vault_file_service.dart';

class BootstrapResult {
  final bool termsAccepted;
  final bool hasVault;

  const BootstrapResult({
    required this.termsAccepted,
    required this.hasVault,
  });
}

class BootstrapService {
  BootstrapService({
    required this.preferencesService,
    required this.vaultFileService,
  });

  final PreferencesService preferencesService;
  final VaultFileService vaultFileService;

  Future<BootstrapResult> check() async {
    final termsAccepted = await preferencesService.isTermsAccepted();
    final preferredName = await preferencesService.getVaultFileName();
    final hasVault = await vaultFileService.hasExistingVault(preferredName: preferredName);
    return BootstrapResult(
      termsAccepted: termsAccepted,
      hasVault: hasVault,
    );
  }
}

final bootstrapServiceProvider = Provider<BootstrapService>((ref) {
  return BootstrapService(
    preferencesService: ref.read(preferencesServiceProvider),
    vaultFileService: VaultFileService(),
  );
});

final bootstrapProvider = FutureProvider<BootstrapResult>((ref) async {
  final service = ref.read(bootstrapServiceProvider);
  return service.check();
});
