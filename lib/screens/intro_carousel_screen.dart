import 'dart:async';

import 'package:contact_photos/services/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
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
                  _IntroSlide(
                    title: 'Welcome to Contact Photos',
                    body:
                        'This app helps you search for companies who text you, choose a company logo, and create a contact with that photo.',
                    icon: Icons.waving_hand_rounded,
                  ),
                  _IntroSlide(
                    title: 'Contacts Access',
                    body:
                        'We need access to your contacts so we can create a new contact with the company phone number and selected photo.',
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
                (index) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentPage.value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (permissionMessage.value != null) ...[
              Text(
                permissionMessage.value!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: isRequestingPermission.value ? null : handleNext,
              child: Text(currentPage.value == 0 ? 'Next' : 'Finish'),
            ),
            if (currentPage.value == 1) ...[
              TextButton(
                onPressed: () => unawaited(openAppSettings()),
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
