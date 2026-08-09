import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_identity.dart';

final identityFlowProvider = StateProvider<List<UserIdentity>>((ref) => []);
