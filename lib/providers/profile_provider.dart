import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileAvatarProvider = FutureProvider<String?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final result = await Supabase.instance.client
      .from('profiles')
      .select('avatar_url')
      .eq('id', user.id)
      .maybeSingle();

  return result?['avatar_url'] as String?;
});
