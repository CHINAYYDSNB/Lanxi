library ssh_service;

export 'src/ssh_service_stub.dart'
    if (dart.library.html) 'src/ssh_service_web.dart';
