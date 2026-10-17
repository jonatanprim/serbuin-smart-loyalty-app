import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart';
import 'services/mock_database_service.dart';
import 'theme/app_theme.dart';
import 'views/auth/role_selection_view.dart';
import 'views/customer/customer_main_view.dart';
import 'views/merchant/merchant_main_view.dart';
import 'widgets/responsive_mobile_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  final dbService = MockDatabaseService();

  await dbService.init();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: dbService),
      ],
      child: const SerbuinApp(),
    ),
  );
}

class SerbuinApp extends StatelessWidget {
  const SerbuinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serbuin - Smart Loyalty App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return ResponsiveMobileWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const RootNavigationRouter(),
    );
  }
}

class RootNavigationRouter extends StatelessWidget {
  const RootNavigationRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = auth.currentUser;
    if (user == null) {
      return const RoleSelectionView();
    }

    if (user.role == UserRole.merchant) {
      return MerchantMainView(user: user);
    } else {
      return CustomerMainView(user: user);
    }
  }
}
