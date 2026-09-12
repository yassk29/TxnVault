import 'package:get_it/get_it.dart';

import '../core/database/app_database.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
}
