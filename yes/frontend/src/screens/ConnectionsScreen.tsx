import React from 'react';
import { Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { Screen, Header, Card, SectionHeader, SegmentedControl, ListRow, Avatar, Tag, IconChip, Button } from '@/components';
import { fontSize, radius, spacing, type ThemeColors, withAlpha } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { useAppData } from '@/data/AppDataProvider';
import type { Connection, SharingMode } from '@/data/types';

type Dialog = 'add-person' | 'add-group' | 'permissions' | 'safe-arrival' | 'history' | null;

/** Connections V1, backed by the replaceable app-data repository. */
export function ConnectionsScreen(): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const data = useAppData();
  const [segment, setSegment] = React.useState('People');
  const [dialog, setDialog] = React.useState<Dialog>(null);
  const [selectedConnection, setSelectedConnection] = React.useState<Connection | null>(null);
  const [name, setName] = React.useState('');
  const [selectedMembers, setSelectedMembers] = React.useState<string[]>([]);
  const connected = data.connections.filter((item) => item.status === 'connected');
  const requests = data.connections.filter((item) => item.status !== 'connected');

  function submitPerson() {
    if (!name.trim()) return;
    data.addConnection(name);
    setName('');
    setDialog(null);
    setSegment('Requests');
  }

  function submitGroup() {
    if (!name.trim()) return;
    data.addGroup(name, selectedMembers);
    setName('');
    setSelectedMembers([]);
    setDialog(null);
  }

  return (
    <Screen>
      <Header title="Connections" showBell showAvatar />
      <SegmentedControl segments={['People', 'Groups', 'Requests']} value={segment} onChange={setSegment} />

      {segment === 'People' ? (
        <>
          <Card>
            <SectionHeader title="Live Location Sharing" action="Add person" onAction={() => setDialog('add-person')} />
            {connected.map((person) => (
              <Pressable key={person.id} style={styles.personRow} onPress={() => setSelectedConnection(person)}>
                <Avatar name={person.name} size={44} ring={person.isLive ? colors.live : undefined} dot={person.isLive ? colors.live : undefined} />
                <View style={styles.grow}>
                  <Text style={styles.personName}>{person.name}</Text>
                  <View style={styles.metaRow}>{person.isLive ? <Tag label="Live" /> : null}<Text style={styles.meta}>{person.lastUpdated}</Text></View>
                </View>
                <Text style={styles.chevron}>›</Text>
              </Pressable>
            ))}
          </Card>
          <View style={styles.pairRow}>
            <FeatureCard icon="safeArrival" color={colors.primary} title="Safe Arrival" body="Monitor a mock journey and arrival state." onPress={() => setDialog('safe-arrival')} />
            <FeatureCard icon="sos" color={colors.emergency} title="SOS Circle" body={`${data.profile.emergencyContacts.filter((item) => item.inSosCircle).length} trusted contacts`} />
          </View>
          <Card padded={false} style={styles.rowCard}>
            <ListRow icon="history" title="Location History" subtitle="Review simulated recent activity." chevron onPress={() => setDialog('history')} />
            <ListRow icon="permissions" title="Permissions" subtitle="Control who can see your location." chevron divider onPress={() => setDialog('permissions')} />
          </Card>
        </>
      ) : null}

      {segment === 'Groups' ? (
        <Card>
          <SectionHeader title="Your Groups" action="Create" onAction={() => setDialog('add-group')} />
          {data.groups.map((group) => (
            <ListRow key={group.id} icon={group.type === 'family' ? 'family' : group.type === 'business' ? 'team' : 'group'} title={group.name} subtitle={`${group.memberIds.length} member${group.memberIds.length === 1 ? '' : 's'} · ${group.type}`} trailing={<Pressable onPress={() => data.removeGroup(group.id)} hitSlop={8}><Text style={styles.removeText}>Remove</Text></Pressable>} />
          ))}
          {data.groups.length === 0 ? <Empty text="Create a family, business, or custom group." /> : null}
        </Card>
      ) : null}

      {segment === 'Requests' ? (
        <Card>
          <SectionHeader title="Friend Requests" action="Add person" onAction={() => setDialog('add-person')} />
          {requests.map((request) => (
            <View key={request.id} style={styles.requestRow}>
              <Avatar name={request.name} size={42} />
              <View style={styles.grow}><Text style={styles.personName}>{request.name}</Text><Text style={styles.meta}>{request.status === 'pending_incoming' ? 'Wants to connect' : 'Request pending'}</Text></View>
              {request.status === 'pending_incoming' ? (
                <View style={styles.inlineActions}><Button label="Accept" size="sm" onPress={() => data.acceptRequest(request.id)} /><Pressable onPress={() => data.declineRequest(request.id)}><Text style={styles.removeText}>Decline</Text></Pressable></View>
              ) : <Pressable onPress={() => data.declineRequest(request.id)}><Text style={styles.removeText}>Cancel</Text></Pressable>}
            </View>
          ))}
          {requests.length === 0 ? <Empty text="No pending requests." /> : null}
        </Card>
      ) : null}

      <FormModal visible={dialog === 'add-person'} title="Add Family or Friend" onClose={() => setDialog(null)}>
        <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="Name" placeholderTextColor={colors.textMuted} autoFocus />
        <Text style={styles.help}>A mock request will be created. It can be replaced by the client friend-request endpoint later.</Text>
        <ModalButtons onCancel={() => setDialog(null)} onDone={submitPerson} done="Send request" />
      </FormModal>

      <FormModal visible={dialog === 'add-group'} title="Create Custom Group" onClose={() => setDialog(null)}>
        <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="Group name" placeholderTextColor={colors.textMuted} autoFocus />
        <Text style={styles.fieldTitle}>Members</Text>
        {connected.map((person) => { const selected = selectedMembers.includes(person.id); return <Choice key={person.id} label={person.name} selected={selected} onPress={() => setSelectedMembers((current) => selected ? current.filter((id) => id !== person.id) : [...current, person.id])} />; })}
        <ModalButtons onCancel={() => setDialog(null)} onDone={submitGroup} done="Create" />
      </FormModal>

      <FormModal visible={dialog === 'permissions'} title="Location Permissions" onClose={() => setDialog(null)}>
        <Text style={styles.help}>Choose a sharing mode for each connection. Timed sharing uses one hour in mock mode.</Text>
        {connected.map((person) => { const permission = data.permissions.find((item) => item.connectionId === person.id); return (
          <View key={person.id} style={styles.permissionBlock}><Text style={styles.personName}>{person.name}</Text><View style={styles.modeRow}>
            {([null, 'time_based', 'permanent', 'emergency'] as const).map((mode) => <Pressable key={mode ?? 'off'} onPress={() => data.setPermission(person.id, mode, 60)} style={[styles.modeChip, (permission?.mode ?? null) === mode && styles.modeChipOn]}><Text style={[styles.modeText, (permission?.mode ?? null) === mode && styles.modeTextOn]}>{mode ? MODE_LABELS[mode] : 'Off'}</Text></Pressable>)}
          </View></View>
        ); })}
        <ModalButtons onCancel={() => setDialog(null)} onDone={() => setDialog(null)} done="Done" />
      </FormModal>

      <FormModal visible={dialog === 'safe-arrival'} title="Safe Arrival Demo" onClose={() => setDialog(null)}>
        <View style={styles.statusBanner}><IconChip icon="safeArrival" color={colors.success} /><View style={styles.grow}><Text style={styles.personName}>Mom is on the way home</Text><Text style={styles.meta}>Expected in 12 minutes · Live location active</Text></View></View>
        <Text style={styles.help}>This is a simulated journey state. Arrival, delay, and missed-arrival events will use the same UI when client endpoints arrive.</Text>
        <ModalButtons onCancel={() => setDialog(null)} onDone={() => setDialog(null)} done="Got it" />
      </FormModal>

      <FormModal visible={dialog === 'history'} title="Location History" onClose={() => setDialog(null)}>
        {connected.slice(0, 3).map((person, index) => <ListRow key={person.id} leading={<Avatar name={person.name} size={38} />} title={person.name} subtitle={`${index === 0 ? 'Carlton → Melbourne CBD' : 'Last known location'} · ${person.lastUpdated}`} />)}
        <Text style={styles.help}>Demo history only. No real location history is stored.</Text>
        <ModalButtons onCancel={() => setDialog(null)} onDone={() => setDialog(null)} done="Close" />
      </FormModal>

      <FormModal visible={selectedConnection !== null} title={selectedConnection?.name ?? ''} onClose={() => setSelectedConnection(null)}>
        <Text style={styles.fieldTitle}>Location status</Text><Text style={styles.help}>{selectedConnection?.location?.label ?? 'Location is not currently shared'} · {selectedConnection?.lastUpdated}</Text>
        <View style={styles.dangerRow}><Button label="Close" variant="outline" onPress={() => setSelectedConnection(null)} /><Button label="Remove connection" color={colors.emergency} onPress={() => { if (selectedConnection) data.removeConnection(selectedConnection.id); setSelectedConnection(null); }} /></View>
      </FormModal>
    </Screen>
  );
}

