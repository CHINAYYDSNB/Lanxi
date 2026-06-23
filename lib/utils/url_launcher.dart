/// Open URL in browser.
/// Web: uses dart:html window.open
/// Native: stub (TODO: add url_launcher)
export 'src/url_launcher_stub.dart'
    if (dart.library.html) 'src/url_launcher_web.dart';
