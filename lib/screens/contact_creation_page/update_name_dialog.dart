import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class UpdateNameDialog extends HookWidget {
  const UpdateNameDialog({this.name, super.key});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: name);
    final sheetError = useState<String?>(null);
    return GlassSheet(
        child: Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Edit Contact Name',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          GlassTextField(
            controller: nameController,
            textInputAction: TextInputAction.done,
            placeholder: 'Enter contact name',
            placeholderStyle:
                TextStyle(color: Theme.of(context).colorScheme.onSurface),
            textStyle:
                TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          if (sheetError.value != null) ...[
            const SizedBox(height: 8),
            Text(
              sheetError.value!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: [
              GlassButton(
                onTap: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              GlassButton(
                onTap: () {
                  final value = nameController.text.trim();
                  if (value.isEmpty) {
                    sheetError.value = 'Name cannot be empty.';
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                icon: Icon(Icons.check,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
