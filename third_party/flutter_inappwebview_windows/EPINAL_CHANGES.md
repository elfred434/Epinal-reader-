# Épinal Windows patch

Vendored from `flutter_inappwebview_windows` 0.7.0-beta.3 on pub.dev; original license is in `LICENSE`.

A Dart method call may return an actual `nullptr` for a null result. The old `CallJsHandlerCallback::decodeResult` wrapped that pointer inside an engaged `std::optional`, and the JavaScript bridge subsequently dereferenced it. An unregistered JavaScript handler (such as epub.js's `rendered` event) can therefore crash the entire Windows process with `0xc0000005`.

- Decode a null pointer or null `EncodableValue` as `std::nullopt`.
- Defensively check the pointer and type before reading the encoded response, returning JavaScript `null` for empty or invalid replies.
- `integration_test/windows_bridge_regression_test.dart` explicitly calls a non-registered handler through the actual WebView2 bridge. Run it on Windows.

Only the Windows plugin is overridden. No changes to the Android/iOS/macOS implementations.
