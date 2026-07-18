#!/usr/bin/env python3
# temp debug: log when the group-unread bump fires + the value, so the next log
# tells us if the DB write happens (vs a render problem). strip before public.
# run from ~/halo/mobile.
import io
p = 'lib/main.dart'
s = io.open(p, encoding='utf-8').read()
old = """    } else if (isGroup && env.groupId != null) {
      final openGroup = 'group:${env.groupId}';
      if (currentChatPeer != openGroup) {
        await db.bumpGroupUnread(env.groupId!);
      } else {
        await db.clearGroupUnread(env.groupId!);
      }
    }"""
new = """    } else if (isGroup && env.groupId != null) {
      final openGroup = 'group:${env.groupId}';
      if (currentChatPeer != openGroup) {
        await db.bumpGroupUnread(env.groupId!);
        debugPrint('GRPUNREAD bump ${env.groupId} cur=$currentChatPeer');
      } else {
        await db.clearGroupUnread(env.groupId!);
        debugPrint('GRPUNREAD clear ${env.groupId} (open)');
      }
    }"""
c = s.count(old); assert c == 1, f"anchor x{c}"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print('dbg_unread ok')
