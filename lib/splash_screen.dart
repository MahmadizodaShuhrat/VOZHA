import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/get_access_token_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/language_page.dart';
import 'package:vozhaomuz/shared/widgets/storage/vozhaomuz_storage.dart';

class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(getAccessTokenProvider.notifier).refreshToken();
      });
      return null;
    }, []);

    final accessToken = ref.watch(getAccessTokenProvider);

    return Scaffold(
      body: accessToken.when(
        data: (data) {
          VozhaomuzStorage().saveAccessToken(data);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (data.isEmpty) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LanguagePage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => NavigationPage()),
              );
            }
          });
          // emin
          return const Center(
            child: Text(
              textAlign: TextAlign.center,
              'Загрузка...',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w400,
                fontSize: 30,
              ),
            ),
          );
        },

        error: (error, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('🔌 Нет подключения'),
                      content: const Text(
                        'Пожалуйста, проверьте подключение к интернету.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            }
          });

          return const Center(
            child: Text(
              '❌ Нет интернета',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
