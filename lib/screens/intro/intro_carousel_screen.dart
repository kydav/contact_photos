import 'dart:async';

import 'package:contact_photos/screens/intro/intro_slide.dart';
import 'package:contact_photos/services/contacts_service.dart';
import 'package:contact_photos/ui/background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

typedef IntroFinishedCallback = Future<void> Function();

class IntroCarouselScreen extends HookWidget {
  const IntroCarouselScreen({
    required this.onFinished,
    super.key,
  });

  final IntroFinishedCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final isRequestingPermission = useState(false);
    final permissionMessage = useState<String?>(null);

    useEffect(() {
      void listener() {
        final page = pageController.page?.round() ?? 0;
        currentPage.value = page;
      }

      pageController.addListener(listener);
      return () => pageController.removeListener(listener);
    }, [pageController]);

    Future<void> handleNext() async {
      if (currentPage.value == 0) {
        await pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
        return;
      }

      isRequestingPermission.value = true;
      permissionMessage.value = null;

      try {
        final permissionResult =
            await ContactsService.requestContactsPermission();
        switch (permissionResult) {
          case ContactsPermissionResult.granted:
            permissionMessage.value = 'Contacts access granted.';
            break;
          case ContactsPermissionResult.denied:
            permissionMessage.value =
                'Contacts access denied. You can continue and allow it later.';
            break;
          case ContactsPermissionResult.permanentlyDenied:
            permissionMessage.value =
                'Contacts access is permanently denied. Enable it in settings.';
            break;
        }

        await onFinished();
      } finally {
        isRequestingPermission.value = false;
      }
    }

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      IntroSlide(
                        title: 'Welcome to Contact Photos',
                        body:
                            'This app helps you search for companies who text you, choose a company logo, and create a contact with that photo.',
                        icon: Icons.waving_hand_rounded,
                      ),
                      IntroSlide(
                        title: 'Contacts Access',
                        body:
                            'We need read and write access to your contacts to create a new contact with the company name, phone number, and selected logo.\n\nYour contact data never leaves your device. Company searches may be sent to Google Gemini AI to identify matching businesses.',
                        icon: Icons.contacts_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    2,
                    (index) => GlassContainer(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: ColoredBox(
                        color: index == currentPage.value
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (permissionMessage.value != null) ...[
                  Text(
                    permissionMessage.value!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                  const SizedBox(height: 8),
                ],
                GlassButton.custom(
                  enabled: !isRequestingPermission.value,
                  onTap: handleNext,
                  shape: const LiquidRoundedRectangle(borderRadius: 40),
                  child: Text(currentPage.value == 0 ? 'Next' : 'Allow Access'),
                ),
                if (currentPage.value == 1) ...[
                  TextButton(
                    onPressed: () => unawaited(openAppSettings()),
                    child: const Text('Open Settings'),
                  ),
                ],
                const SizedBox(height: 4),
                const _PrivacyFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: muted,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => unawaited(_open('https://auaha.app/privacy')),
          child: const Text('Privacy Policy'),
        ),
        Text('·', style: TextStyle(color: muted, fontSize: 12)),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: muted,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => unawaited(_open('https://auaha.app/terms')),
          child: const Text('Terms of Service'),
        ),
      ],
    );
  }
}
