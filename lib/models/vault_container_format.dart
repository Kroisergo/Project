enum VaultContainerFormat { v3 }

VaultContainerFormat vaultContainerFormatFromVersion(int version) {
  if (version == 3) return VaultContainerFormat.v3;
  throw ArgumentError.value(version, 'version', 'Unsupported vault format');
}
