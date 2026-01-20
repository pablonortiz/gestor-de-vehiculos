// Conditional export para web vs mobile
export 'database_helper.dart' if (dart.library.html) 'database_helper_stub.dart';
