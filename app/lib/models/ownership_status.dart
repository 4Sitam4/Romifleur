/// Ownership status of a ROM (for local library comparison)
enum OwnershipStatus {
  /// ROM not found locally
  notOwned,

  /// Same title found (different region/revision)
  partialMatch,

  /// Exact file found
  fullMatch,
}
