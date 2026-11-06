# Épinal local adaptation

This is `flutter_epub_viewer` 2.2.1, BSD 3-Clause-licensed (see LICENSE). Épinal adds `captureViewport()` to the public controller and platform interface so the optional page-curl mode can animate an in-memory screenshot of the current EPUB viewport. The web implementation returns null and the reader falls back to a normal turn. No EPUB or screenshot is sent to a server or saved. To update this dependency, reapply this small bridge change and test page navigation on real devices.

The bundled JavaScript assets are in `bundle/` instead of `dist/` so they survive workspace snapshots. The HTML and package asset manifest point to the renamed folder.
