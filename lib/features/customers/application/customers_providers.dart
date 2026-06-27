import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/app_database.dart';

/// Live list of saved customers (captured during billing by phone number).
final customersProvider = StreamProvider<List<Customer>>(
  (ref) => ref.watch(databaseProvider).customersDao.watchAll(),
);
