class BackgroundService {
  Future<void> init() async {}
  Future<void> enableBackgroundExecution() async {}
  Future<void> disableBackgroundExecution() async {}
  Future<void> showProgress(String title, int progress, int max) async {}
  Future<void> cancelProgress() async {}
}
