/// A fake backend with an adjustable delay.
class Api {
  static Duration latency = const Duration(milliseconds: 1200);

  static Future<T> load<T>(T value) => Future.delayed(latency, () => value);
}
