import 'package:flutter/material.dart' hide Card;
import 'package:flutter_hooks/flutter_hooks.dart';
import '../components/index.dart';
import '../theme/index.dart';
import '../theme/icons.dart';
import '../data/AppDataProvider.dart';
import '../data/types.dart';

typedef Dialog = String;

/** Connections V1, backed by the replaceable app-data repository. */
class ConnectionsScreen extends HookWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = useMemoized(() => createStyles(colors), [colors]);
    final data = useAppData(context);
    final segment = useState('People');
    final dialog = useState<Dialog?>(null);
    final selectedConnection = useState<Connection?>(null);
    final name = useState('');
    final nameController = useTextEditingController();
    final selectedMembers = useState<List<String>>([]);
    final connected = data.connections.where((item) => item.status == 'connected').toList();
    final requests = data.connections.where((item) => item.status != 'connected').toList();

    void submitPerson() {
      if (name.value.trim().isEmpty) return;
      data.addConnection(name.value);
      name.value = '';
      nameController.clear();
      dialog.value = null;
      segment.value = 'Requests';
    }

    void submitGroup() {
      if (name.value.trim().isEmpty) return;
      data.addGroup(name.value, selectedMembers.value);
      name.value = '';
      nameController.clear();
      selectedMembers.value = [];
      dialog.value = null;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Screen(
            children: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Header(title: 'Connections', showBell: true, showAvatar: true),
                SizedBox(height: spacing.md),
                SegmentedControl(
                  segments: const ['People', 'Groups', 'Requests'],
                  value: segment.value,
                  onChange: (value) => segment.value = value,
                ),

                if (segment.value == 'People') ...[
                  SizedBox(height: spacing.md),
                  Card(
                    children: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Live Location Sharing',
                          action: 'Add person',
                          onAction: () => dialog.value = 'add-person',
                        ),
                        ...connected.map((person) => InkWell(
                          onTap: () => selectedConnection.value = person,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: styles.personRow.paddingVertical),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Avatar(
                                  name: person.name,
                                  size: 44,
                                  ring: person.isLive ? colors.live : null,
                                  dot: person.isLive ? colors.live : null,
                                ),
                                SizedBox(width: styles.personRow.gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(person.name, style: styles.personName),
                                      SizedBox(height: styles.metaRow.marginTop),
                                      Row(
                                        children: [
                                          if (person.isLive) ...[
                                            const Tag(label: 'Live'),
                                            SizedBox(width: styles.metaRow.gap),
                                          ],
                                          Text(person.lastUpdated, style: styles.meta),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text('›', style: styles.chevron),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FeatureCard(
                            context: context,
                            icon: 'safeArrival',
                            color: colors.primary,
                            title: 'Safe Arrival',
                            body: 'Monitor a mock journey and arrival state.',
                            onPress: () => dialog.value = 'safe-arrival',
                          ),
                        ),
                        SizedBox(width: styles.pairRow.gap),
                        Expanded(
                          child: FeatureCard(
                            context: context,
                            icon: 'sos',
                            color: colors.emergency,
                            title: 'SOS Circle',
                            body: '${data.profile.emergencyContacts.where((item) => item.inSosCircle).length} trusted contacts',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Card(
                    padded: false,
                    children: Padding(
                      padding: EdgeInsets.symmetric(horizontal: styles.rowCard.paddingHorizontal),
                      child: Column(
                        children: [
                          ListRow(
                            icon: 'history',
                            title: 'Location History',
                            subtitle: 'Review simulated recent activity.',
                            chevron: true,
                            onPress: () => dialog.value = 'history',
                          ),
                          ListRow(
                            icon: 'permissions',
                            title: 'Permissions',
                            subtitle: 'Control who can see your location.',
                            chevron: true,
                            divider: true,
                            onPress: () => dialog.value = 'permissions',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (segment.value == 'Groups') ...[
                  SizedBox(height: spacing.md),
                  Card(
                    children: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Your Groups',
                          action: 'Create',
                          onAction: () => dialog.value = 'add-group',
                        ),
                        ...data.groups.map((group) => ListRow(
                          icon: group.type == 'family'
                            ? 'family'
                            : group.type == 'business'
                              ? 'team'
                              : 'group',
                          title: group.name,
                          subtitle: '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'} · ${group.type}',
                          trailing: GestureDetector(
                            onTap: () => data.removeGroup(group.id),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('Remove', style: styles.removeText),
                            ),
                          ),
                        )),
                        if (data.groups.isEmpty)
                          Empty(
                            context: context,
                            text: 'Create a family, business, or custom group.',
                          ),
                      ],
                    ),
                  ),
                ],

                if (segment.value == 'Requests') ...[
                  SizedBox(height: spacing.md),
                  Card(
                    children: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Friend Requests',
                          action: 'Add person',
                          onAction: () => dialog.value = 'add-person',
                        ),
                        ...requests.map((request) => Padding(
                          padding: EdgeInsets.symmetric(vertical: styles.requestRow.paddingVertical),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Avatar(name: request.name, size: 42),
                              SizedBox(width: styles.requestRow.gap),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(request.name, style: styles.personName),
                                    Text(
                                      request.status == 'pending_incoming'
                                        ? 'Wants to connect'
                                        : 'Request pending',
                                      style: styles.meta,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: styles.requestRow.gap),
                              if (request.status == 'pending_incoming')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Button(
                                      label: 'Accept',
                                      size: 'sm',
                                      onPress: () => data.acceptRequest(request.id),
                                    ),
                                    SizedBox(height: styles.inlineActions.gap),
                                    GestureDetector(
                                      onTap: () => data.declineRequest(request.id),
                                      child: Text('Decline', style: styles.removeText),
                                    ),
                                  ],
                                )
                              else
                                GestureDetector(
                                  onTap: () => data.declineRequest(request.id),
                                  child: Text('Cancel', style: styles.removeText),
                                ),
                            ],
                          ),
                        )),
                        if (requests.isEmpty)
                          Empty(
                            context: context,
                            text: 'No pending requests.',
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        FormModal(
          context: context,
          visible: dialog.value == 'add-person',
          title: 'Add Family or Friend',
          onClose: () => dialog.value = null,
          children: [
            TextField(
              controller: nameController,
              onChanged: (value) => name.value = value,
              autofocus: true,
              style: TextStyle(color: styles.input.color),
              decoration: InputDecoration(
                hintText: 'Name',
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: styles.input.backgroundColor,
                contentPadding: styles.input.padding,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(styles.input.borderRadius),
                  borderSide: BorderSide(
                    width: 1,
                    color: styles.input.borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(styles.input.borderRadius),
                  borderSide: BorderSide(
                    width: 1,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            Text(
              'A mock request will be created. It can be replaced by the client friend-request endpoint later.',
              style: styles.help,
            ),
            ModalButtons(
              context: context,
              onCancel: () => dialog.value = null,
              onDone: submitPerson,
              done: 'Send request',
            ),
          ],
        ),

        FormModal(
          context: context,
          visible: dialog.value == 'add-group',
          title: 'Create Custom Group',
          onClose: () => dialog.value = null,
          children: [
            TextField(
              controller: nameController,
              onChanged: (value) => name.value = value,
              autofocus: true,
              style: TextStyle(color: styles.input.color),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: styles.input.backgroundColor,
                contentPadding: styles.input.padding,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(styles.input.borderRadius),
                  borderSide: BorderSide(
                    width: 1,
                    color: styles.input.borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(styles.input.borderRadius),
                  borderSide: BorderSide(
                    width: 1,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            Text('Members', style: styles.fieldTitle),
            ...connected.map((person) {
              final selected = selectedMembers.value.contains(person.id);
              return Choice(
                context: context,
                label: person.name,
                selected: selected,
                onPress: () {
                  selectedMembers.value = selected
                    ? selectedMembers.value.where((id) => id != person.id).toList()
                    : [...selectedMembers.value, person.id];
                },
              );
            }),
            ModalButtons(
              context: context,
              onCancel: () => dialog.value = null,
              onDone: submitGroup,
              done: 'Create',
            ),
          ],
        ),

        FormModal(
          context: context,
          visible: dialog.value == 'permissions',
          title: 'Location Permissions',
          onClose: () => dialog.value = null,
          children: [
            Text(
              'Choose a sharing mode for each connection. Timed sharing uses one hour in mock mode.',
              style: styles.help,
            ),
            ...connected.map((person) {
              SharePermission? permission;
              for (final item in data.permissions) {
                if (item.connectionId == person.id) {
                  permission = item;
                  break;
                }
              }

              return Container(
                padding: EdgeInsets.only(top: styles.permissionBlock.paddingTop),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      width: 1,
                      color: styles.permissionBlock.borderTopColor,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name, style: styles.personName),
                    SizedBox(height: styles.permissionBlock.gap),
                    Wrap(
                      spacing: styles.modeRow.gap,
                      runSpacing: styles.modeRow.gap,
                      children: <SharingMode?>[
                        null,
                        'time_based',
                        'permanent',
                        'emergency',
                      ].map((mode) {
                        final selected = permission?.mode == mode;
                        return GestureDetector(
                          onTap: () => data.setPermission(person.id, mode, 60),
                          child: Container(
                            padding: styles.modeChip.padding,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(styles.modeChip.borderRadius),
                              color: selected
                                ? styles.modeChipOn.backgroundColor
                                : styles.modeChip.backgroundColor,
                            ),
                            child: Text(
                              mode != null ? MODE_LABELS[mode]! : 'Off',
                              style: selected ? styles.modeTextOn : styles.modeText,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            ModalButtons(
              context: context,
              onCancel: () => dialog.value = null,
              onDone: () => dialog.value = null,
              done: 'Done',
            ),
          ],
        ),

        FormModal(
          context: context,
          visible: dialog.value == 'safe-arrival',
          title: 'Safe Arrival Demo',
          onClose: () => dialog.value = null,
          children: [
            Container(
              padding: styles.statusBanner.padding,
              decoration: BoxDecoration(
                color: styles.statusBanner.backgroundColor,
                borderRadius: BorderRadius.circular(styles.statusBanner.borderRadius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconChip(icon: 'safeArrival', color: colors.success),
                  SizedBox(width: styles.statusBanner.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mom is on the way home', style: styles.personName),
                        Text(
                          'Expected in 12 minutes · Live location active',
                          style: styles.meta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'This is a simulated journey state. Arrival, delay, and missed-arrival events will use the same UI when client endpoints arrive.',
              style: styles.help,
            ),
            ModalButtons(
              context: context,
              onCancel: () => dialog.value = null,
              onDone: () => dialog.value = null,
              done: 'Got it',
            ),
          ],
        ),

        FormModal(
          context: context,
          visible: dialog.value == 'history',
          title: 'Location History',
          onClose: () => dialog.value = null,
          children: [
            ...connected.take(3).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final person = entry.value;
              return ListRow(
                leading: Avatar(name: person.name, size: 38),
                title: person.name,
                subtitle: '${index == 0 ? 'Carlton → Melbourne CBD' : 'Last known location'} · ${person.lastUpdated}',
              );
            }),
            Text(
              'Demo history only. No real location history is stored.',
              style: styles.help,
            ),
            ModalButtons(
              context: context,
              onCancel: () => dialog.value = null,
              onDone: () => dialog.value = null,
              done: 'Close',
            ),
          ],
        ),

        FormModal(
          context: context,
          visible: selectedConnection.value != null,
          title: selectedConnection.value?.name ?? '',
          onClose: () => selectedConnection.value = null,
          children: [
            Text('Location status', style: styles.fieldTitle),
            Text(
              '${selectedConnection.value?.location?.label ?? 'Location is not currently shared'} · ${selectedConnection.value?.lastUpdated ?? ''}',
              style: styles.help,
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: styles.dangerRow.gap,
              runSpacing: styles.dangerRow.gap,
              children: [
                Button(
                  label: 'Close',
                  variant: 'outline',
                  onPress: () => selectedConnection.value = null,
                ),
                Button(
                  label: 'Remove connection',
                  color: colors.emergency,
                  onPress: () {
                    if (selectedConnection.value != null) {
                      data.removeConnection(selectedConnection.value!.id);
                    }
                    selectedConnection.value = null;
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

const Map<SharingMode, String> MODE_LABELS = {
  'time_based': '1 hour',
  'permanent': 'Always',
  'emergency': 'SOS only',
};

Widget FeatureCard({
  required BuildContext context,
  required IconName icon,
  required Color color,
  required String title,
  required String body,
  VoidCallback? onPress,
}) {
  final colors = Theme.of(context).extension<ThemeColors>()!;
  final styles = createStyles(colors);
  return InkWell(
    onTap: onPress,
    borderRadius: BorderRadius.circular(radius.lg),
    child: Card(
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color),
          SizedBox(height: styles.featureCard.gap),
          Text(title, style: styles.featureTitle),
          SizedBox(height: styles.featureCard.gap),
          Text(body, style: styles.featureBody),
        ],
      ),
    ),
  );
}

Widget Choice({
  required BuildContext context,
  required String label,
  required bool selected,
  required VoidCallback onPress,
}) {
  final colors = Theme.of(context).extension<ThemeColors>()!;
  final styles = createStyles(colors);
  return InkWell(
    onTap: onPress,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: styles.choice.paddingVertical),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: styles.personName),
          Text(selected ? '✓' : '', style: styles.check),
        ],
      ),
    ),
  );
}

Widget Empty({
  required BuildContext context,
  required String text,
}) {
  final colors = Theme.of(context).extension<ThemeColors>()!;
  final styles = createStyles(colors);
  return Padding(
    padding: EdgeInsets.symmetric(vertical: styles.empty.paddingVertical),
    child: Text(
      text,
      style: styles.empty.textStyle,
      textAlign: TextAlign.center,
    ),
  );
}

Widget FormModal({
  required BuildContext context,
  required bool visible,
  required String title,
  required VoidCallback onClose,
  required List<Widget> children,
}) {
  final colors = Theme.of(context).extension<ThemeColors>()!;
  final styles = createStyles(colors);

  if (!visible) return const SizedBox.shrink();

  return Positioned.fill(
    child: Material(
      color: Colors.transparent,
      child: Container(
        color: styles.modalBackground.backgroundColor,
        padding: styles.modalBackground.padding,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: styles.modal.maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * styles.modal.maxHeight,
          ),
          child: Container(
            width: double.infinity,
            padding: styles.modal.padding,
            decoration: BoxDecoration(
              color: styles.modal.backgroundColor,
              borderRadius: BorderRadius.circular(styles.modal.borderRadius),
              border: Border.all(
                width: 1,
                color: styles.modal.borderColor,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: styles.modalTitle),
                  ...children.expand((child) => [
                    SizedBox(height: styles.modal.gap),
                    child,
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget ModalButtons({
  required BuildContext context,
  required VoidCallback onCancel,
  required VoidCallback onDone,
  required String done,
}) {
  final colors = Theme.of(context).extension<ThemeColors>()!;
  final styles = createStyles(colors);
  return Padding(
    padding: EdgeInsets.only(top: styles.buttonRow.marginTop),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onCancel,
          child: Text('Cancel', style: styles.cancelText),
        ),
        SizedBox(width: styles.buttonRow.gap),
        Button(label: done, size: 'sm', onPress: onDone),
      ],
    ),
  );
}

({
  ({int flex}) grow,
  ({double gap, double paddingVertical}) personRow,
  TextStyle personName,
  ({double gap, double marginTop}) metaRow,
  TextStyle meta,
  TextStyle chevron,
  ({double gap}) pairRow,
  ({int flex}) featureWrap,
  ({int flex, double gap}) featureCard,
  TextStyle featureTitle,
  TextStyle featureBody,
  ({double paddingHorizontal}) rowCard,
  ({double gap, double paddingVertical}) requestRow,
  ({double gap}) inlineActions,
  TextStyle removeText,
  ({TextStyle textStyle, double paddingVertical}) empty,
  ({Color backgroundColor, EdgeInsets padding}) modalBackground,
  ({
    double maxWidth,
    double maxHeight,
    Color backgroundColor,
    Color borderColor,
    double borderRadius,
    EdgeInsets padding,
    double gap,
  }) modal,
  TextStyle modalTitle,
  ({
    Color borderColor,
    Color backgroundColor,
    Color color,
    double borderRadius,
    EdgeInsets padding,
  }) input,
  TextStyle help,
  TextStyle fieldTitle,
  ({double gap, double marginTop}) buttonRow,
  TextStyle cancelText,
  ({double paddingVertical}) choice,
  TextStyle check,
  ({
    double gap,
    Color borderTopColor,
    double paddingTop,
  }) permissionBlock,
  ({double gap}) modeRow,
  ({
    EdgeInsets padding,
    double borderRadius,
    Color backgroundColor,
  }) modeChip,
  ({Color backgroundColor}) modeChipOn,
  TextStyle modeText,
  TextStyle modeTextOn,
  ({
    double gap,
    Color backgroundColor,
    EdgeInsets padding,
    double borderRadius,
  }) statusBanner,
  ({double gap}) dangerRow,
}) createStyles(ThemeColors colors) {
  return (
    grow: (flex: 1,),
    personRow: (gap: spacing.md, paddingVertical: spacing.sm),
    personName: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
    metaRow: (gap: spacing.sm, marginTop: 3),
    meta: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
    chevron: TextStyle(fontSize: 22, color: colors.textFaint),
    pairRow: (gap: spacing.md,),
    featureWrap: (flex: 1,),
    featureCard: (flex: 1, gap: spacing.sm),
    featureTitle: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
    featureBody: TextStyle(fontSize: fontSize.sm, color: colors.textMuted, height: 18 / fontSize.sm),
    rowCard: (paddingHorizontal: spacing.md,),
    requestRow: (gap: spacing.sm, paddingVertical: spacing.sm),
    inlineActions: (gap: spacing.xs,),
    removeText: TextStyle(color: colors.emergency, fontSize: fontSize.sm, fontWeight: FontWeight.w600),
    empty: (
      textStyle: TextStyle(color: colors.textMuted, fontSize: fontSize.sm),
      paddingVertical: spacing.lg,
    ),
    modalBackground: (
      backgroundColor: colors.scrim,
      padding: EdgeInsets.all(spacing.lg),
    ),
    modal: (
      maxWidth: 480,
      maxHeight: 0.85,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: radius.md,
      padding: EdgeInsets.all(spacing.lg),
      gap: spacing.md,
    ),
    modalTitle: TextStyle(color: colors.text, fontSize: fontSize.lg, fontWeight: FontWeight.w800),
    input: (
      borderColor: colors.border,
      backgroundColor: colors.background,
      color: colors.text,
      borderRadius: radius.sm,
      padding: EdgeInsets.all(spacing.md),
    ),
    help: TextStyle(color: colors.textMuted, fontSize: fontSize.sm, height: 19 / fontSize.sm),
    fieldTitle: TextStyle(color: colors.text, fontSize: fontSize.sm, fontWeight: FontWeight.w700),
    buttonRow: (gap: spacing.lg, marginTop: spacing.sm),
    cancelText: TextStyle(color: colors.textMuted, fontSize: fontSize.sm, fontWeight: FontWeight.w600),
    choice: (paddingVertical: spacing.sm,),
    check: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
    permissionBlock: (
      gap: spacing.sm,
      borderTopColor: colors.border,
      paddingTop: spacing.sm,
    ),
    modeRow: (gap: spacing.xs,),
    modeChip: (
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      borderRadius: radius.pill,
      backgroundColor: colors.surfaceAlt,
    ),
    modeChipOn: (backgroundColor: colors.primary,),
    modeText: TextStyle(color: colors.textMuted, fontSize: fontSize.xs, fontWeight: FontWeight.w600),
    modeTextOn: TextStyle(color: colors.onAccent, fontSize: fontSize.xs, fontWeight: FontWeight.w600),
    statusBanner: (
      gap: spacing.md,
      backgroundColor: withAlpha(colors.success, 0.1),
      padding: EdgeInsets.all(spacing.md),
      borderRadius: radius.sm,
    ),
    dangerRow: (gap: spacing.sm,),
  );
}