const MODE_LABELS: Record<SharingMode, string> = { time_based: '1 hour', permanent: 'Always', emergency: 'SOS only' };

function FeatureCard({ icon, color, title, body, onPress }: { icon: React.ComponentProps<typeof IconChip>['icon']; color: string; title: string; body: string; onPress?: () => void }) {
  const { colors } = useAppTheme(); const styles = React.useMemo(() => createStyles(colors), [colors]);
  return <Pressable style={styles.featureWrap} onPress={onPress}><Card style={styles.featureCard}><IconChip icon={icon} color={color} /><Text style={styles.featureTitle}>{title}</Text><Text style={styles.featureBody}>{body}</Text></Card></Pressable>;
}
function Choice({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) { const { colors } = useAppTheme(); const styles = React.useMemo(() => createStyles(colors), [colors]); return <Pressable onPress={onPress} style={styles.choice}><Text style={styles.personName}>{label}</Text><Text style={styles.check}>{selected ? '✓' : ''}</Text></Pressable>; }
function Empty({ text }: { text: string }) { const { colors } = useAppTheme(); const styles = React.useMemo(() => createStyles(colors), [colors]); return <Text style={styles.empty}>{text}</Text>; }
function FormModal({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: React.ReactNode }) { const { colors } = useAppTheme(); const styles = React.useMemo(() => createStyles(colors), [colors]); return <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}><View style={styles.modalBackground}><View style={styles.modal}><Text style={styles.modalTitle}>{title}</Text>{children}</View></View></Modal>; }
function ModalButtons({ onCancel, onDone, done }: { onCancel: () => void; onDone: () => void; done: string }) { const { colors } = useAppTheme(); const styles = React.useMemo(() => createStyles(colors), [colors]); return <View style={styles.buttonRow}><Pressable onPress={onCancel}><Text style={styles.cancelText}>Cancel</Text></Pressable><Button label={done} size="sm" onPress={onDone} /></View>; }

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    grow: { flex: 1 }, personRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: spacing.sm }, personName: { fontSize: fontSize.md, fontWeight: '700', color: colors.text }, metaRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: 3 }, meta: { fontSize: fontSize.sm, color: colors.textMuted }, chevron: { fontSize: 22, color: colors.textFaint },
    pairRow: { flexDirection: 'row', gap: spacing.md }, featureWrap: { flex: 1 }, featureCard: { flex: 1, gap: spacing.sm }, featureTitle: { fontSize: fontSize.md, fontWeight: '700', color: colors.text }, featureBody: { fontSize: fontSize.sm, color: colors.textMuted, lineHeight: 18 }, rowCard: { paddingHorizontal: spacing.md },
    requestRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.sm }, inlineActions: { alignItems: 'flex-end', gap: spacing.xs }, removeText: { color: colors.emergency, fontSize: fontSize.sm, fontWeight: '600' }, empty: { color: colors.textMuted, fontSize: fontSize.sm, textAlign: 'center', paddingVertical: spacing.lg },
    modalBackground: { flex: 1, backgroundColor: colors.scrim, justifyContent: 'center', alignItems: 'center', padding: spacing.lg }, modal: { width: '100%', maxWidth: 480, maxHeight: '85%', backgroundColor: colors.card, borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, padding: spacing.lg, gap: spacing.md }, modalTitle: { color: colors.text, fontSize: fontSize.lg, fontWeight: '800' }, input: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, color: colors.text, borderRadius: radius.sm, padding: spacing.md },
    help: { color: colors.textMuted, fontSize: fontSize.sm, lineHeight: 19 }, fieldTitle: { color: colors.text, fontSize: fontSize.sm, fontWeight: '700' }, buttonRow: { flexDirection: 'row', justifyContent: 'flex-end', alignItems: 'center', gap: spacing.lg, marginTop: spacing.sm }, cancelText: { color: colors.textMuted, fontSize: fontSize.sm, fontWeight: '600' }, choice: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.sm }, check: { color: colors.primary, fontWeight: '800' },
    permissionBlock: { gap: spacing.sm, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: spacing.sm }, modeRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }, modeChip: { paddingVertical: 6, paddingHorizontal: 10, borderRadius: radius.pill, backgroundColor: colors.surfaceAlt }, modeChipOn: { backgroundColor: colors.primary }, modeText: { color: colors.textMuted, fontSize: fontSize.xs, fontWeight: '600' }, modeTextOn: { color: colors.onAccent }, statusBanner: { flexDirection: 'row', gap: spacing.md, alignItems: 'center', backgroundColor: withAlpha(colors.success, 0.1), padding: spacing.md, borderRadius: radius.sm }, dangerRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, flexWrap: 'wrap' },
  });
}
