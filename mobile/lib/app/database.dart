// SPDX-License-Identifier: GPL-3.0-or-later
// the database: HaloDb with its tables and upgrade steps

part of '../main.dart';

class HaloDb implements GroupOwedStore {
  HaloDb([this.container = HaloContainer.everyday]);

  // a wrapped container, under the key its pin entry unwrapped. storage is
  // never read or written for it, and the key goes on close
  HaloDb.withKey(this.container, String keyHex) : _given = "x'$keyHex'" {
    if (!container.wrapped) {
      throw ArgumentError('${container.dbFile} has a key of its own');
    }
    // anything else would be taken as a passphrase and open another file
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw ArgumentError('a raw key is 64 hex characters');
    }
  }

  // whose database this is: its file, and where its key sits
  final HaloContainer container;

  static const _storage = secureStore;

  Database? _db;
  String? _given;

  // 32 bytes from the platform csprng, made once, before its database
  // file. a read that fails or gives up throws, and boot shows it: a new
  // key is made only while no file exists that the old one opens
  Future<String> _passphrase() async {
    final given = _given;
    if (given != null) return given;
    final name = container.keyName;
    if (name == null) throw StateError('${container.dbFile} has no key here');
    final kept = await keyStoreCall(() => _storage.read(key: name));
    if (kept != null) return kept;
    if (await File(await container.dbPath()).exists()) {
      throw StateError('${container.dbFile} has no key here');
    }
    final pw = container.newKey();
    // no file is made under a key until its write has answered. one that
    // gives up may still land, and the next read waits for it
    await keyStoreCall(() => _storage.write(key: name, value: pw));
    return pw;
  }

  // folds the write-ahead log into the file before it is copied. a
  // backup reads halo.db as bytes, and without this the last minutes of
  // messages could still be sitting in the sidecar. a failure is passed on:
  // a copy made without it would miss them and still look whole. a reader
  // holding the log says busy, and is waited out a few times before that
  Future<void> checkpoint() async {
    final db = _db;
    if (db == null) return;
    for (var i = 1; ; i++) {
      final r = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      if (r.isEmpty || r.first['busy'] != 1) return;
      if (i == 5) throw StateError('the log stayed busy');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  // before its files go
  Future<void> close() async {
    final d = _db;
    _db = null;
    _given = null;
    _unfinished = null;
    _strandedLit = false;
    await d?.close();
  }

  // its file is open. a sweep never opens one shut: a restore, a removal
  // or a wipe is putting other files in its place
  bool get isOpen => _db != null;

  // a restore is putting another file where this one is: closed, and never
  // opened again by this process, so nothing is stored, and acknowledged,
  // in a file that is gone at the restart
  bool _retired = false;
  Future<void> retire() async {
    _retired = true;
    await close();
  }

  // the file copied to [to] whole: a read holds the lock that keeps every
  // writer out until the copy is done
  Future<void> copyTo(String to) async {
    final db = await open();
    await checkpoint();
    await db.transaction((t) async {
      await t.rawQuery('SELECT COUNT(*) FROM sqlite_master');
      await File(await container.dbPath()).copy(to);
    });
  }

  // the people and groups a chat is held with: a deleted chat's row stays,
  // archived and not accepted, and is none
  Future<({Set<String> people, Set<String> groups})> draftChats() async {
    final d = await open();
    final people = await d.query(
      'contacts',
      columns: ['halo_id', 'accepted', 'archived'],
    );
    final groups = await d.query('groups', columns: ['group_id']);
    return (
      people: {
        for (final r in people)
          if (r['accepted'] != 0 || r['archived'] != 1) r['halo_id'] as String,
      },
      groups: {for (final r in groups) r['group_id'] as String},
    );
  }

  // a wrapped container copied for a backup, and the key it opens with,
  // which the backup carries inside its own encryption
  Future<String> copyWithKey(String to) async {
    final key = _given;
    if (key == null) throw StateError('${container.dbFile} has no key here');
    await copyTo(to);
    return key.substring(2, key.length - 1);
  }

  // a wrapped container attached to another database's connection under
  // its own key, so rows move between the two a statement at a time. the
  // key stays in here
  Future<void> attachTo(Database db, String schema) async {
    final key = _given;
    if (key == null) throw StateError('${container.dbFile} has no key here');
    await db.execute('ATTACH DATABASE ? AS $schema KEY ?', [
      await container.dbPath(),
      key,
    ]);
  }

  Future<Database> open() async {
    if (_retired) throw StateError('${container.dbFile} was replaced');
    if (_db != null) return _db!;
    final path = await container.dbPath();
    final pw = await _passphrase();
    // photo files an upgrade took in, shredded once it is written
    var adopted = const <String>[];
    _db = await openDatabase(
      path,
      password: pw,
      version: 85,
      onConfigure: eraseFreedPages,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE identity (
            id TEXT PRIMARY KEY,
            ed_priv TEXT NOT NULL,
            x_priv TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            halo_id TEXT PRIMARY KEY,
            onion TEXT NOT NULL,
            xpub TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen INTEGER NOT NULL,
            back_paired INTEGER NOT NULL DEFAULT 0,
            nickname TEXT,
            blocked INTEGER NOT NULL DEFAULT 0,
            muted INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0,
            verified INTEGER NOT NULL DEFAULT 0,
            verified_key TEXT,
            unread INTEGER NOT NULL DEFAULT 0,
            atmosphere TEXT,
            note TEXT,
            pinned INTEGER NOT NULL DEFAULT 0,
            key_changed INTEGER NOT NULL DEFAULT 0,
            peer_bundle TEXT,
            accepted INTEGER NOT NULL DEFAULT 1,
            supporter_badge TEXT,
            avatar INTEGER,
            vouched_by TEXT,
            vouched_at INTEGER,
            voice_disguise INTEGER,
            name_check INTEGER NOT NULL DEFAULT 0,
            ack_owed INTEGER NOT NULL DEFAULT 0,
            shots_on INTEGER NOT NULL DEFAULT 0,
            shots_at INTEGER NOT NULL DEFAULT 0,
            shots_can INTEGER NOT NULL DEFAULT 0,
            shots_by INTEGER NOT NULL DEFAULT 0,
            shots_when INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            plaintext TEXT NOT NULL,
            sent_at INTEGER NOT NULL,
            burn_at INTEGER,
            msg_uid TEXT,
            reply_to TEXT,
            group_id TEXT,
            edited INTEGER NOT NULL DEFAULT 0,
            pinned INTEGER NOT NULL DEFAULT 0,
            pinned_at INTEGER,
            secure INTEGER NOT NULL DEFAULT 0,
            media_path TEXT,
            file_path TEXT,
            file_name TEXT,
            voice_disguised INTEGER NOT NULL DEFAULT 0,
            saved INTEGER NOT NULL DEFAULT 0,
            sent INTEGER NOT NULL DEFAULT 1,
            delivered INTEGER NOT NULL DEFAULT 0,
            preview TEXT,
            pow_nonce INTEGER,
            burn_secs INTEGER,
            poll TEXT,
            sticker TEXT,
            burn_unseen INTEGER NOT NULL DEFAULT 0,
            via_dev INTEGER NOT NULL DEFAULT 0,
            written_at INTEGER,
            album_id TEXT,
            album_n INTEGER,
            album_i INTEGER,
            FOREIGN KEY (peer_id) REFERENCES contacts(halo_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE reactions (
            msg_uid TEXT NOT NULL,
            reactor TEXT NOT NULL,
            emoji TEXT NOT NULL,
            reacted_at INTEGER NOT NULL,
            PRIMARY KEY (msg_uid, reactor)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_msg_uid ON messages(msg_uid)',
        );
        await db.execute(
          'CREATE INDEX idx_messages_group_id ON messages(group_id)',
        );
        await burnIndex(db);
        await writtenOrder(db);
        await albumIndex(db);
        await db.execute('''
          CREATE TABLE groups (
            group_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            admin_id TEXT,
            unread INTEGER NOT NULL DEFAULT 0,
            atmosphere TEXT,
            room_priv TEXT,
            room_pub TEXT,
            expires_at INTEGER,
            creator_pub TEXT,
            fc_pk TEXT,
            member_cap INTEGER,
            room_seen INTEGER NOT NULL DEFAULT 0,
            mentioned INTEGER NOT NULL DEFAULT 0,
            joining_at INTEGER,
            door_priv TEXT,
            door_pub TEXT,
            door_was TEXT,
            voice_disguise INTEGER,
            ended_at INTEGER,
            ended_by TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE group_members (
            group_id TEXT NOT NULL,
            halo_id TEXT NOT NULL,
            joined_at INTEGER NOT NULL,
            PRIMARY KEY (group_id, halo_id),
            FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE seen_msgs (
            hash TEXT PRIMARY KEY,
            ts INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE media_chunks (
            media_id TEXT NOT NULL,
            idx INTEGER NOT NULL,
            slice TEXT NOT NULL,
            total INTEGER NOT NULL,
            burn INTEGER,
            at INTEGER NOT NULL,
            sender TEXT,
            group_id TEXT,
            PRIMARY KEY (media_id, idx)
          )
        ''');
        await _vouchTable(db);
        await _shieldTable(db);
        await _editsTable(db);
        await _pinsTable(db);
        await _framesTable(db);
        await _mediaWantsTable(db);
        await _heldTable(db);
        await _signalTables(db);
        await _pollTables(db);
        await searchTables(db, fresh: true);
        await routerTables(db);
        await _devChatTables(db);
        await _devSignalTables(db);
        await _supportTables(db);
        await groupOwedTables(db);
        await groupCtlTables(db);
        await _goneTable(db);
        await blockTables(db);
        await firstContactTables(db);
        await roomKeysTable(db);
        await frameOrderTable(db);
        await notifTagTables(db);
        await groupResentTables(db);
        await notifRingTables(db);
        await blockedKeysTable(db);
        await groupEndIndexes(db);
        await wallpaperTable(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // 62 runs after every older step, below: its index names columns
        // they add. 66 runs after it: it reads what they all make. 67 to 85
        // last
        if (oldV < 65) {
          // a room joined off a link and not let in yet: when the join went
          await roomJoiningColumn(db);
        }
        if (oldV < 64) {
          // what someone blocked sent, and what came in and went
          await upgradeTo64(db, oldV);
        }
        if (oldV < 61) {
          // the number on the next room frame this phone sends
          await addColumn(
            db,
            'ALTER TABLE group_roster ADD COLUMN seq INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 60) {
          // group controls queued per member, and each group's roster stamp
          await groupCtlTables(db);
        }
        if (oldV < 59) {
          // what a group file's send left owed, member by member
          await groupOwedTables(db);
        }
        if (oldV < 58) {
          // unsends and reactions queue like edits
          await _framesTable(db);
        }
        if (oldV < 57) {
          // who sent each slice of an unfinished file
          await addColumn(
            db,
            'ALTER TABLE media_chunks ADD COLUMN sender TEXT',
          );
        }
        if (oldV < 56) {
          // the developer's own phone: its support inbox
          await _supportTables(db);
        }
        if (oldV < 55) {
          // the anonymous dev chat's own signal store
          await _devSignalTables(db);
        }
        if (oldV < 54) {
          // the developer chat's row: an upgrade shows it once, as a fresh
          // install does
          await _devChatTables(db);
        }
        if (oldV < 53) {
          // the hidden chats' list, their sealing key and what came sealed
          await routerTables(db);
        }
        if (oldV < 52) {
          // stickers: the wire value on the row
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN sticker TEXT');
        }
        if (oldV < 51) {
          // search: the index starts empty and fills from the oldest
          // message up, in the background, a batch at a time
          await searchTables(db);
        }
        if (oldV < 50) {
          // polls: the options on the row, the votes beside it
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN poll TEXT');
          await _pollTables(db);
        }
        if (oldV < 49) {
          await _mediaWantsTable(db);
        }
        if (oldV < 48) {
          // when a message was pinned, so the list of pins can run newest
          // first. pins from before have none and sort by their own time.
          await _pinsTable(db);
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pinned_at INTEGER',
          );
        }
        if (oldV < 47) {
          // the reader-side title cache is unused
          try {
            await db.execute('DROP TABLE IF EXISTS link_titles');
          } catch (e) {
            dlog('migration 47: $e');
          }
        }
        if (oldV < 46) {
          // onion-lane messages past the stranger cap, kept for accept
          await _heldTable(db);
        }
        if (oldV < 45) {
          // edits that have not reached the other side yet
          await _editsTable(db);
        }
        if (oldV < 44) {
          // the burn window a queued message was sent with, since burn_at is
          // only set on delivery
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN burn_secs INTEGER',
          );
        }
        if (oldV < 43) {
          // the link title cache rides the same helper as the shield table
          // (create if missing), so an existing phone gets it too
          await _shieldTable(db);
        }
        if (oldV < 42) {
          // a group where someone wrote your three words after an @, so the
          // home row can say so. cleared with the unread count.
          await addColumn(
            db,
            'ALTER TABLE groups ADD COLUMN mentioned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 41) {
          // the proof-of-work a stranger's first message was sent with, so
          // an opener the outbox retries is not dropped on the far side
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pow_nonce INTEGER',
          );
        }
        if (oldV < 40) {
          // burner rooms live in the groups table with their own key and a
          // clock
          for (final col in const [
            'room_priv TEXT',
            'room_pub TEXT',
            'expires_at INTEGER',
            'creator_pub TEXT',
            'fc_pk TEXT',
            'member_cap INTEGER',
            'room_seen INTEGER NOT NULL DEFAULT 0',
          ]) {
            await addColumn(db, 'ALTER TABLE groups ADD COLUMN $col');
          }
        }
        if (oldV < 39) {
          // what the scam shield flagged on a stranger, and whether the
          // person told it to drop the matter.
          await _shieldTable(db);
        }
        if (oldV < 38) {
          // one person can be vouched for by several people we know. the
          // single vouched_by column stays but is unused: dropping columns on
          // a phone is not worth it.
          await _vouchTable(db);
          try {
            await db.execute('''
              INSERT OR IGNORE INTO vouches (halo_id, voucher_id, note, created_at)
              SELECT halo_id, vouched_by, NULL,
                     IFNULL(vouched_at, first_seen)
              FROM contacts WHERE vouched_by IS NOT NULL
            ''');
          } catch (e) {
            dlog('migrate v38: backfill skipped ($e)');
          }
        }
        if (oldV < 37) {
          // who introduced this contact, so their request skips the stranger
          // gate
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN vouched_by TEXT',
          );
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN vouched_at INTEGER',
          );
        }
        if (oldV < 36) {
          // the face a contact picked, so we draw theirs and not a
          // default derived from their id.
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN avatar INTEGER');
        }
        if (oldV < 35) {
          // the sender can ask that a message not be screenshotted. we
          // keep the flag so it still holds after a restart
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN secure INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 34) {
          // partial media on disk, so a restart does not lose it
          await db.execute('''
            CREATE TABLE IF NOT EXISTS media_chunks (
              media_id TEXT NOT NULL,
              idx INTEGER NOT NULL,
              slice TEXT NOT NULL,
              total INTEGER NOT NULL,
              burn INTEGER,
              at INTEGER NOT NULL,
              sender TEXT,
              group_id TEXT,
              PRIMARY KEY (media_id, idx)
            )
          ''');
        }
        if (oldV < 33) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN delivered INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 32) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN supporter_badge TEXT',
          );
        }
        if (oldV < 31) {
          // duplicate msg_uids break every uid-keyed widget key. keep the
          // original row per uid, drop the copies.
          await db.execute('''
            DELETE FROM messages WHERE msg_uid IS NOT NULL AND id NOT IN (
              SELECT MIN(id) FROM messages WHERE msg_uid IS NOT NULL
              GROUP BY msg_uid
            )
          ''');
        }
        if (oldV < 30) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN peer_bundle TEXT',
          );
        }
        if (oldV < 29) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN atmosphere TEXT');
        }
        if (oldV < 28) {
          await addColumn(
            db,
            'ALTER TABLE groups ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 27) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS seen_msgs (
              hash TEXT PRIMARY KEY,
              ts INTEGER NOT NULL
            )
          ''');
        }
        if (oldV < 26) {
          // message requests: existing contacts stay accepted (default 1),
          // only new unknown senders arrive unaccepted.
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN accepted INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 25) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN admin_id TEXT');
        }
        if (oldV < 24) {
          await addColumn(db, 'ALTER TABLE groups ADD COLUMN description TEXT');
        }
        if (oldV < 23) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN preview TEXT');
        }
        if (oldV < 22) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN voice_disguised INTEGER NOT NULL DEFAULT 0',
          );
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN saved INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 21) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN file_path TEXT');
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN file_name TEXT');
        }
        if (oldV < 20) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN key_changed INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 19) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN sent INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 2) await _signalTables(db);
        if (oldV < 3) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN burn_at INTEGER',
          );
        }
        if (oldV < 4) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN back_paired INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 5) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN msg_uid TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_msg_uid ON messages(msg_uid)',
          );
          await db.execute('''
            CREATE TABLE reactions (
              msg_uid TEXT NOT NULL,
              reactor TEXT NOT NULL,
              emoji TEXT NOT NULL,
              reacted_at INTEGER NOT NULL,
              PRIMARY KEY (msg_uid, reactor)
            )
          ''');
        }
        if (oldV < 6) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN reply_to TEXT');
        }
        if (oldV < 8) {
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN nickname TEXT');
        }
        if (oldV < 9) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 10) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 11) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN muted INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 12) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 13) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 14) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 16) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 17) {
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN atmosphere TEXT',
          );
        }
        if (oldV < 18) {
          await addColumn(db, 'ALTER TABLE contacts ADD COLUMN note TEXT');
          await addColumn(
            db,
            'ALTER TABLE contacts ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 15) {
          await addColumn(
            db,
            'ALTER TABLE messages ADD COLUMN media_path TEXT',
          );
        }
        if (oldV < 7) {
          await addColumn(db, 'ALTER TABLE messages ADD COLUMN group_id TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id)',
          );
          // the whole table as a fresh install gets it: the later column
          // migrations run before this block
          await db.execute('''
            CREATE TABLE groups (
              group_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              created_at INTEGER NOT NULL,
              is_admin INTEGER NOT NULL DEFAULT 0,
              admin_id TEXT,
              unread INTEGER NOT NULL DEFAULT 0,
              atmosphere TEXT,
              room_priv TEXT,
              room_pub TEXT,
              expires_at INTEGER,
              creator_pub TEXT,
              fc_pk TEXT,
              member_cap INTEGER,
              room_seen INTEGER NOT NULL DEFAULT 0,
              mentioned INTEGER NOT NULL DEFAULT 0,
              joining_at INTEGER,
              door_priv TEXT,
              door_pub TEXT,
              door_was TEXT,
              voice_disguise INTEGER,
              ended_at INTEGER,
              ended_by TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE group_members (
              group_id TEXT NOT NULL,
              halo_id TEXT NOT NULL,
              joined_at INTEGER NOT NULL,
              PRIMARY KEY (group_id, halo_id),
              FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldV < 62) {
          // after every older step: the index names burn_at and burn_secs
          await burnUnseenTables(db);
        }
        if (oldV < 66) {
          // after every older step: it reads contacts.verified and the
          // signal store's peer_identities
          await verifiedKeyColumn(db);
        }
        if (oldV < 67) {
          // a contact's message that came through the developer chat
          await viaDevColumn(db);
        }
        if (oldV < 68) {
          // a room whose maker reset its link: the key its new link knocks on
          await roomDoorColumns(db);
        }
        if (oldV < 69) {
          // a held slice's file and its place in it
          await heldMediaColumn(db);
        }
        if (oldV < 70) {
          // openers that did not file, and openers sent with no receipt
          await firstContactTables(db);
        }
        if (oldV < 71) {
          // a group file's slices by group, and every key a room listened to
          await roomTeardownTables(db);
        }
        if (oldV < 72) {
          // tries on disk for queued edits, pins and frames, and the order
          // of edits and reactions taken in
          await queueTurnColumns(db);
        }
        if (oldV < 73) {
          // the random tag each chat's notifications go under
          await notifTagTables(db);
        }
        if (oldV < 74) {
          // which groups' texts went again to a member after a restore
          await groupResentTables(db);
        }
        if (oldV < 75) {
          // when a span seeded at 64 is listened on from
          await blockListenColumn(db);
        }
        if (oldV < 76) {
          // a chat's own choice to disguise the voice
          await voiceDisguiseColumns(db);
        }
        if (oldV < 77) {
          // whether the name someone goes by here was checked
          await nameCheckColumn(db);
        }
        if (oldV < 78) {
          // when each message was written: the order a chat shows
          await writtenAtColumn(db);
        }
        if (oldV < 79) {
          // which message each notification rang for
          await notifRingTables(db);
        }
        if (oldV < 80) {
          // an accept whose word to them has not gone yet
          await upgradeTo80(db, oldV);
        }
        // test builds of one step each took 81 for it: a file at 81 to 84
        // runs every step to 85 again, each safe twice
        if (oldV < 85) {
          // keys blocked as not who they said. a file made before this
          // build took 80 for itself may lack the column 80 adds
          await blockedKeysTable(db);
          await ackOwedColumn(db);
        }
        if (oldV < 85) {
          // a group its admin ended
          await groupEndColumns(db);
        }
        if (oldV < 85) {
          // a chat's screenshot block, as both phones hold it
          await shotsColumns(db);
        }
        if (oldV < 85) {
          // the album each photo or video was sent in
          await albumColumns(db);
        }
        if (oldV < 85) {
          // chats' wallpaper photos and the default, kept in here, and the
          // photo files of before taken in
          await wallpaperTable(db);
          adopted = await adoptWallpaperFiles(
            db,
            p.join(p.dirname(path), 'wallpapers${container.suffix}'),
          );
        }
      },
    );
    // a backup reading the folder or a restore replacing it keeps them:
    // nothing names them now, so the start sweep takes them after
    for (final f in backupRunning || restoreRunning ? const [] : adopted) {
      try {
        await shredFile(f);
      } catch (_) {
        // shredFile logs its own failure
      }
    }
    try {
      await dropOrphanWallpapers(_db!);
    } catch (e) {
      dlog('wallpaper: orphans not swept (${e.runtimeType})');
    }
    // retired while it was opening
    if (_retired) {
      await close();
      throw StateError('${container.dbFile} was replaced');
    }
    final db = _db!;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 30), () async {
        if (_retired || !identical(_db, db)) return;
        try {
          await searchForgetsOnce(db);
        } catch (e) {
          dlog('search: marks not merged (${e.runtimeType})');
        }
        try {
          await wipeFreedOnce(db);
        } catch (e) {
          dlog('freed pages: not wiped (${e.runtimeType})');
        }
        // a removal a death cut short of its tidy
        try {
          await tidyIfOwed(db);
        } catch (e) {
          dlog('tidy: not done (${e.runtimeType})');
        }
      }),
    );
    return db;
  }

  Future<Map<String, String>?> loadIdentity() async {
    final db = await open();
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'] as String,
      'ed_priv': rows.first['ed_priv'] as String,
      'x_priv': rows.first['x_priv'] as String,
    };
  }

  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {
    final db = await open();
    await db.delete('identity');
    await db.insert('identity', {
      'id': id,
      'ed_priv': edPriv,
      'x_priv': xPriv,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setNote(String haloId, String note) async {
    final db = await open();
    await db.update(
      'contacts',
      {'note': note},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactPinned(String haloId, bool pinned) async {
    final db = await open();
    await db.update(
      'contacts',
      {'pinned': pinned ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setPeerBundle(String haloId, String bundleB64) async {
    // the dev chat's bundle is the pinned one, and his is no one else's
    if (isDevId(haloId) || devKeyByBundle(bundleB64) != null) return;
    final db = await open();
    await db.update(
      'contacts',
      {'peer_bundle': bundleB64},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<Map<String, Object?>?> getContact(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isEmpty ? null : (await _verifiedNow(db, rows)).first;
  }

  Future<List<Map<String, Object?>>> _verifiedNow(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows, {
    String idColumn = 'halo_id',
  }) => verifiedNow(db, rows, idColumn: idColumn, identity: _keySource);

  // where a key held for someone is read when this database keeps no signal
  // tables of its own (keySourceFor)
  Future<String?> Function(String haloId)? get _keySource =>
      keySourceFor(container);

  // a contact stub from group invite info. a peer we already know is left
  // as is.
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('contacts', {
      'halo_id': haloId,
      'onion': onion,
      'xpub': xpub,
      'first_seen': now,
      'last_seen': now,
      'back_paired': 0,
      // being in a group with someone is not knowing them. the key is kept
      // so their messages decrypt; the row stays out of the contact list
      // until you add them yourself.
      'accepted': 0,
      // and the name is whatever the card said
      'name_check': kNameAsk | kNameSays,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> keyChanged(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['key_changed'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['key_changed'] as int? ?? 0) == 1;
  }

  // flag that a known peer's identity key changed (reinstall or mitm).
  // the chat surfaces this so the user verifies before trusting.
  Future<void> setKeyChanged(String haloId, bool changed) async {
    // the dev chat never warns: a key that is not the pinned one is dropped
    if (isDevId(haloId)) return;
    final db = await open();
    await _inLane(
      haloId,
      () => db.update(
        'contacts',
        {'key_changed': changed ? 1 : 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      ),
    );
  }

  Future<void> clearKeyChanged(String haloId) async {
    final db = await open();
    await _inLane(
      haloId,
      () => db.update(
        'contacts',
        {'key_changed': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      ),
    );
  }

  // in their signal lane: an open that fails puts back only what was there
  // before it, never a write made since
  static Future<T> _inLane<T>(String haloId, Future<T> Function() work) =>
      isDevId(haloId) ? work() : signalSession.serial(haloId, work);

  Future<String?> contactXPub(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['xpub'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['xpub'] as String?;
  }

  Future<void> setContactBadge(String haloId, String? tier) async {
    final d = await open();
    await d.update(
      'contacts',
      {'supporter_badge': tier},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // who vouched for whom. a row only ever lands when the voucher is a
  // contact we accepted, which is what makes the count mean anything.
  Future<void> addVouch(
    String haloId,
    String voucherId,
    String? note, {
    int? at,
  }) async {
    final db = await open();
    final v = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [voucherId],
      limit: 1,
    );
    if (v.isEmpty || (v.first['accepted'] as int? ?? 0) != 1) {
      dlog('vouch: $voucherId is not an accepted contact, dropped');
      return;
    }
    final n = (note ?? '').trim();
    await db.insert('vouches', {
      'halo_id': haloId,
      'voucher_id': voucherId,
      'note': n.isEmpty ? null : (n.length > 40 ? n.substring(0, 40) : n),
      'created_at': at ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // every vouch for one person, joined to what we know about the voucher.
  // only vouchers we still hold as accepted contacts count: a deleted or
  // blocked one drops out here rather than lingering as a name.
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async {
    final db = await open();
    return _verifiedNow(
      db,
      await db.rawQuery(
        '''
      SELECT v.voucher_id, v.note, v.created_at,
             c.nickname, c.avatar, c.verified, c.verified_key, c.xpub
      FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0
      ORDER BY v.created_at ASC
      ''',
        [haloId],
      ),
      idColumn: 'voucher_id',
    );
  }

  Future<bool> isVouched(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      '''
      SELECT 1 FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0 LIMIT 1
      ''',
      [haloId],
    );
    return r.isNotEmpty;
  }

  // introduced people we have not accepted yet. they need a relay
  // subscription like a real contact or their first message never lands.
  Future<List<Map<String, Object?>>> vouchedPending() async {
    final db = await open();
    return db.rawQuery('''
      SELECT DISTINCT c.* FROM contacts c
      JOIN vouches v ON v.halo_id = c.halo_id
      WHERE c.accepted = 0 AND c.blocked = 0
    ''');
  }

  // headline and lines are stored as shield codes (ShieldHit.toJson), and
  // worded when shown. a flag or a dismissal stays; only a clean check an
  // older build stored gives way
  Future<void> setShield(
    String haloId,
    String headline,
    List<Map<String, String>> lines,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      final had = await t.query(
        'shield',
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      if (had.isNotEmpty && !shieldRowOpen(had.first)) return;
      await t.insert('shield', {
        'halo_id': haloId,
        'headline': headline,
        'lines': jsonEncode(lines),
        'dismissed': 0,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, Object?>?> shieldFor(String haloId) async {
    final db = await open();
    final r = await db.query(
      'shield',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  // ignore = for good. the row stays so the check never re-runs on them.
  Future<void> dismissShield(String haloId) async {
    final db = await open();
    await db.update(
      'shield',
      {'dismissed': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<int?> powNonceOf(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['pow_nonce'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['pow_nonce'] as num?)?.toInt();
  }

  Future<void> setPowNonce(String msgUid, int nonce) async {
    final db = await open();
    await db.update(
      'messages',
      {'pow_nonce': nonce},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setContactAvatar(String haloId, int? av) async {
    final db = await open();
    await db.update(
      'contacts',
      {'avatar': av},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactXPub(String haloId, String xpub) async {
    // the dev chat's row keeps the key it was made with, and no one else
    // gets his
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    await db.update(
      'contacts',
      {'xpub': xpub},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return _verifiedNow(
      db,
      await db.query(
        'contacts',
        where: 'accepted = 1',
        orderBy: 'last_seen DESC',
      ),
    );
  }

  // every person held, true for a contact and false for a key only, and
  // every group: what a session reads to know whose a chat is
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async {
    final db = await open();
    final people = await db.query('contacts', columns: ['halo_id', 'accepted']);
    final groups = await db.query('groups', columns: ['group_id']);
    return (
      people: {
        for (final r in people)
          r['halo_id'] as String: (r['accepted'] as int? ?? 0) == 1,
      },
      groups: {for (final r in groups) r['group_id'] as String},
    );
  }

  // the developer chat's row: its flags, its start and its delete
  DevChat get devChat => DevChat(open, shred: shredFile);

  // the developer's own phone: the chats people start from the Marios row
  SupportChats get support => SupportChats(open);

  // a 1:1 chat with a message that came through the developer chat
  Future<bool> hasViaDev(String haloId) async {
    try {
      final d = await open();
      final r = await d.query(
        'messages',
        columns: ['id'],
        where: 'peer_id = ? AND group_id IS NULL AND via_dev = ?',
        whereArgs: [haloId, 1],
        limit: 1,
      );
      return r.isNotEmpty;
    } catch (e) {
      dlog('via dev: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> deleteConversation(String haloId) async {
    final d = await open();
    String? atmo;
    final files = await d.transaction((t) async {
      atmo = await _atmosphereOf(t, haloId);
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await _noteGone(t, rows);
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // the row stays: it carries the xpub our nostr subscription is built
      // from. archived + unaccepted = invisible everywhere until they write.
      // what was set for the chat goes with it, so they come back as a new
      // person. the block, the verified mark on its key and the vouches for
      // them stay
      await t.update(
        'contacts',
        {
          'accepted': 0,
          'archived': 1,
          'unread': 0,
          'nickname': null,
          'note': null,
          'atmosphere': null,
          'voice_disguise': null,
          'muted': 0,
          'pinned': 0,
          'ack_owed': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      // a first message after this is checked afresh, and rings under a
      // new tag the shade never ties to the old chat
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('notif_tags', where: 'chat = ?', whereArgs: [haloId]);
      await t.delete('notif_rings', where: 'chat = ?', whereArgs: [haloId]);
      // nothing queued for the old chat goes after it. a take-back still
      // goes, it only withdraws
      await _dropQueuedTo(t, haloId);
      if (rows.isNotEmpty) await oweTidy(t);
      return rows;
    });
    await _scrubMedia(files);
    await _dropPhotos([atmo]);
  }

  // a chat's atmosphere as its row has it
  static Future<String?> _atmosphereOf(
    DatabaseExecutor t,
    String haloId,
  ) async {
    final r = await t.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['atmosphere'] as String?;
  }

  // a request that never became one: its row, its shield line and what
  // of theirs waited to be tried again
  Future<void> forgetRequest(String haloId) async {
    final db = await open();
    final gone = await db.transaction((t) async {
      final gone = await t.query(
        'contacts',
        columns: ['atmosphere'],
        where: 'halo_id = ? AND accepted = ?',
        whereArgs: [haloId, 0],
      );
      await t.delete(
        'contacts',
        where: 'halo_id = ? AND accepted = ?',
        whereArgs: [haloId, 0],
      );
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('first_kept', where: 'peer = ?', whereArgs: [haloId]);
      await t.delete('notif_tags', where: 'chat = ?', whereArgs: [haloId]);
      return gone;
    });
    await _dropPhotos([for (final r in gone) r['atmosphere']]);
  }

  // they wrote after we deleted them: bring the row back as a request.
  Future<void> unparkIfArchived(String haloId) async {
    final d = await open();
    final r = await d.query(
      'contacts',
      columns: ['archived', 'accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (r.isEmpty) return;
    final arch = (r.first['archived'] as int?) ?? 0;
    final acc = (r.first['accepted'] as int?) ?? 0;
    if (arch == 1 && acc == 0) {
      await d.update(
        'contacts',
        {'archived': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> setArchived(String haloId, bool archived) async {
    final db = await open();
    await db.update(
      'contacts',
      {'archived': archived ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setMuted(String haloId, bool muted) async {
    final db = await open();
    await db.update(
      'contacts',
      {'muted': muted ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isMuted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['muted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['muted'] as int? ?? 0) == 1;
  }

  // in their signal lane: an open that saves a new key for them lands
  // wholly before the mark or after it
  Future<bool> setVerified(String haloId, bool verified, {String? key}) async {
    final db = await open();
    return _inLane(
      haloId,
      () => markVerified(db, haloId, verified, key: key, identity: _keySource),
    );
  }

  Future<bool> isVerified(String haloId) async {
    final c = await getContact(haloId);
    return (c?['verified'] as int? ?? 0) == 1;
  }

  // a name let go (AppState.releaseName): the key the row held and what
  // came with it go. what is left is a name nobody checked
  Future<void> forgetName(String haloId) async {
    final db = await open();
    final atmo = await db.transaction((t) async {
      final atmo = await _atmosphereOf(t, haloId);
      await t.update(
        'contacts',
        {
          'xpub': '',
          'peer_bundle': null,
          'key_changed': 0,
          'verified': 0,
          'verified_key': null,
          'back_paired': 0,
          'avatar': null,
          'supporter_badge': null,
          'vouched_by': null,
          'vouched_at': null,
          'nickname': null,
          'note': null,
          'atmosphere': null,
          'pinned': 0,
          'muted': 0,
          'voice_disguise': null,
          'name_check': kNameAsk | kNameSays,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      // vouches for them, and the ones they gave
      await t.delete('vouches', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('vouches', where: 'voucher_id = ?', whereArgs: [haloId]);
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      return atmo;
    });
    await _dropPhotos([atmo]);
  }

  // "this isn't them": everything of [haloId] here goes in one go, what
  // they wrote in groups and their seats there too, and [keyHex], the key
  // the number was made from, is blocked. by the key alone: the same words
  // on another key are someone else, though none who writes first is given
  // them (name_tombs). a group they ran has no admin after. the files go
  // once it is done. the uids of what of theirs went, for the shade
  Future<List<String>> removeAndBlockKey(String haloId, String keyHex) async {
    final db = await open();
    final (rows, wallpaper) = await db.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, 'msg_uid', 'poll'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      final uids = [
        for (final r in rows)
          if (r['msg_uid'] case final String u) u,
      ];
      final polls = [
        for (final r in rows)
          if (r['poll'] != null)
            if (r['msg_uid'] case final String u) u,
      ];
      final c = await t.query(
        'contacts',
        columns: ['atmosphere'],
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      final atmo = c.isEmpty ? null : c.first['atmosphere'] as String?;
      // what they left unread in a group goes from its count
      await _unreadGo(t, [
        for (final r in rows)
          if (r['group_id'] != null) r,
      ]);
      for (var i = 0; i < uids.length; i += 400) {
        final part = uids.sublist(i, min(i + 400, uids.length));
        final marks = List.filled(part.length, '?').join(', ');
        for (final (table, col) in const [
          ('reactions', 'msg_uid'),
          ('poll_votes', 'poll_uid'),
          ('pins_out', 'msg_uid'),
          ('edits_out', 'msg_uid'),
          ('opener_again', 'msg_uid'),
          ('frame_order', 'msg_uid'),
          ('notif_rings', 'msg_uid'),
          ('group_media_owed', 'msg_uid'),
        ]) {
          await t.delete(table, where: '$col IN ($marks)', whereArgs: part);
        }
      }
      await _dropFilesComingFrom(t, haloId);
      for (final (table, col) in const [
        ('reactions', 'reactor'),
        ('poll_votes', 'voter'),
        ('media_chunks', 'sender'),
        ('frame_order', 'sender'),
        ('frames_out', 'peer_id'),
        ('pins_out', 'peer_id'),
        ('edits_out', 'peer_id'),
        ('held_onion', 'peer_id'),
        ('first_kept', 'peer'),
        ('gone_in', 'peer_id'),
        ('notif_tags', 'chat'),
        ('notif_rings', 'chat'),
        ('shield', 'halo_id'),
        ('vouches', 'halo_id'),
        ('vouches', 'voucher_id'),
        ('block_spans', 'peer_id'),
        ('blocked_drops', 'peer_id'),
        ('group_members', 'halo_id'),
        ('group_media_owed', 'member'),
        ('group_ctl_out', 'member'),
        ('group_resent', 'member'),
        ('support_chats', 'halo_id'),
        ('sessions', 'address'),
        ('peer_identities', 'address'),
        ('messages', 'peer_id'),
        ('contacts', 'halo_id'),
      ]) {
        await t.delete(table, where: '$col = ?', whereArgs: [haloId]);
      }
      // what of theirs went in groups, by group and sender (goneKey). the
      // delete marked their polls as just gone: nothing of them stays
      final inGroups = [
        for (final r in await t.query(
          'gone_in',
          columns: ['peer_id'],
          where: 'peer_id LIKE ?',
          whereArgs: ['group:%'],
        ))
          if (r['peer_id'] case final String k)
            if (k.substring(6).split(':').skip(1).join(':') == haloId) k,
      ];
      for (final (table, col, keys) in [
        ('gone_in', 'peer_id', inGroups),
        ('polls_gone', 'uid', polls),
      ]) {
        for (var i = 0; i < keys.length; i += 400) {
          final part = keys.sublist(i, min(i + 400, keys.length));
          await t.delete(
            table,
            where: '$col IN (${List.filled(part.length, '?').join(', ')})',
            whereArgs: part,
          );
        }
      }
      await t.update(
        'groups',
        {'admin_id': kAdminGone},
        where: 'admin_id = ?',
        whereArgs: [haloId],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await t.insert('blocked_keys', {
        'x': keyHex.trim().toLowerCase(),
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await t.insert('name_tombs', {
        'name': haloId,
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await oweTidy(t);
      return (rows, atmo);
    });
    await _scrubMedia(rows);
    // their chat's own photo, named for them in this container's folder
    if (wallpaper != null && wallpaper.startsWith('image:')) {
      final f = File(wallpaper.substring(6));
      final folder = await container.folder('wallpapers');
      if (p.isWithin(folder.path, f.path) && await f.exists()) {
        await shredFile(f.path);
      }
    }
    return [
      for (final r in rows)
        if (r['msg_uid'] case final String u) u,
    ];
  }

  // words "this isn't them" let go here: nobody who writes first gets them
  Future<bool> tombed(String name) async {
    final db = await open();
    final r = await db.query(
      'name_tombs',
      columns: ['name'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<List<({String name, int at})>> tombs() async {
    final db = await open();
    return [
      for (final r in await db.query('name_tombs'))
        (name: r['name'] as String, at: (r['at'] as num).toInt()),
    ];
  }

  // what another container blocked and let go, kept here as it goes
  Future<void> takeBlocks(
    List<({String x, int at})> keys,
    List<({String name, int at})> tombs,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      for (final k in keys) {
        await t.insert('blocked_keys', {
          'x': k.x,
          'at': k.at,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final n in tombs) {
        await t.insert('name_tombs', {
          'name': n.name,
          'at': n.at,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // an add the person made takes the words again
  Future<void> clearTomb(String name) async {
    final db = await open();
    await db.delete('name_tombs', where: 'name = ?', whereArgs: [name]);
  }

  // someone let go in the other container: no seat in a group here, no
  // row that only held their key, and no admin in a group they ran. only
  // where the row here has [keyHex], or no key at all: the same words on
  // another key are someone else
  Future<void> dropSeats(String haloId, String keyHex) async {
    final db = await open();
    await db.transaction((t) async {
      final row = await t.query(
        'contacts',
        columns: ['xpub'],
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      final x = row.isEmpty
          ? ''
          : ((row.first['xpub'] as String?) ?? '').trim().toLowerCase();
      if (x.isNotEmpty && x != keyHex.trim().toLowerCase()) return;
      for (final (table, col) in const [
        ('group_members', 'halo_id'),
        ('group_media_owed', 'member'),
        ('group_ctl_out', 'member'),
        ('group_resent', 'member'),
      ]) {
        await t.delete(table, where: '$col = ?', whereArgs: [haloId]);
      }
      await t.update(
        'groups',
        {'admin_id': kAdminGone},
        where: 'admin_id = ?',
        whereArgs: [haloId],
      );
      final own = await t.query(
        'messages',
        columns: ['id'],
        where: _kOneToOne,
        whereArgs: [haloId],
        limit: 1,
      );
      if (own.isEmpty) {
        await t.delete(
          'contacts',
          where: 'halo_id = ? AND accepted = ?',
          whereArgs: [haloId, 0],
        );
      }
    });
  }

  // a key blocked here by "this isn't them"
  Future<bool> keyBlocked(String keyHex) async {
    final db = await open();
    final r = await db.query(
      'blocked_keys',
      columns: ['x'],
      where: 'x = ?',
      whereArgs: [keyHex.trim().toLowerCase()],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  // the keys blocked here, the newest first
  Future<List<({String x, int at})>> blockedKeys() async {
    final db = await open();
    return [
      for (final r in await db.query('blocked_keys', orderBy: 'at DESC'))
        (x: r['x'] as String, at: (r['at'] as num).toInt()),
    ];
  }

  Future<void> unblockKey(String keyHex) async {
    final db = await open();
    await db.delete(
      'blocked_keys',
      where: 'x = ?',
      whereArgs: [keyHex.trim().toLowerCase()],
    );
  }

  // a member of a group or a room here
  Future<bool> inAnyGroup(String haloId) async {
    final db = await open();
    for (final (t, c, w) in const [
      // an ended group's members are kept for its end alone
      ('group_members', 'halo_id', _kRunningGroup),
      ('room_keys', 'member', ''),
    ]) {
      final r = await db.query(
        t,
        columns: [c],
        where: '$c = ?$w',
        whereArgs: [haloId],
        limit: 1,
      );
      if (r.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> setNameCheck(String haloId, int flags) async {
    final db = await open();
    await db.update(
      'contacts',
      {'name_check': flags},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // no key when it could not be read: no number shows
  Future<String?> heldKey(String haloId) async {
    final k = await heldKeyHex(await open(), haloId, identity: _keySource);
    return k == kKeyUnread ? null : k;
  }

  Future<bool> keyHeld(String haloId) async =>
      keyHeldIn(await open(), haloId, identity: _keySource);

  Future<void> acceptNewKey(String haloId) async {
    final db = await open();
    await _inLane(haloId, () => acceptNewKeyIn(db, haloId));
  }

  // a block starts the clocks of what they sent that waits to be read, in
  // their chat and in groups, and drops what was queued for them. an
  // unblock leaves them counting. what of ours waits for them is not sent,
  // either way: an unblock sends nothing without a tap
  Future<void> setBlocked(String haloId, bool blocked) async {
    final db = await open();
    await db.transaction((t) async {
      await t.update(
        'contacts',
        {
          'blocked': blocked ? 1 : 0,
          // an unblock is no accept: what an accept owed them goes with it
          if (blocked) 'ack_owed': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      if (blocked) {
        await _lightFrom(t, haloId);
        await _dropQueuedTo(t, haloId);
      }
      await _holdBackTo(t, haloId);
      await _markSpan(t, haloId, blocked);
    });
  }

  // a block opens a span and an unblock closes it
  static Future<void> _markSpan(
    DatabaseExecutor t,
    String haloId,
    bool blocked,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final open = await t.query(
        'block_spans',
        columns: ['rowid AS rowid'],
        where: 'peer_id = ? AND to_at IS NULL',
        whereArgs: [haloId],
        limit: 1,
      );
      if (blocked && open.isEmpty) {
        await t.insert('block_spans', {'peer_id': haloId, 'from_at': now});
      } else if (!blocked && open.isNotEmpty) {
        await t.update(
          'block_spans',
          {'to_at': now},
          where: 'peer_id = ? AND to_at IS NULL',
          whereArgs: [haloId],
        );
      }
    } catch (e) {
      dlog('block span: $e');
    }
  }

  // every span of a block on [haloId], from and to, to null while it holds
  Future<List<(int, int?)>> blockSpansOf(String haloId) async {
    try {
      final db = await open();
      final r = await db.query(
        'block_spans',
        columns: ['from_at', 'to_at'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      return [for (final x in r) (x['from_at'] as int, x['to_at'] as int?)];
    } catch (e) {
      dlog('block span: $e');
      return const [];
    }
  }

  // when the block on [haloId] that holds now began, or null without one
  Future<int?> blockedSince(String haloId) async {
    try {
      final db = await open();
      final r = await db.query(
        'block_spans',
        columns: ['from_at'],
        where: 'peer_id = ? AND to_at IS NULL',
        whereArgs: [haloId],
        limit: 1,
      );
      return r.isEmpty ? null : r.first['from_at'] as int?;
    } catch (e) {
      dlog('block span: $e');
      return null;
    }
  }

  // what came from someone while they were blocked, by uid. one that comes
  // again keeps its row a while longer, so a sender that retries for weeks
  // is still turned away
  int _dropsSweptAt = 0;
  Future<void> noteBlockedDrop(String haloId, String uid) async {
    try {
      final db = await open();
      _dropsSweptAt = await noteBlockedDropIn(
        db,
        haloId,
        uid,
        now: DateTime.now().millisecondsSinceEpoch,
        sweptAt: _dropsSweptAt,
      );
    } catch (e) {
      dlog('blocked drop: $e');
    }
  }

  Future<bool> droppedWhileBlocked(String haloId, String uid) async {
    try {
      final db = await open();
      if (!await droppedIn(db, haloId, uid)) return false;
      await noteBlockedDrop(haloId, uid);
      return true;
    } catch (e) {
      dlog('blocked drop: $e');
      return false;
    }
  }

  // [haloId] blocked elsewhere: their rows here that wait start counting
  Future<void> lightBurnsFrom(String haloId) async {
    final db = await open();
    await db.transaction((t) => _lightFrom(t, haloId));
  }

  static Future<void> _lightFrom(DatabaseExecutor t, String haloId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await t.query(
      'messages',
      columns: ['id', 'sent_at', 'burn_secs'],
      where: 'peer_id = ? AND $_kBurnIdle',
      whereArgs: [haloId],
    );
    for (final r in rows) {
      final sent = (r['sent_at'] as num?)?.toInt() ?? now;
      await _lightUnread(t, r, min(now, burnStartBy(sent, now)));
    }
  }

  // a timed row that came in and was never read: its clock waits
  static const _kBurnIdle =
      "direction = 'in' AND burn_secs IS NOT NULL AND burn_at IS NULL";

  // a waiting row's clock started at [from] with nobody reading it: it
  // counts down, and stays out of lists until read (burnWaitsRow)
  static Future<void> _lightUnread(
    DatabaseExecutor t,
    Map<String, Object?> r,
    int from,
  ) => t.update(
    'messages',
    {
      'burn_at': from + (r['burn_secs'] as num).toInt() * 1000,
      'burn_unseen': 1,
    },
    where: 'id = ? AND burn_at IS NULL',
    whereArgs: [r['id']],
  );

  // every blocked id, accepted or not. contacts() is accepted-only, so a
  // caller built on it never sees someone blocked while still a stranger.
  Future<Set<String>> blockedIds() async => _blockedIn(await open());

  // their rows, each with listen = 1 while its block is young enough to
  // be listened on (kBlockListenFor). without the spans none is
  Future<List<Map<String, Object?>>> blockedRows({required int now}) async {
    final db = await open();
    try {
      return await db.rawQuery(kBlockedRowsSql, [now - kBlockListenFor]);
    } catch (e) {
      dlog('blocked rows: $e');
      return db.rawQuery(
        'SELECT *, 0 AS listen FROM contacts WHERE blocked = 1',
      );
    }
  }

  // blocked, or never taken in: no one a restore asks to start afresh
  Future<Set<String>> unaskedIds() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'accepted = 0',
    );
    return {
      ...await _blockedIn(db),
      for (final r in rows) r['halo_id'] as String,
    };
  }

  static Future<Set<String>> _blockedIn(DatabaseExecutor db) async {
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'blocked = 1',
    );
    return {for (final r in rows) r['halo_id'] as String};
  }

  Future<bool> isBlocked(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['blocked'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['blocked'] as int? ?? 0) == 1;
  }

  // true only when we've accepted this sender. unknown senders read false.
  Future<bool> isAccepted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['accepted'] as int? ?? 0) == 1;
  }

  // how many messages we already hold from a sender in their own chat:
  // caps strangers. [inGroups] counts what they wrote in groups as well
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async {
    final db = await open();
    final r = await db.rawQuery(
      inGroups
          ? 'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?'
          : 'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
      [peerId, 'in'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // how many messages we've sent a peer: caps our own request messages
  Future<int> countMessagesTo(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
      [peerId, 'out'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> setNickname(String haloId, String? name) async {
    final db = await open();
    final v = (name == null || name.trim().isEmpty) ? null : name.trim();
    await db.update(
      'contacts',
      {'nickname': v},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // unknown senders waiting for accept/block. blocked ones stay hidden.
  // the receive side tries and listens for all of these, a group member
  // known only by key included
  Future<List<Map<String, Object?>>> pendingRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0',
      orderBy: 'last_seen DESC',
    );
  }

  // of those, the ones who asked: what the requests inbox shows
  Future<List<Map<String, Object?>>> askedRequests() async {
    final db = await open();
    return db.query('contacts', where: kRequestRows, orderBy: 'last_seen DESC');
  }

  // declined and parked: out of the inbox, but a second message still has
  // to reach us so the row can resurface
  Future<List<Map<String, Object?>>> parkedRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1',
    );
  }

  // the requests inbox: support chats wait in their own, though the
  // receive side still tries them as requests
  Future<List<Map<String, Object?>>> requestsInbox() async {
    final rows = await askedRequests();
    if (rows.isEmpty) return rows;
    return withoutSupport(rows, await support.ids());
  }

  Future<int> pendingRequestCount() async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE $kRequestRows',
    );
    final n = (r.first['c'] as int?) ?? 0;
    if (n == 0 || (await support.ids()).isEmpty) return n;
    return (await requestsInbox()).length;
  }

  // someone who asked, or asked and was let go: adding them by their card
  // is the accept they were waiting for
  Future<bool> askedBefore(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE halo_id = ? AND ($kAskedRows)',
      [haloId],
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  // the accept and the word it owes them in one write: a death before the
  // word goes leaves it owed
  Future<void> acceptRequest(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'accepted': 1, 'ack_owed': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // quietly dismiss a request: drop the stranger's row and pending messages.
  // not a block: they can reach us again later.
  Future<void> declineRequest(String haloId) async {
    final d = await open();
    String? atmo;
    final files = await d.transaction((t) async {
      atmo = await _atmosphereOf(t, haloId);
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      // turned away, they stay away: a resend or the relays bring none
      // back, the ones the cap held either
      final held = await t.query(
        'held_onion',
        columns: ['cipher', 'at'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      await _noteGone(t, [
        ...rows,
        for (final h in held)
          if (heldWireOf(h['cipher'] as String) case final w?)
            if (unwrapMessage(w).msgUid case final uid?)
              {
                'msg_uid': uid,
                'peer_id': haloId,
                'direction': 'in',
                'sent_at': h['at'],
              },
      ]);
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await t.delete('held_onion', where: 'peer_id = ?', whereArgs: [haloId]);
      await t.delete('first_kept', where: 'peer = ?', whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // park, don't delete: the row carries the xpub the relay subscription
      // is built from. if they write again, unparkIfArchived surfaces them as
      // a new request. a wallpaper set for the request goes with it
      await t.update(
        'contacts',
        {
          'accepted': 0,
          'archived': 1,
          'unread': 0,
          'ack_owed': 0,
          'atmosphere': null,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      return rows;
    });
    await _scrubMedia(files);
    await _dropPhotos([atmo]);
  }

  // [owe]: an add that takes in someone who asked, which owes them word
  // that they are in, kept in the same write
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
    bool owe = false,
  }) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('contacts', {
        'halo_id': haloId,
        'onion': onion,
        'xpub': xpub,
        'first_seen': now,
        'last_seen': now,
        'accepted': accepted,
        // someone who wrote first gave their name themselves
        if (accepted == 0) 'name_check': kNameAsk | kNameSays,
        if (owe && accepted == 1) 'ack_owed': 1,
      });
    } else {
      // xpub changed on someone we already know = they reinstalled, or its a
      // mitm. dont just swap the key silently, flag it so the chat warns
      final priorX = existing.first['xpub'] as String?;
      final changed =
          priorX != null &&
          priorX.isNotEmpty &&
          xpub.isNotEmpty &&
          priorX != xpub;
      // someone blocked stays as the block left them. a new key is still
      // flagged, so their chat warns once the block ends
      if ((existing.first['blocked'] as int? ?? 0) == 1) {
        if (changed) {
          await db.update(
            'contacts',
            {'key_changed': 1, 'verified': 0},
            where: 'halo_id = ?',
            whereArgs: [haloId],
          );
        }
        return;
      }
      // only ever raise accepted (0->1 on an explicit re-pair), never lower
      // it: a back-pair passing accepted:0 must not demote a real contact.
      final priorAccepted = (existing.first['accepted'] as int?) ?? 0;
      final nextAccepted = accepted == 1 ? 1 : priorAccepted;
      // parked = deleted (archived and unaccepted). a real archived chat is
      // still accepted, so this can't un-archive one the user archived on
      // purpose. any touch on a parked row brings it back as a request.
      final wasParked =
          ((existing.first['archived'] as int?) ?? 0) == 1 &&
          priorAccepted == 0;
      await db.update(
        'contacts',
        {
          'onion': onion,
          // v2 links pass '' here: never wipe a key we already learned
          if (xpub.isNotEmpty) 'xpub': xpub,
          'last_seen': now,
          'accepted': nextAccepted,
          if (owe && nextAccepted == 1) 'ack_owed': 1,
          if (wasParked) 'archived': 0,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    // when it came, if not now: an arrival opened from the seal
    int? sentAt,
    // when it was written, held to what can be true (writtenAtOf). when it
    // came if not given: ours are written as they go
    int? writtenAt,
    // a contact's, through the developer chat (viaDevChat)
    bool viaDev = false,
    // its place in an album
    AlbumTag? album,
  }) async {
    final db = await open();
    final came = sentAt ?? DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      // your own words too (a pasted caption, a forward): no direction
      // controls reach the screen from here (bidi_safe.dart)
      'plaintext': unmarked(plaintext),
      'sent_at': came,
      'written_at': writtenAt ?? came,
      'burn_at': burnAt,
      'burn_secs': burnSecs,
      // came in with its window and its clock already running: nobody read
      // it, it waited too long (kBurnWaitMost)
      if (direction == 'in' && burnSecs != null && burnAt != null)
        'burn_unseen': 1,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'group_id': groupId,
      'media_path': mediaPath,
      'file_path': filePath,
      'file_name': fileName == null ? null : unmarked(fileName),
      'voice_disguised': voiceDisguised ? 1 : 0,
      'preview': preview,
      'saved': saved ? 1 : 0,
      'sent': sent,
      'secure': secure ? 1 : 0,
      'poll': ?poll,
      'sticker': ?sticker,
      if (viaDev) 'via_dev': 1,
      ...?album?.toRow(),
    });
    try {
      await indexSearchRow(db, id, {
        'plaintext': plaintext,
        'poll': poll,
        'file_name': fileName,
        'preview': preview,
        'sticker': sticker,
      });
    } catch (e) {
      // a message is never lost to its index; the fill catches it up
      dlog('search: not indexed now: $e');
    }
    // any inbound message proves the peer knows us, so flip back_paired.
    // subsequent sends to them can use nostr safely.
    if (direction == 'in') {
      await db.update(
        'contacts',
        {'back_paired': 1},
        where: 'halo_id = ?',
        whereArgs: [peerId],
      );
    }
    // a word from them, or one to them that carries the accept with it:
    // the line saying they may not know goes
    if (groupId == null || groupId.isEmpty) {
      await db.update(
        'contacts',
        {'ack_owed': 0},
        where: 'halo_id = ? AND ack_owed = 2',
        whereArgs: [peerId],
      );
    }
  }

  /// a file of this phone's own in the chat with [peerId], kept in the
  /// same go as a look that the chat is still here: one deleted, or hidden
  /// away while it was made, keeps nothing. [wasAccepted] is what the chat
  /// was when the send began. false then
  Future<bool> saveInChat(
    String peerId, {
    required String msgUid,
    required bool wasAccepted,
    required int writtenAt,
    String? replyTo,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    int? burnAt,
    int? burnSecs,
    int sent = 0,
  }) async {
    final db = await open();
    final id = await db.transaction((t) async {
      final c = await t.query(
        'contacts',
        columns: ['accepted', 'archived'],
        where: 'halo_id = ?',
        whereArgs: [peerId],
        limit: 1,
      );
      if (c.isEmpty) return null;
      final accepted = c.first['accepted'] == 1;
      // a deleted chat is parked: unaccepted and archived. a hidden one
      // leaves at most a key here, unaccepted
      if (!accepted && (wasAccepted || c.first['archived'] == 1)) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      return t.insert('messages', {
        'peer_id': peerId,
        'direction': 'out',
        'plaintext': '',
        'sent_at': now,
        'written_at': writtenAt,
        'burn_at': burnAt,
        'burn_secs': burnSecs,
        'msg_uid': msgUid,
        'reply_to': replyTo,
        'file_path': filePath,
        'file_name': fileName == null ? null : unmarked(fileName),
        'voice_disguised': voiceDisguised ? 1 : 0,
        'saved': 0,
        'sent': sent,
        'secure': 0,
      });
    });
    if (id == null) return false;
    try {
      await indexSearchRow(db, id, {'plaintext': '', 'file_name': fileName});
    } catch (e) {
      dlog('search: not indexed now: $e');
    }
    return true;
  }

  /// a row of this phone's own in group [groupId], kept in the same go as
  /// a look that the group is still here: one that ended, was left or was
  /// taken out of keeps nothing. false then
  Future<bool> saveInGroup(
    String peerId,
    String plaintext, {
    required String groupId,
    required String msgUid,
    int? burnSecs,
    String? replyTo,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    int sent = 0,
    String? preview,
    String? poll,
    String? sticker,
    AlbumTag? album,
    // when it was begun, if not now: a bubble shown before it was saved
    int? writtenAt,
  }) async {
    final db = await open();
    final id = await db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ? AND ended_at IS NULL',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      return t.insert('messages', {
        'peer_id': peerId,
        'direction': 'out',
        'plaintext': unmarked(plaintext),
        'sent_at': now,
        'written_at': writtenAt ?? now,
        'burn_secs': burnSecs,
        'msg_uid': msgUid,
        'reply_to': replyTo,
        'group_id': groupId,
        'media_path': mediaPath,
        'file_path': filePath,
        'file_name': fileName == null ? null : unmarked(fileName),
        'voice_disguised': voiceDisguised ? 1 : 0,
        'preview': preview,
        'saved': 0,
        'sent': sent,
        'secure': 0,
        'poll': ?poll,
        'sticker': ?sticker,
        ...?album?.toRow(),
      });
    });
    if (id == null) return false;
    try {
      await indexSearchRow(db, id, {
        'plaintext': plaintext,
        'poll': poll,
        'file_name': fileName,
        'preview': preview,
        'sticker': sticker,
      });
    } catch (e) {
      dlog('search: not indexed now: $e');
    }
    return true;
  }

  // the same message can come via tor and nostr, plus retries. a duplicate
  // crashes on the used-up prekey, so it is dropped before any decrypt.
  Future<bool> alreadySeen(String hash) async {
    final db = await open();
    final rows = await db.query(
      'seen_msgs',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSeen(String hash) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // prune anything older than a day so the table stays tiny
    await db.delete('seen_msgs', where: 'ts < ?', whereArgs: [now - 86400000]);
  }

  // like markSeen but stamped a month ahead of the daily prune: a pruned
  // hash of an undecryptable cipher replays the bad mac the next day. relays
  // age the events out well before the month is up.
  Future<void> markSeenLong(String hash) async {
    final db = await open();
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': DateTime.now().millisecondsSinceEpoch + 30 * 86400000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // a msg_uid for a row from before the v5 migration, so it can take
  // reactions. (peer_id, sent_at) is unique enough in practice.
  Future<void> assignUidIfMissing(
    String peerId,
    int sentAtMs,
    String uid,
  ) async {
    final db = await open();
    await db.update(
      'messages',
      {'msg_uid': uid},
      where: 'peer_id = ? AND sent_at = ? AND msg_uid IS NULL',
      whereArgs: [peerId, sentAtMs],
    );
  }

  Future<void> markBackPaired(String peerId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'back_paired': 1},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<bool> isBackPaired(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['back_paired'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['back_paired'] as int? ?? 0) == 1;
  }

  // an accept's word to them, kept on their row until a send of it is
  // taken: a dead route or a restart must not leave them locked out
  // set only on someone accepted and not blocked: a block that lands
  // between an accept and this write keeps its row clear
  Future<void> setAckOwed(String haloId, bool owed) async {
    final d = await open();
    await d.update(
      'contacts',
      {'ack_owed': owed ? 1 : 0},
      where: owed
          ? 'halo_id = ? AND accepted = 1 AND blocked = 0'
          : 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isAckOwed(String haloId) async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['ack_owed'],
      where: 'halo_id = ? AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isNotEmpty && (rows.first['ack_owed'] as int? ?? 0) == 1;
  }

  // the ack went untried for good: 2 on the row, and a line in their chat
  // says they may not know until a word goes either way or it is tried
  // again
  Future<void> loseAck(String haloId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'ack_owed': 2},
      where: 'halo_id = ? AND ack_owed = 1',
      whereArgs: [haloId],
    );
  }

  Future<bool> ackLost(String haloId) async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ? AND ack_owed = 2 AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // owed again, from the line's button. true when it was lost here
  Future<bool> retryAck(String haloId) async {
    final d = await open();
    final n = await d.update(
      'contacts',
      {'ack_owed': 1},
      where: 'halo_id = ? AND ack_owed = 2 AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
    );
    return n > 0;
  }

  // everyone here still owed it, and not blocked since
  Future<List<String>> ackOwed() async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['halo_id'],
      where: 'ack_owed = 1 AND accepted = 1 AND blocked = 0',
    );
    return [for (final r in rows) r['halo_id'] as String];
  }

  // ---- groups ----

  // when this phone first had group [groupId]: its first members' row. a
  // roster sent again keeps it
  Future<int?> groupJoinedAt(String groupId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MIN(joined_at) AS t FROM group_members WHERE group_id = ?',
      [groupId],
    );
    return (r.first['t'] as num?)?.toInt();
  }

  // members is the full set, including the creator. isAdmin is true for
  // groups we created.
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
    String? adminId,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': isAdmin ? 1 : 0,
      'admin_id': adminId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> groupExists(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['group_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> loadGroups() async {
    final db = await open();
    return db.query('groups', orderBy: 'created_at DESC');
  }

  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // the group creator/admin kryfo id. used to verify a roster self-heal
  // really came from the admin, not a member spoofing membership changes.
  Future<String?> groupAdminId(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['admin_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['admin_id'] as String?;
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_members',
      columns: ['halo_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'joined_at ASC',
    );
    return rows.map((r) => r['halo_id'] as String).toList();
  }

  Future<void> addGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.insert('group_members', {
      'group_id': groupId,
      'halo_id': haloId,
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // the authoritative list from a create or reconcile control replaces the
  // whole member set. one still in it keeps when they joined: what went
  // before it never went to them
  Future<void> syncGroupMembers(String groupId, List<String> members) async {
    await keepGroupOwedTo(groupId, members);
    final db = await open();
    final batch = db.batch();
    batch.delete(
      'group_members',
      where: members.isEmpty
          ? 'group_id = ?'
          : 'group_id = ? AND halo_id NOT IN '
                '(${List.filled(members.length, '?').join(', ')})',
      whereArgs: [groupId, ...members],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final h in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': h,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ? AND halo_id = ?',
      whereArgs: [groupId, haloId],
    );
    await db.transaction((t) async {
      await _owedGone(t, 'group_id = ? AND member = ?', [groupId, haloId]);
      // our edits and reactions are no longer theirs to get. take-backs
      // and controls stay: they may hold the message yet
      for (final r in await t.query(
        'group_ctl_out',
        columns: ['id', 'ctl'],
        where: 'group_id = ? AND member = ?',
        whereArgs: [groupId, haloId],
      )) {
        if (groupFrameOf(r['ctl']) == null &&
            groupWrappedOf(r['ctl']) == null) {
          continue;
        }
        await t.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
      }
    });
  }

  Future<void> renameGroup(String groupId, String name) async {
    final db = await open();
    await db.update(
      'groups',
      {'name': name},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  /// ends [groupId] here, once: what it held goes as a leave takes it,
  /// and the row stays as the line that says so. its members stay with it,
  /// for an end told again to one still writing
  Future<bool> endGroup(
    String groupId, {
    required String by,
    required int at,
  }) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'ended_at': at, 'ended_by': by, 'unread': 0, 'mentioned': 0},
      where: 'group_id = ? AND ended_at IS NULL AND room_pub IS NULL',
      whereArgs: [groupId],
    );
    if (n == 0) return false;
    await wipeEnded(groupId);
    return true;
  }

  /// an ended group's content, as deleteGroup takes it, all but the row,
  /// its members, and what of ours still goes: take-backs, the end itself
  /// and its words for older versions
  Future<void> wipeEnded(String groupId) async {
    dropDraft(container.chatKey(groupId), group: true);
    await clearGroupConversation(groupId, noteGone: false);
    final db = await open();
    // its wallpaper too: the line stays on a plain page, with no count. a
    // row with none of it is left as it is
    final atmo = (await getGroup(groupId))?['atmosphere'];
    await db.update(
      'groups',
      {'atmosphere': null, 'unread': 0, 'mentioned': 0},
      where:
          'group_id = ? AND (atmosphere IS NOT NULL OR unread != 0 '
          'OR mentioned != 0)',
      whereArgs: [groupId],
    );
    if (atmo != null) await _dropPhotos([atmo]);
    for (final table in const ['group_media_owed', 'group_resent']) {
      await db.delete(table, where: 'group_id = ?', whereArgs: [groupId]);
    }
    final gone = goneGroupPrefix(groupId);
    for (final k in {
      for (final r in await db.query('gone_in', columns: ['peer_id']))
        if (r['peer_id'] case final String k when k.startsWith(gone)) k,
    }) {
      await db.delete('gone_in', where: 'peer_id = ?', whereArgs: [k]);
    }
    for (final r in await db.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    )) {
      // a remove still owed: the one taken out drops the group by it
      if (groupUnsendOf(r['ctl']) != null ||
          groupEndOut(r['ctl']) ||
          groupRemoveOut(r['ctl'])) {
        continue;
      }
      await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
    await db.delete(
      'notif_tags',
      where: 'chat = ?',
      whereArgs: ['group:$groupId'],
    );
  }

  /// the groups here their admin ended that still hold something a wipe
  /// takes: one cut short. a wiped one costs a look at a few indexes
  Future<List<String>> endedGroupIds() async {
    final db = await open();
    return [
      for (final r in await db.rawQuery(
        'SELECT g.group_id FROM groups g WHERE g.ended_at IS NOT NULL AND ('
        'g.atmosphere IS NOT NULL OR g.unread != 0 OR g.mentioned != 0 '
        'OR EXISTS (SELECT 1 FROM messages m WHERE m.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM media_chunks c '
        'WHERE c.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM group_media_owed o '
        'WHERE o.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM group_resent r '
        'WHERE r.group_id = g.group_id) '
        "OR EXISTS (SELECT 1 FROM notif_tags n WHERE n.chat = 'group:' || "
        'g.group_id))',
      ))
        r['group_id'] as String,
    ];
  }

  /// the wipes of ended groups a stop cut short, finished, each one's
  /// notifications handed to [unshade] by the tag read before it went. one
  /// that fails leaves the rest to go on; how many were finished
  Future<int> finishEndedWipes({
    Future<void> Function(String chat, Set<String> tags)? unshade,
  }) async {
    var n = 0;
    for (final g in await endedGroupIds()) {
      try {
        final chat = 'group:$g';
        final tags = {?await notifTagOf(chat)};
        await wipeEnded(g);
        n++;
        await unshade?.call(chat, tags);
      } catch (e) {
        dlog('groups: an ended one not swept (${e.runtimeType})');
      }
    }
    return n;
  }

  /// the end and its words for older versions, in each member's lane at
  /// once: a stop between the two can lose neither
  Future<void> queueGroupEnd(
    String groupId,
    Iterable<String> members,
    String notice, {
    required int now,
  }) async {
    final end = jsonEncode(const GroupControl(type: 'end').toWire());
    final words = jsonEncode(groupWrappedRow(notice));
    final db = await open();
    await db.transaction((t) async {
      for (final ctl in [end, words]) {
        for (final m in members) {
          await t.insert('group_ctl_out', {
            'group_id': groupId,
            'member': m,
            'ctl': ctl,
            'since': now,
            'tries': 0,
            'next_at': now,
          });
        }
      }
    });
  }

  Future<void> deleteGroup(String groupId) async {
    dropDraft(container.chatKey(groupId), group: true);
    final db = await open();
    final room = (await getGroup(groupId))?['room_pub'] != null;
    // what its members were still sending goes with it
    await _dropGroupFiles(
      db,
      groupId,
      keys: room
          ? {...await getGroupMembers(groupId), ...await roomKeysOf(groupId)}
          : const <String>[],
    );
    for (final table in const [
      'group_media_owed',
      'group_roster',
      'room_keys',
      'group_resent',
    ]) {
      await db.delete(table, where: 'group_id = ?', whereArgs: [groupId]);
    }
    // what of it came in and went is known no longer
    final gone = goneGroupPrefix(groupId);
    for (final k in {
      for (final r in await db.query('gone_in', columns: ['peer_id']))
        if (r['peer_id'] case final String k when k.startsWith(gone)) k,
    }) {
      await db.delete('gone_in', where: 'peer_id = ?', whereArgs: [k]);
    }
    // a take-back still goes to members who may hold the message, after
    // a leave or a remove too: they act on it without the group, and so
    // does an end. a room's keys go with it, and nothing of it could go
    for (final r in await db.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    )) {
      if (!room && groupUnsendOf(r['ctl']) != null) continue;
      if (!room && groupEndOut(r['ctl'])) continue;
      await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
    await db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete(
      'notif_tags',
      where: 'chat = ?',
      whereArgs: ['group:$groupId'],
    );
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // a burner room: a group row with a key of its own and an end time.
  // members are room keys, not kryfo ids; admin_id is the creator's key.
  // [joiningAt]: joined off a link, waiting for the creator's roster
  Future<void> createRoom({
    required String groupId,
    required String name,
    required String priv,
    required String pub,
    required int expiresAt,
    required String creatorPub,
    required String fcPk,
    int? cap,
    required List<String> members,
    int? joiningAt,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': creatorPub == pub ? 1 : 0,
      'admin_id': creatorPub,
      'room_priv': priv,
      'room_pub': pub,
      'expires_at': expiresAt,
      'creator_pub': creatorPub,
      'fc_pk': fcPk,
      'member_cap': cap,
      'joining_at': joiningAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, Object?>?> roomByPub(String pub) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'room_pub = ?',
      whereArgs: [pub],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// the room a knock on [pub] is for: its door key since a reset, its own
  /// key before one. once reset, its own key finds nothing
  Future<Map<String, Object?>?> roomByDoor(String pub) async {
    final db = await open();
    final reset = await db.query(
      'groups',
      where: 'door_pub = ?',
      whereArgs: [pub],
      limit: 1,
    );
    if (reset.isNotEmpty) return reset.first;
    final rows = await db.query(
      'groups',
      where: 'room_pub = ? AND door_pub IS NULL',
      whereArgs: [pub],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// a new link for a room this phone made: a new door key and the
  /// address it gives the link. [was] is the door before, kept until its
  /// files are gone. with [roster] the members' roster carrying the new
  /// address is queued in the same step, so a kill leaves both or neither.
  /// false when the room is not here, or not this phone's
  Future<bool> resetRoomDoor(
    String groupId, {
    required String priv,
    required String pub,
    required String fcPk,
    String? was,
    bool roster = false,
    required int now,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'groups',
        where: 'group_id = ? AND is_admin = 1 AND room_pub IS NOT NULL',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final g = rows.first;
      final n = await t.update(
        'groups',
        {'door_priv': priv, 'door_pub': pub, 'fc_pk': fcPk, 'door_was': was},
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      if (n == 0) return false;
      if (!roster) return true;
      final members = [
        for (final r in await t.query(
          'group_members',
          columns: ['halo_id'],
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'joined_at ASC',
        ))
          r['halo_id'] as String,
      ];
      final held = await _rosterRow(t, groupId);
      final stamp = max(now, ((held?['stamp'] as int?) ?? 0) + 1);
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      final body = jsonEncode(
        GroupControl(
          type: 'create',
          name: g['name'] as String,
          members: members,
          stamp: stamp,
          fc: fcPk,
        ).toWire(),
      );
      for (final m in members) {
        if (m == g['room_pub']) continue;
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
      return true;
    });
  }

  /// the door before a reset, its files gone
  Future<void> clearRoomDoorWas(String groupId, String priv) async {
    final db = await open();
    await db.update(
      'groups',
      {'door_was': null},
      where: 'group_id = ? AND door_was = ?',
      whereArgs: [groupId, priv],
    );
  }

  /// the address a room's link knocks on, as its maker last gave it
  Future<void> setRoomFc(String groupId, String fcPk) async {
    final db = await open();
    await db.update(
      'groups',
      {'fc_pk': fcPk},
      where: 'group_id = ? AND room_pub IS NOT NULL',
      whereArgs: [groupId],
    );
  }

  Future<List<Map<String, Object?>>> rooms() async {
    final db = await open();
    return db.query('groups', where: 'room_pub IS NOT NULL');
  }

  Future<List<Map<String, Object?>>> expiredRooms(int now) async {
    final db = await open();
    return db.query(
      'groups',
      where: 'room_pub IS NOT NULL AND expires_at <= ?',
      whereArgs: [now],
    );
  }

  /// a join sent again at [at], or null once the creator let this phone in
  Future<void> setRoomJoining(String groupId, int? at) async {
    final db = await open();
    await db.update(
      'groups',
      {'joining_at': at},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  /// the wait of a room still waiting starts again at [at]. one let in
  /// meanwhile stays let in. false when there was no wait to restart
  Future<bool> restartRoomJoining(String groupId, int at) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'joining_at': at},
      where: 'group_id = ? AND joining_at IS NOT NULL',
      whereArgs: [groupId],
    );
    return n > 0;
  }

  /// the join sent at [at] did not go: its wait is over at once, so the
  /// room says it is not answering. a newer join, or a let-in, is kept
  Future<bool> failRoomJoining(String groupId, int at) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'joining_at': at - kRoomJoinWait.inMilliseconds},
      where: 'group_id = ? AND joining_at = ?',
      whereArgs: [groupId, at],
    );
    return n > 0;
  }

  Future<void> markRoomSeen(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'room_seen': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // every file a group's messages point at, so expiry can shred them
  Future<List<String>> groupFilePaths(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['media_path', 'file_path'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return [
      for (final r in rows)
        for (final k in const ['media_path', 'file_path'])
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  Future<void> deleteGroupMessages(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
      }
    }
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // a chat's order (msg_order.dart): by when each was written, then as
  // they came. before and from name a row by its time and id
  static const _kOldestFirst = 'written_at ASC, id ASC';
  static const _kNewestFirst = 'written_at DESC, id DESC';
  static const _kBefore = '(written_at < ? OR (written_at = ? AND id < ?))';
  static const _kFrom = '(written_at > ? OR (written_at = ? AND id >= ?))';

  // the args for _kBefore or _kFrom at row [id]. its own time when [at] is
  // not given, null when that row is gone
  static Future<List<Object>?> _at(Database db, int id, int? at) async {
    if (at != null) return [at, at, id];
    final r = await db.query(
      'messages',
      columns: ['written_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final w = r.isEmpty ? null : (r.first['written_at'] as num?)?.toInt();
    return w == null ? null : [w, w, id];
  }

  // peer_id on each row is the sender's kryfo id, ours on our own messages
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: _kOldestFirst,
    );
  }

  // the newest page of a group, or the one before row [beforeRowid],
  // written at [beforeAt]
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final db = await open();
    final at = beforeRowid == null
        ? null
        : await _at(db, beforeRowid, beforeAt);
    if (beforeRowid != null && at == null) return [];
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: at == null ? 'group_id = ?' : 'group_id = ? AND $_kBefore',
      whereArgs: [groupId, ...?at],
      orderBy: _kNewestFirst,
      limit: limit,
    );
    return rows.reversed.toList();
  }

  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'group_id = ? AND rowid > ?',
      whereArgs: [groupId, afterRowid],
      orderBy: 'sent_at ASC',
    );
  }

  // the chat a row lives in: (peer_id, group_id), or null when there is no
  // such row
  Future<(String, String?)?> chatOf(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['peer_id', 'group_id'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['peer_id'] as String, r.first['group_id'] as String?);
  }

  Future<void> setPinned(String msgUid, bool pinned, {int? at}) async {
    final db = await open();
    await db.update(
      'messages',
      {
        'pinned': pinned ? 1 : 0,
        'pinned_at': pinned
            ? at ?? DateTime.now().millisecondsSinceEpoch
            : null,
      },
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every pin in one chat, newest pin first, whatever part of the thread
  // the screen has loaded. a 1:1 chat by the other person's id, a group by
  // its own.
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async {
    final db = await open();
    return db.query(
      'messages',
      columns: [
        'msg_uid',
        'peer_id',
        'direction',
        'plaintext',
        'sent_at',
        'written_at',
        'media_path',
        'file_name',
        'pinned_at',
        'sticker',
        // what says it waits to be read (burnWaitsRow)
        'burn_secs',
        'burn_at',
        'burn_unseen',
      ],
      where: groupId != null
          ? 'pinned = 1 AND msg_uid IS NOT NULL AND group_id = ?'
          : "pinned = 1 AND msg_uid IS NOT NULL AND peer_id = ? "
                "AND (group_id IS NULL OR group_id = '')",
      whereArgs: [groupId ?? peerId],
      orderBy: 'COALESCE(pinned_at, written_at) DESC',
    );
  }

  Future<void> setSaved(String msgUid, bool saved) async {
    final db = await open();
    await db.update(
      'messages',
      {'saved': saved ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every saved message across all chats, newest first. peer_id rides along
  // so the saved screen can show who it's from.
  // a timed message not read yet is left out: it shows in its own chat
  // alone, where reading it starts its clock
  Future<List<Map<String, Object?>>> savedMessages() async {
    final db = await open();
    final rows = await db.query(
      'messages',
      where: 'saved = 1',
      orderBy: _kNewestFirst,
      limit: 500,
    );
    return [
      for (final r in rows)
        if (!burnWaitsRow(r)) r,
    ];
  }

  // every column that names a file of a message: a photo, or a voice note,
  // a video or any other file
  static const _kFileCols = ['media_path', 'file_path'];
  // a person's own chat: what they wrote in groups is the groups'
  static const _kOneToOne = 'peer_id = ? AND group_id IS NULL';
  // a group_members row of a group still running
  static const _kRunningGroup =
      ' AND group_id NOT IN (SELECT group_id FROM groups '
      'WHERE ended_at IS NOT NULL)';

  // the files go too, not just the rows. zeros first, then unlink, so a raw
  // read of the flash finds nothing either.
  Future<void> _scrubMedia(List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      for (final k in const ['media_path', 'file_path']) {
        final mp = r[k] as String?;
        if (mp != null && mp.isNotEmpty) await shredFile(mp);
      }
    }
  }

  // the photo an atmosphere names, null for a preset
  static String? _photoOf(Object? atmosphere) =>
      atmosphere is String && atmosphere.startsWith('image:')
      ? atmosphere.substring(6)
      : null;

  // every photo a chat or group here names, by its name in the folder
  Future<Set<String>> _namedPhotos() async {
    final db = await open();
    return {
      for (final t in const ['contacts', 'groups'])
        for (final r in await db.query(
          t,
          columns: ['atmosphere'],
          where: 'atmosphere IS NOT NULL',
        ))
          if (_photoOf(r['atmosphere']) case final f?) p.basename(f),
    };
  }

  // wallpapers whose rows are written without them. one a row still names
  // stays, and only this container's wallpapers folder is ever touched
  Future<void> _dropPhotos(Iterable<Object?> atmospheres) async {
    final names = {
      for (final a in atmospheres)
        if (_photoOf(a) case final f?) p.basename(f),
    }..removeWhere((n) => n.isEmpty || n == '.' || n == '..');
    if (names.isEmpty) return;
    try {
      final named = await _namedPhotos();
      final dir = await container.folder('wallpapers');
      for (final n in names) {
        if (!named.contains(n)) await shredFile(p.join(dir.path, n));
      }
    } catch (e) {
      // the start sweep takes it
      dlog('wallpaper: not shredded (${e.runtimeType})');
    }
  }

  static final _randomWall = RegExp(r'^wp_[0-9a-f]{32}\.jpg$');

  /// wallpapers an older version named after their chat get a random name:
  /// the row is written first, then the file renamed. a start between the
  /// two finds the row's file missing and the old name beside it, and
  /// finishes the rename. throws when a rename is left undone, so nothing
  /// is swept that a row is about to name
  Future<void> renameNamedWallpapers() async {
    final db = await open();
    final dir = await container.folder('wallpapers');
    for (final r in await db.query(
      'contacts',
      columns: ['halo_id', 'atmosphere'],
      where: 'atmosphere IS NOT NULL',
    )) {
      final id = r['halo_id'] as String;
      final was = r['atmosphere'];
      final f = _photoOf(was);
      if (f == null) continue;
      final leaf = p.basename(f);
      final at = File(p.join(dir.path, leaf));
      final type = await FileSystemEntity.type(at.path, followLinks: false);
      if (_randomWall.hasMatch(leaf)) {
        if (type == FileSystemEntityType.notFound) {
          await (await _namedAfter(dir, id))?.rename(at.path);
        }
        continue;
      }
      // only a file of ours: a link or a folder is left as it is
      if (type != FileSystemEntityType.file) continue;
      final to = p.join(dir.path, _freshWallLeaf());
      final written = await db.transaction((t) async {
        if (await _atmosphereOf(t, id) != was) return false;
        await t.update(
          'contacts',
          {'atmosphere': 'image:$to'},
          where: 'halo_id = ?',
          whereArgs: [id],
        );
        return true;
      });
      if (written) await at.rename(to);
    }
  }

  // a wallpaper an older version named after [id]'s chat, the newest
  static Future<File?> _namedAfter(Directory dir, String id) async {
    final shape = RegExp('^${RegExp.escape(id)}(_[0-9a-f]{16})?\\.jpg\$');
    File? best;
    DateTime? at;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !shape.hasMatch(p.basename(e.path))) continue;
      final m = await e.lastModified();
      if (at == null || m.isAfter(at)) (best, at) = (e, m);
    }
    return best;
  }

  /// the files in this container's wallpapers folder that no chat or group
  /// names, last written before [before]: what a delete or a crash left
  Future<List<File>> unnamedWallpapers({required DateTime before}) async {
    final named = await _namedPhotos();
    final dir = await container.folder('wallpapers');
    final out = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || named.contains(p.basename(e.path))) continue;
      if ((await e.lastModified()).isBefore(before)) out.add(e);
    }
    return out;
  }

  /// the files in this container's media folder that no message names,
  /// last written before [before]: what a delete left behind. a file is
  /// matched by its name in the folder, so rows written under another
  /// path to the same folder still hold theirs. folders are left alone
  Future<List<File>> unnamedMedia({required DateTime before}) async {
    final db = await open();
    final named = <String>{};
    for (final col in _kFileCols) {
      for (final r in await db.query(
        'messages',
        columns: [col],
        where: '$col IS NOT NULL',
      )) {
        final v = r[col];
        if (v is String && v.isNotEmpty) named.add(p.basename(v));
      }
    }
    final dir = await container.mediaDir();
    final out = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || named.contains(p.basename(e.path))) continue;
      if ((await e.lastModified()).isBefore(before)) out.add(e);
    }
    return out;
  }

  // every 1:1 row of one chat that is not a person's, the notes to self:
  // their files and reactions go with them. how many went
  Future<int> deleteAllOf(String chatId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kOneToOne,
      whereArgs: [chatId],
    );
    await db.transaction((t) async {
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await _noteGone(t, rows);
      await t.delete('messages', where: _kOneToOne, whereArgs: [chatId]);
    });
    await _scrubMedia(rows);
    return rows.length;
  }

  Future<void> deleteMessage(String msgUid) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await _unreadGo(db, media);
    await _noteGone(db, media);
    await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await db.delete(
      'group_media_owed',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await _scrubMedia(media);
  }

  // what a row needs for _unreadGo to place it
  static const _kUnreadCols = ['id', 'peer_id', 'group_id', 'direction'];
  // and for _noteGone, with those
  static const _kGoneCols = ['msg_uid', 'sent_at', 'album_id'];

  // how long one that came in and went is known by its uid: as far back
  // as a resend reaches, and our relay's fortnight, which a fresh install
  // after a restore reads again. other relays keep what they choose
  static const kGoneFor = Duration(days: 15);

  // the rows of these that came in, kept by uid as they go: a 1:1 one by
  // its sender, a group's or a room's by its group and sender (goneKey).
  // only what a resend or the relays could still bring: sent within
  // kGoneFor and a day for clocks
  static Future<void> _noteGone(
    DatabaseExecutor db,
    Iterable<Map<String, Object?>> rows, {
    // burned on its timer: its album takes nothing after it. a delete or a
    // clear by hand leaves later items to show and ring as their own
    bool burned = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final from =
        now - kGoneFor.inMilliseconds - const Duration(days: 1).inMilliseconds;
    // one commit for all of them: a busy group cleared is thousands
    final b = db.batch();
    var any = false;
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      final peer = r['peer_id'] as String?;
      final group = r['group_id'] as String?;
      final sent = (r['sent_at'] as num?)?.toInt();
      if (uid == null || peer == null || r['direction'] != 'in') continue;
      if (sent != null && sent < from) continue;
      if (!goneKept(group)) continue;
      b.insert('gone_in', {
        'msg_uid': uid,
        'peer_id': goneKey(peer, group: group),
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // an album that burned takes nothing that comes after (albumGone)
      if (r['album_id'] case final String album when burned) {
        b.insert('gone_in', {
          'msg_uid': albumGoneUid(album),
          'peer_id': goneKey(peer, group: group),
          'at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      any = true;
    }
    if (any) await b.commit(noResult: true);
  }

  /// [msgUid] came in from [peer] and burned or was deleted here lately
  Future<bool> goneFrom(String peer, String msgUid) async {
    final db = await open();
    final r = await db.query(
      'gone_in',
      columns: ['at'],
      where: 'msg_uid = ? AND peer_id = ?',
      whereArgs: [msgUid, peer],
      limit: 1,
    );
    if (r.isEmpty) return false;
    final at = (r.first['at'] as num).toInt();
    return DateTime.now().millisecondsSinceEpoch - at < kGoneFor.inMilliseconds;
  }

  // rows that came in and go before they were read take their unread mark
  // with them. the unread ones are the newest that many that came in
  Future<void> _unreadGo(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    final gone = <(String, bool), Set<int>>{};
    for (final r in rows) {
      final id = r['id'];
      if (r['direction'] != 'in' || id is! int) continue;
      final g = r['group_id'] as String?;
      final peer = r['peer_id'] as String?;
      final chat = g != null ? (g, true) : (peer, false);
      if (chat.$1 == null) continue;
      (gone[(chat.$1!, chat.$2)] ??= {}).add(id);
    }
    for (final MapEntry(key: (chat, group), value: ids) in gone.entries) {
      final table = group ? 'groups' : 'contacts';
      final key = group ? 'group_id = ?' : 'halo_id = ?';
      final c = await db.query(
        table,
        columns: ['unread'],
        where: key,
        whereArgs: [chat],
        limit: 1,
      );
      final unread = c.isEmpty ? 0 : (c.first['unread'] as int? ?? 0);
      if (unread <= 0) continue;
      final newest = await db.query(
        'messages',
        columns: ['id'],
        where: group
            ? "group_id = ? AND direction = 'in'"
            : "$_kOneToOne AND direction = 'in'",
        whereArgs: [chat],
        orderBy: 'id DESC',
        limit: unread,
      );
      final n = newest.where((r) => ids.contains(r['id'])).length;
      if (n == 0) continue;
      // nothing left unread in a group: no mention is left in it either
      await db.update(
        table,
        {'unread': unread - n, if (group && unread - n <= 0) 'mentioned': 0},
        where: key,
        whereArgs: [chat],
      );
    }
  }

  // a timed message of ours that went but never had its clock started:
  // from before receipts lit it, or a stop between marking it sent and
  // lighting it. once per open is enough, nothing makes new ones after
  bool _strandedLit = false;
  Future<void> _lightStrandedOnce(Database db) async {
    if (_strandedLit) return;
    await _lightStranded(db);
    _strandedLit = true;
  }

  Future<int> lightStrandedBurns() async => _lightStranded(await open());

  static Future<int> _lightStranded(Database db) async {
    final rows = await db.query(
      'messages',
      columns: ['id', 'burn_secs'],
      where:
          "direction = 'out' AND sent = 1 AND burn_secs IS NOT NULL "
          'AND burn_at IS NULL',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      final secs = (r['burn_secs'] as num).toInt();
      await db.update(
        'messages',
        {'burn_at': now + secs * 1000},
        where: 'id = ? AND burn_at IS NULL',
        whereArgs: [r['id']],
      );
    }
    return rows.length;
  }

  // a row of ours that has not gone yet is not due: its clock starts when
  // it goes. only outgoing rows are ever unsent
  static const _kBurnDue = 'burn_at IS NOT NULL AND burn_at < ? AND sent = 1';

  // the timed rows that came in and wait to be read, with [cols]
  Future<List<Map<String, Object?>>> _idle(Database db, List<String> cols) =>
      db.query(
        'messages',
        columns: {...cols, 'id', 'peer_id', 'sent_at', 'burn_secs'}.toList(),
        where: _kBurnIdle,
      );

  // waited unread a day and its window after that: due as if lit then,
  // whether or not anything lit it. a phone off all that time, or a vault
  // shut, burns it at the next sweep
  static bool _waitedOut(Map<String, Object?> r, int now) =>
      burnStartBy((r['sent_at'] as num?)?.toInt() ?? now, now) +
          (r['burn_secs'] as num).toInt() * 1000 <
      now;

  Future<int> _dropRows(Database db, List<Map<String, Object?>> rows) async {
    var n = 0;
    for (var i = 0; i < rows.length; i += 500) {
      final ids = [for (final r in rows.skip(i).take(500)) r['id']];
      n += await db.delete(
        'messages',
        where: 'id IN (${List.filled(ids.length, '?').join(', ')})',
        whereArgs: ids,
      );
    }
    return n;
  }

  // what still waits a day after it came starts counting, unread, and so
  // does a blocked sender's (a restore or a hide brings blocks along).
  // [blocked] is everyone blocked on this side, this container's own list
  // when null. an arrival further ahead of this phone's clock than
  // kBurnSkew counts from now, written down so it cannot wait on
  Future<void> _lightWaited(
    Database db,
    int now,
    List<Map<String, Object?>> idle,
    Future<Set<String>> Function()? blocked,
  ) async {
    final rows = [
      for (final r in idle)
        if (!_waitedOut(r, now)) r,
    ];
    if (rows.isEmpty) return;
    final out = await (blocked == null ? _blockedIn(db) : blocked());
    final ahead = now + kBurnSkew.inMilliseconds;
    final lit = <(Map<String, Object?>, int)>[];
    for (final r in rows) {
      final sent = (r['sent_at'] as num?)?.toInt() ?? now;
      final by = burnStartBy(sent, now);
      if (out.contains(r['peer_id'])) {
        lit.add((r, min(now, by)));
      } else if (by <= now || sent > ahead) {
        lit.add((r, by));
      }
    }
    if (lit.isEmpty) return;
    await db.transaction((t) async {
      for (final (r, from) in lit) {
        await _lightUnread(t, r, from);
      }
    });
  }

  // [blocked] as for purgeExpired
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {
    final db = await open();
    await _lightStrandedOnce(db);
    final cut = DateTime.now().millisecondsSinceEpoch;
    final due = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kBurnDue,
      whereArgs: [cut],
    );
    final idle = await _idle(db, [
      ..._kFileCols,
      ..._kUnreadCols,
      ..._kGoneCols,
    ]);
    // after what waits is read: nothing in it was filed past this now
    final now = DateTime.now().millisecondsSinceEpoch;
    final waited = [
      for (final r in idle)
        if (_waitedOut(r, now)) r,
    ];
    final rows = [...due, ...waited];
    await _unreadGo(db, rows);
    await _noteGone(db, rows, burned: true);
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        // the sweep would have taken its notification down, and this
        // read can beat the sweep to it
        if (r['direction'] == 'in') unawaited(clearMessageNotification(uid));
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        await db.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [uid],
        );
      }
    }
    await db.delete('messages', where: _kBurnDue, whereArgs: [cut]);
    await _dropRows(db, waited);
    await _scrubMedia(rows);
    await _lightWaited(db, now, idle, blocked);
  }

  Future<void> bumpUnread(String peerId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE contacts SET unread = unread + 1 WHERE halo_id = ?',
      [peerId],
    );
  }

  Future<void> clearUnread(String peerId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'unread': 0},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> bumpGroupUnread(String groupId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE groups SET unread = unread + 1 WHERE group_id = ?',
      [groupId],
    );
  }

  Future<void> setGroupMentioned(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'mentioned': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> clearGroupUnread(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'unread': 0, 'mentioned': 0},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // the same as setChatAtmosphere: one way in, so a photo always goes with
  // the choice that replaced it
  Future<void> setGroupAtmosphere(String groupId, String atmosphere) =>
      setChatAtmosphere(groupId, atmosphere, group: true);

  Future<String?> getGroupAtmosphere(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['atmosphere'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  // the photo it had goes once the row is written (setChatAtmosphere)
  Future<void> setAtmosphere(String peerId, String atmosphere) =>
      setChatAtmosphere(peerId, atmosphere);

  // a chat's own voice disguise choice, null until one is made here
  Future<bool?> voiceDisguiseOf(String chatId, {bool group = false}) async {
    final db = await open();
    final rows = await db.query(
      group ? 'groups' : 'contacts',
      columns: ['voice_disguise'],
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['voice_disguise'];
    return v is int ? v == 1 : null;
  }

  Future<void> setVoiceDisguise(
    String chatId,
    bool on, {
    bool group = false,
  }) async {
    final db = await open();
    await db.update(
      group ? 'groups' : 'contacts',
      {'voice_disguise': on ? 1 : 0},
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
    );
  }

  // a chat's screenshot block (chat_shots.dart)
  Future<ChatShots> shotsOf(String peer) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ChatShots.reads,
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    return ChatShots.ofRow(rows.firstOrNull, quiet: container.quiet);
  }

  // a change made here, for [peer]'s phone to take: its stamp, past the
  // one held, read and written in one go. null with no row
  Future<int?> turnShots(String peer, {required bool on}) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'contacts',
        columns: const ['shots_at'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final at = shotsNextStamp((rows.first['shots_at'] as num).toInt(), now);
      await t.update(
        'contacts',
        {
          'shots_on': on ? 1 : 0,
          'shots_at': at,
          'shots_by': kShotsByMe,
          'shots_when': now,
        },
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
      return at;
    });
  }

  // what a 1:1 envelope from [peer] says of the block. [counts]: a message
  // of theirs (shotsCanAfter). true when anything changed
  Future<bool> takeShots(
    String peer,
    ShotsWord? word, {
    required bool counts,
    int? written,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'contacts',
        columns: [...ChatShots.columns, 'accepted'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final was = ChatShots.ofRow(rows.first);
      // a request sets nothing on this screen: it could keep its own words
      // from being kept
      final accepted = rows.first['accepted'] == 1;
      final can = shotsCanAfter(
        was.can,
        carried: word != null,
        counts: counts,
        written: written,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final took =
          accepted &&
          word != null &&
          shotsInTime(word, now) &&
          shotsWins(word, on: was.on, at: was.at);
      // a burst of theirs keeps its line where the burst began, saying
      // where it ended
      final burst =
          was.by == kShotsByThem &&
          now - was.when < kShotsLineGap.inMilliseconds;
      final put = <String, Object?>{
        'shots_can': ?can,
        if (took) ...{
          'shots_on': word.on ? 1 : 0,
          'shots_at': word.at,
          if (word.on != was.on) ...{
            'shots_by': kShotsByThem,
            if (!burst) 'shots_when': now,
          },
        },
      };
      if (put.isEmpty) return false;
      await t.update('contacts', put, where: 'halo_id = ?', whereArgs: [peer]);
      return true;
    });
  }

  // accepted chats whose phones know the block and that do not block yet
  Future<List<String>> shotsCanTurnOn() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: const ['halo_id'],
      where: 'accepted = 1 AND blocked = 0 AND shots_can > ? AND shots_on = 0',
      whereArgs: [0],
    );
    return [
      for (final r in rows)
        if (!isDevChat(r['halo_id'] as String)) r['halo_id'] as String,
    ];
  }

  Future<String?> getAtmosphere(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  // a wallpaper row by its key (wallKey, '' for the default)
  Future<({String atmo, Uint8List? photo})?> wallpaperRow(String key) async {
    final db = await open();
    final rows = await db.query(
      'wallpapers',
      columns: ['atmo', 'photo'],
      where: 'chat = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final photo = rows.first['photo'];
    return (
      atmo: rows.first['atmo'] as String,
      photo: photo is Uint8List
          ? photo
          : photo is List<int>
          ? Uint8List.fromList(photo)
          : null,
    );
  }

  // what a chat's atmosphere says now, as its row has it
  static Future<String?> _wallOf(
    DatabaseExecutor t,
    String chatId,
    bool group,
  ) async {
    final r = await t.query(
      group ? 'groups' : 'contacts',
      columns: ['atmosphere'],
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['atmosphere'] as String?;
  }

  // a chat's own photo behind it, and its atmosphere saying so. the row is
  // written first and the photo only when it found its chat, so a photo
  // never lands where no chat names it. a file an older version kept for
  // it is shredded once the row is written. whether it was kept
  Future<bool> setChatPhoto(
    String chatId,
    Uint8List photo, {
    bool group = false,
  }) async {
    final db = await open();
    final (kept, was) = await db.transaction((t) async {
      final was = await _wallOf(t, chatId, group);
      final n = await t.update(
        group ? 'groups' : 'contacts',
        {'atmosphere': kPhotoWall},
        where: group ? 'group_id = ?' : 'halo_id = ?',
        whereArgs: [chatId],
      );
      if (n != 1) return (false, null);
      await t.insert('wallpapers', {
        'chat': wallKey(chatId, group: group),
        'atmo': kPhotoWall,
        'photo': photo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return (true, was);
    });
    await _dropPhotos([was]);
    return kept;
  }

  // a built-in by name, or null to follow the default. a photo it had goes
  Future<void> setChatAtmosphere(
    String chatId,
    String? atmo, {
    bool group = false,
  }) async {
    final db = await open();
    final was = await db.transaction((t) async {
      final was = await _wallOf(t, chatId, group);
      await t.delete(
        'wallpapers',
        where: 'chat = ?',
        whereArgs: [wallKey(chatId, group: group)],
      );
      await t.update(
        group ? 'groups' : 'contacts',
        {'atmosphere': atmo},
        where: group ? 'group_id = ?' : 'halo_id = ?',
        whereArgs: [chatId],
      );
      return was;
    });
    await _dropPhotos([was]);
  }

  // the default: a built-in by name, or kPhotoWall with its photo
  Future<void> setDefaultWallpaper(String atmo, [Uint8List? photo]) async {
    final db = await open();
    await db.insert('wallpapers', {
      'chat': '',
      'atmo': atmo,
      'photo': photo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearConversation(String peerId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kOneToOne,
      whereArgs: [peerId],
    );
    await _noteGone(db, media);
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE $_kOneToOne AND msg_uid IS NOT NULL)',
      [peerId],
    );
    await db.delete('messages', where: _kOneToOne, whereArgs: [peerId]);
    await _dropFilesComingFrom(db, peerId);
    await _scrubMedia(media);
  }

  // [noteGone] false for a group about to go: its delete drops the records
  Future<void> clearGroupConversation(
    String groupId, {
    bool noteGone = true,
  }) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (noteGone) await _noteGone(db, media);
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE group_id = ? AND msg_uid IS NOT NULL)',
      [groupId],
    );
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await _dropGroupFiles(db, groupId);
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
    await _scrubMedia(media);
  }

  // what a group left by an older version kept, and the paths of its files
  Future<List<String>> dropGroupLeftovers() async {
    final db = await open();
    final rows = await db.transaction(dropGroupLeftoversIn);
    return [
      for (final r in rows)
        for (final k in _kFileCols)
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  // a stranger past the cap gets a small shelf, not a disk. [mediaId]
  // names the file a slice is of and [chunk] its place in it, of [total]:
  // a file takes one place and each of its slices one row. an [overflow]
  // row is a cipher as it came, kept for its bytes alone
  Future<Shelved> holdCipher(
    String peerId,
    String cipher, {
    String? mediaId,
    int? chunk,
    int? total,
    bool overflow = false,
  }) async {
    final db = await open();
    // a copy of one held already (off a relay's backlog) is held once
    final slice = !overflow && mediaId != null && chunk != null;
    final had = await db.query(
      'held_onion',
      columns: ['id'],
      where: slice
          ? 'peer_id = ? AND media_id = ? AND chunk = ?'
          : 'peer_id = ? AND cipher = ?',
      whereArgs: slice ? [peerId, mediaId, chunk] : [peerId, cipher],
      limit: 1,
    );
    if (had.isNotEmpty) return Shelved.kept;
    final shelf = await shelfOf(peerId);
    final v = shelfVerdict(
      places: shelf.places,
      files: shelf.files,
      bytes: shelf.bytes,
      size: cipher.length,
      mediaId: mediaId,
      chunk: chunk,
      total: total,
      overflow: overflow,
    );
    if (v != Shelved.kept) return v;
    await db.insert('held_onion', {
      'peer_id': peerId,
      'cipher': cipher,
      'at': DateTime.now().millisecondsSinceEpoch,
      'media_id': overflow ? null : mediaId,
      'chunk': overflow ? null : chunk,
    });
    return Shelved.kept;
  }

  // the places their shelf takes, the slices of each file on it and the
  // bytes it holds. a row as it came (overflow) takes no place
  Future<({int places, Map<String, Set<int?>> files, int bytes})> shelfOf(
    String peerId,
  ) async {
    final db = await open();
    final texts =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) n FROM held_onion WHERE peer_id = ? AND media_id IS NULL AND cipher LIKE ?',
            [peerId, 'wire:%'],
          ),
        ) ??
        0;
    final files = <String, Set<int?>>{};
    var bytes = 0;
    for (final r in await db.query(
      'held_onion',
      columns: ['media_id', 'chunk', 'length(cipher) AS n'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
    )) {
      bytes += (r['n'] as num?)?.toInt() ?? 0;
      final m = r['media_id'] as String?;
      if (m != null) (files[m] ??= {}).add((r['chunk'] as num?)?.toInt());
    }
    return (places: texts + files.length, files: files, bytes: bytes);
  }

  // strangers whose shelf is full, [only] or everyone's, with the files on
  // it: what more they send waits on the relay
  Future<Map<String, Set<String>>> fullShelves({String? only}) async {
    final db = await open();
    final out = <String, Set<String>>{};
    final ids = only != null
        ? [only]
        : [
            for (final r in await db.query(
              'held_onion',
              distinct: true,
              columns: ['peer_id'],
            ))
              r['peer_id'] as String,
          ];
    for (final id in ids) {
      final shelf = await shelfOf(id);
      if (shelf.places < kShelfPlaces) continue;
      if (await isAccepted(id) || await isBlocked(id) || await isVouched(id)) {
        continue;
      }
      out[id] = shelf.files.keys.toSet();
    }
    return out;
  }

  // what the shelf holds for them, oldest first. a row goes with
  // forgetHeld once it is in, so one that fails stays
  Future<List<({int id, String cipher, int at})>> heldOf(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'held_onion',
      columns: ['id', 'cipher', 'at'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'id ASC',
    );
    return [
      for (final r in rows)
        (
          id: r['id'] as int,
          cipher: r['cipher'] as String,
          at: r['at'] as int? ?? 0,
        ),
    ];
  }

  Future<void> forgetHeld(int id) async {
    final db = await open();
    await db.delete('held_onion', where: 'id = ?', whereArgs: [id]);
  }

  // people accepted already with something still on the shelf: an accept
  // that failed part way, or died before it was through
  Future<List<String>> heldOfAccepted() async {
    final db = await open();
    final rows = await db.rawQuery(kHeldOfAccepted);
    return [for (final r in rows) r['peer_id'] as String];
  }

  Future<void> dropHeld(String peerId) async {
    final db = await open();
    await db.delete('held_onion', where: 'peer_id = ?', whereArgs: [peerId]);
  }

  // a stranger's opener that opened and did not file, kept as it came to be
  // tried again: [peer] is who it opened to, empty for someone the everyday
  // side does not name, and [uid] the message it carries. false when there
  // is no room for it (firstKeepFits)
  Future<bool> keepFirst(
    String hash,
    String cipher, {
    String peer = '',
    String? uid,
    required int now,
    Reached? reached,
  }) async {
    final db = await open();
    final rows = await db.query(
      'first_kept',
      columns: ['hash', 'cipher', 'peer'],
    );
    if (rows.any((r) => r['hash'] == hash)) return true;
    var bytes = 0;
    var mine = 0;
    for (final r in rows) {
      bytes += (r['cipher'] as String).length;
      if (r['peer'] == peer) mine++;
    }
    if (!firstKeepFits(
      rows: rows.length,
      mine: mine,
      bytes: bytes,
      size: cipher.length,
      named: peer.isNotEmpty,
    )) {
      return false;
    }
    await db.insert('first_kept', {
      'hash': hash,
      'cipher': cipher,
      'peer': peer,
      'uid': uid,
      'at': now,
      'tries': 0,
      'next_at': now + firstRetryGap(0).inMilliseconds,
      'reached_from': reached?.from,
      'reached_until': reached?.until,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  // every kept opener, oldest first
  Future<List<FirstKept>> firstKept() async {
    final db = await open();
    final rows = await db.query('first_kept', orderBy: 'at ASC');
    return [
      for (final r in rows)
        (
          hash: r['hash'] as String,
          cipher: r['cipher'] as String,
          peer: r['peer'] as String? ?? '',
          at: (r['at'] as num).toInt(),
          tries: (r['tries'] as num).toInt(),
          nextAt: (r['next_at'] as num).toInt(),
          reached: switch ((r['reached_from'], r['reached_until'])) {
            (final int f, final int u) => (from: f, until: u),
            _ => null,
          },
        ),
    ];
  }

  Future<void> retryFirstAt(String hash, int tries, int nextAt) async {
    final db = await open();
    await db.update(
      'first_kept',
      {'tries': tries, 'next_at': nextAt},
      where: 'hash = ?',
      whereArgs: [hash],
    );
  }

  Future<void> forgetFirst(String hash) async {
    final db = await open();
    await db.delete('first_kept', where: 'hash = ?', whereArgs: [hash]);
  }

  // what [peer] has kept here: their request went, or they took [uid] back
  Future<void> forgetFirstOf(String peer, {String? uid}) async {
    final db = await open();
    await db.delete(
      'first_kept',
      where: uid == null ? 'peer = ?' : 'peer = ? AND uid = ?',
      whereArgs: [peer, ?uid],
    );
  }

  // every kept opener: none of them opens under a new invite key
  Future<void> forgetAllFirst() async {
    final db = await open();
    await db.delete('first_kept');
  }

  // and those kept before [cut], in a vault that was shut as the key moved
  Future<void> forgetFirstBefore(int cut) async {
    final db = await open();
    await db.delete('first_kept', where: 'at < ?', whereArgs: [cut]);
  }

  // whether an opener of [peer]'s, or of someone unnamed, with [uid] is kept
  Future<bool> firstKeptHas(String peer, String uid) async {
    final db = await open();
    final rows = await db.query(
      'first_kept',
      columns: ['peer'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows.any((r) => r['peer'] == peer || r['peer'] == '');
  }

  // [uid] taken back by [peer] before it came: known as gone, so a copy
  // that comes later, after a restart too, is never shown
  Future<void> noteTakenBack(String peer, String uid) async {
    final db = await open();
    await db.insert('gone_in', {
      'msg_uid': uid,
      'peer_id': peer,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // our 1:1 texts and files to [peer] that went, oldest first: past their
  // stranger cap, theirs are held rather than shown
  Future<List<String>> sentUidsTo(String peer) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: "$_kOneToOne AND direction = 'out' AND sent = 1",
      whereArgs: [peer],
      orderBy: 'sent_at ASC',
    );
    return [
      for (final r in rows)
        if (r['msg_uid'] case final String u) u,
    ];
  }

  // our sent texts to [peer] with no receipt yet, the openers among them
  // while they have not added us back
  Future<List<Map<String, Object?>>> sentUnconfirmed(String peer) async {
    final db = await open();
    return db.query(
      'messages',
      where:
          "$_kOneToOne AND direction = 'out' AND sent = 1 AND delivered = 0 "
          'AND msg_uid IS NOT NULL AND media_path IS NULL AND file_path IS NULL',
      whereArgs: [peer],
      orderBy: 'sent_at ASC',
    );
  }

  // people we may have written to who have not added us back, and are
  // neither blocked nor flagged with a new key
  Future<List<String>> notBackPaired() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'back_paired = 0 AND blocked = 0 AND key_changed = 0',
    );
    return [for (final r in rows) r['halo_id'] as String];
  }

  // how often an opener of ours went again, when it last did, the words it
  // first went as and whether its onion and relay copies both went
  Future<({int tries, int lastAt, String? wire, bool both})?> openerAgain(
    String uid,
  ) async {
    final db = await open();
    final rows = await db.query(
      'opener_again',
      where: 'msg_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      tries: (r['tries'] as num).toInt(),
      lastAt: (r['last_at'] as num).toInt(),
      wire: r['wire'] as String?,
      both: r['both_went'] == 1,
    );
  }

  Future<void> _openerRow(String uid, Map<String, Object?> v) async {
    final db = await open();
    final n = await db.update(
      'opener_again',
      v,
      where: 'msg_uid = ?',
      whereArgs: [uid],
    );
    if (n > 0) return;
    await db.insert('opener_again', {
      'msg_uid': uid,
      'last_at': DateTime.now().millisecondsSinceEpoch,
      ...v,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> noteOpenerAgain(String uid, int tries, int at) =>
      _openerRow(uid, {'tries': tries, 'last_at': at});

  // an opener's words as they first went: what goes again is the same, so
  // a gate that held it holds no second copy
  Future<void> keepOpenerWire(String uid, String wire) =>
      _openerRow(uid, {'wire': wire});

  // its onion took it and its relay copy went too
  Future<void> noteOpenerBoth(String uid) => _openerRow(uid, {'both_went': 1});

  // what went again before [cut] is past the relays' keeping
  Future<void> forgetOpenersBefore(int cut) async {
    final db = await open();
    await db.delete('opener_again', where: 'last_at < ?', whereArgs: [cut]);
  }

  Future<void> queuePin(String msgUid, String peerId, bool pinned) async {
    final db = await open();
    // one row a message: the latest word replaces the last
    await db.insert('pins_out', {
      'msg_uid': msgUid,
      'peer_id': peerId,
      'pinned': pinned ? 1 : 0,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // the oldest rows whose turn has come: one still waiting out its gap
  // keeps no other out of the window
  Future<List<Map<String, Object?>>> unsentPins({
    Set<String> skip = const {},
    int? now,
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'pins_out',
      where: '$kNotBlocked AND next_at < ?${_notIn(s)}',
      whereArgs: [(now ?? DateTime.now().millisecondsSinceEpoch) + 1, ...s],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  /// a drain's try of a queued pin is starting: counted, and the next one
  /// waits its gap. a newer word queued meanwhile is not touched
  Future<void> triedPin(String msgUid, bool pinned, int tries, int now) =>
      _tried(
        'pins_out',
        'msg_uid = ? AND pinned = ?',
        [msgUid, pinned ? 1 : 0],
        tries,
        now,
      );

  Future<void> _tried(
    String table,
    String where,
    List<Object?> args,
    int tries,
    int now,
  ) async {
    final db = await open();
    await db.update(
      table,
      {'tries': tries + 1, 'next_at': now + queueGap(tries)},
      where: where,
      whereArgs: args,
    );
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropPin(String msgUid, bool pinned) async {
    final db = await open();
    await db.delete(
      'pins_out',
      where: 'msg_uid = ? AND pinned = ?',
      whereArgs: [msgUid, pinned ? 1 : 0],
    );
  }

  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      // a message taken back has nothing left to edit, pin or react to
      if (kind == kFrameUnsend) {
        for (final table in const ['edits_out', 'pins_out', 'frames_out']) {
          await t.delete(
            table,
            where: 'msg_uid = ? AND peer_id = ?',
            whereArgs: [msgUid, peerId],
          );
        }
      }
      await t.insert('frames_out', {
        'msg_uid': msgUid,
        'kind': kind,
        'peer_id': peerId,
        'body': body,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // the oldest rows that can go now: none of the [waiting] peers', whose
  // seals wait on their card, and none still waiting out its gap. a
  // receipt or a reaction a week old, or a reaction past its tries, has
  // no one left to reach, and goes. a take-back stays
  Future<List<Map<String, Object?>>> unsentFrames({
    Iterable<String> waiting = const [],
    int? now,
  }) async {
    final db = await open();
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final old = at - kReceiptKeptFor.inMilliseconds;
    for (final kind in const [kFrameReceipt, kFrameReaction]) {
      await db.delete(
        'frames_out',
        where: 'kind = ? AND at < ?',
        whereArgs: [kind, old],
      );
    }
    for (final kind in const [kFrameReaction, kFrameShots]) {
      await db.delete(
        'frames_out',
        where: 'kind = ? AND tries > ?',
        whereArgs: [kind, kFrameTries - 1],
      );
    }
    final skip = waiting.toList();
    return db.query(
      'frames_out',
      where:
          'next_at < ?'
          '${skip.isEmpty ? '' : ' AND peer_id NOT IN (${List.filled(skip.length, '?').join(', ')})'}',
      whereArgs: [at + 1, ...skip],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  Future<void> triedFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
    int tries,
    int now,
  ) => _tried(
    'frames_out',
    'msg_uid = ? AND kind = ? AND peer_id = ? AND body = ?',
    [msgUid, kind, peerId, body],
    tries,
    now,
  );

  /// [w], the sender's time on an edit or reaction of [msgUid], is no
  /// older than the last one taken from them: noted, and true. false for
  /// a late copy
  Future<bool> takeFrameOrder(
    String msgUid,
    String sender,
    String kind,
    int w,
  ) async {
    final db = await open();
    return db.transaction((t) async {
      final r = await t.query(
        'frame_order',
        columns: ['w'],
        where: 'msg_uid = ? AND sender = ? AND kind = ?',
        whereArgs: [msgUid, sender, kind],
        limit: 1,
      );
      if (r.isNotEmpty && (r.first['w'] as int) > w) return false;
      await t.insert('frame_order', {
        'msg_uid': msgUid,
        'sender': sender,
        'kind': kind,
        'w': w,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {
    final db = await open();
    await db.delete(
      'frames_out',
      where: 'msg_uid = ? AND kind = ? AND peer_id = ? AND body = ?',
      whereArgs: [msgUid, kind, peerId, body],
    );
  }

  // a block: nothing queued for them goes after it, a receipt, an edit, a
  // pin or a reaction. a take-back only withdraws, and still goes
  Future<void> dropQueuedTo(String peerId) async =>
      _dropQueuedTo(await open(), peerId);

  static Future<void> _dropQueuedTo(DatabaseExecutor db, String peerId) async {
    for (final (table, where, args) in [
      ('frames_out', 'peer_id = ? AND kind != ?', [peerId, kFrameUnsend]),
      ('edits_out', 'peer_id = ?', [peerId]),
      ('pins_out', 'peer_id = ?', [peerId]),
    ]) {
      try {
        await db.delete(table, where: where, whereArgs: args);
      } catch (e) {
        dlog('block: $table not dropped (${e.runtimeType})');
      }
    }
  }

  // a block here: our texts and files to them that have not gone are not
  // sent. a tap sends each again, nothing else does. a group's rows are
  // the group's
  static Future<void> _holdBackTo(DatabaseExecutor db, String peerId) async {
    for (final (where, args) in [
      ('group_id IS NULL', const <Object?>[]),
      ('group_id = ?', const <Object?>['']),
    ]) {
      try {
        await db.update(
          'messages',
          {'sent': kNotSent},
          where: 'peer_id = ? AND direction = ? AND sent = ? AND $where',
          whereArgs: [peerId, 'out', 0, ...args],
        );
      } catch (e) {
        dlog('block: rows not held back (${e.runtimeType})');
      }
    }
  }

  // a row of ours a block here kept from going
  Future<bool> heldBack(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isNotEmpty && r.first['sent'] == kNotSent;
  }

  // one row a block kept from going
  Future<void> holdBack(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': kNotSent},
      where: 'msg_uid = ? AND direction = ? AND sent = ?',
      whereArgs: [msgUid, 'out', 0],
    );
  }

  // a tap on a row a block held back: it waits to go like any unsent row
  Future<void> sendAgain(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 0},
      where: 'msg_uid = ? AND sent = ?',
      whereArgs: [msgUid, kNotSent],
    );
  }

  Future<void> queueEdit(String msgUid, String peerId, String newText) async {
    final db = await open();
    await db.insert('edits_out', {
      'msg_uid': msgUid,
      'peer_id': peerId,
      'new_text': newText,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> unsentEdits({
    Set<String> skip = const {},
    int? now,
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'edits_out',
      where: '$kNotBlocked AND next_at < ?${_notIn(s)}',
      whereArgs: [(now ?? DateTime.now().millisecondsSinceEpoch) + 1, ...s],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  Future<void> triedEdit(String msgUid, String newText, int tries, int now) =>
      _tried(
        'edits_out',
        'msg_uid = ? AND new_text = ?',
        [msgUid, newText],
        tries,
        now,
      );

  // with [newText], only the wording that went: a newer one queued
  // meanwhile stays
  Future<void> dropEdit(String msgUid, {String? newText}) async {
    final db = await open();
    await db.delete(
      'edits_out',
      where: newText == null ? 'msg_uid = ?' : 'msg_uid = ? AND new_text = ?',
      whereArgs: [msgUid, ?newText],
    );
  }

  Future<Map<String, Object?>?> queuedEdit(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'edits_out',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  /// the sticker on a row, as it goes on the wire
  Future<String?> stickerOf(String uid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sticker'],
      where: 'msg_uid = ? AND sticker IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isEmpty ? null : StickerWire.parse(r.first['sticker'])?.value;
  }

  // ---- polls ----

  /// the poll on a row, the chat it is in, and whether it is ours
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['poll', 'group_id', 'direction'],
      where: 'msg_uid = ? AND poll IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final spec = PollSpec.parse(r.first['poll']);
    if (spec == null) return null;
    return (
      spec: spec,
      groupId: r.first['group_id'] as String?,
      mine: r.first['direction'] == 'out',
    );
  }

  Future<int?> pollVoteSeq(String pollUid, String voter) async {
    final db = await open();
    final r = await db.query(
      'poll_votes',
      columns: ['seq'],
      where: 'poll_uid = ? AND voter = ?',
      whereArgs: [pollUid, voter],
      limit: 1,
    );
    return r.isEmpty ? null : (r.first['seq'] as num).toInt();
  }

  /// keeps the vote when it is newer than the one held. false when it was
  /// a duplicate or an old vote arriving late.
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async {
    final db = await open();
    return db.transaction((tx) async {
      final r = await tx.query(
        'poll_votes',
        columns: ['seq'],
        where: 'poll_uid = ? AND voter = ?',
        whereArgs: [pollUid, voter],
        limit: 1,
      );
      final held = r.isEmpty ? null : (r.first['seq'] as num).toInt();
      if (!voteIsNewer(held, seq)) return false;
      await tx.insert('poll_votes', {
        'poll_uid': pollUid,
        'voter': voter,
        'group_id': groupId,
        'choices': jsonEncode(choices),
        'seq': seq,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// every vote held for these polls, voter by voter
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async {
    final out = <String, Map<String, PollVote>>{};
    if (uids.isEmpty) return out;
    final db = await open();
    for (var i = 0; i < uids.length; i += 400) {
      final part = uids.sublist(
        i,
        i + 400 > uids.length ? uids.length : i + 400,
      );
      final rows = await db.query(
        'poll_votes',
        where: 'poll_uid IN (${List.filled(part.length, '?').join(',')})',
        whereArgs: part,
      );
      for (final r in rows) {
        List<int> picks;
        try {
          picks = (jsonDecode(r['choices'] as String) as List)
              .whereType<int>()
              .toList();
        } catch (_) {
          continue;
        }
        out.putIfAbsent(r['poll_uid'] as String, () => {})[r['voter']
            as String] = PollVote(
          picks,
          (r['seq'] as num).toInt(),
        );
      }
    }
    return out;
  }

  /// the poll is closed: the row says so, and the votes are the final ones
  /// from the close. held above any seq a voter can send, so nothing late
  /// moves them.
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) async {
    final db = await open();
    await db.transaction((tx) async {
      await tx.update(
        'messages',
        {'poll': spec.closedNow().toRow()},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
      await tx.delete('poll_votes', where: 'poll_uid = ?', whereArgs: [uid]);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in finals.entries) {
        await tx.insert('poll_votes', {
          'poll_uid': uid,
          'voter': e.key,
          'group_id': groupId,
          'choices': jsonEncode(e.value),
          'seq': kPollFinalSeq,
          'at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> pollGone(String uid) async {
    final db = await open();
    final r = await db.query(
      'polls_gone',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  /// votes still waiting for a poll that never came: after an hour the
  /// poll is not coming, it burned or was deleted. dropped, and the marks
  /// of polls that went with them.
  Future<void> purgeStrayVotes({
    Duration after = const Duration(hours: 1),
  }) async {
    final db = await open();
    final cut = DateTime.now().subtract(after).millisecondsSinceEpoch;
    await db.rawDelete(
      'DELETE FROM poll_votes WHERE at < ? AND poll_uid NOT IN '
      '(SELECT msg_uid FROM messages WHERE msg_uid IS NOT NULL '
      'AND poll IS NOT NULL)',
      [cut],
    );
    await db.delete('polls_gone', where: 'at < ?', whereArgs: [cut]);
  }

  // did this sender write this row. what edit and unsend frames check.
  Future<bool> isTheirs(String msgUid, String sender) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['id'],
      where: "msg_uid = ? AND direction = 'in' AND peer_id = ?",
      whereArgs: [msgUid, sender],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<void> editMessage(String msgUid, String newText) async {
    final db = await open();
    // a page title belongs to the link it was fetched for
    final was = await db.query(
      'messages',
      columns: ['plaintext'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    final linkMoved =
        was.isNotEmpty &&
        firstUrl(was.first['plaintext'] as String? ?? '') !=
            firstUrl(unmarked(newText));
    await db.update(
      'messages',
      {
        'plaintext': unmarked(newText),
        'edited': 1,
        if (linkMoved) 'preview': null,
      },
      // a sticker has no words to edit: its text stays its emoji
      where: 'msg_uid = ? AND sticker IS NULL',
      whereArgs: [msgUid],
    );
    // an opener that goes again goes as it reads now
    await db.update(
      'opener_again',
      {'wire': null},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    // the old words must not find it any more
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    for (final r in rows) {
      await indexSearchRow(db, r['id'] as int, r);
    }
  }

  // ---- search ----

  /// one batch of the first fill, oldest first. how far it got, of how
  /// many; done when [at] reaches [to].
  Future<({int at, int to})> fillSearchIndex({int batch = 300}) async {
    final db = await open();
    int meta(List<Map<String, Object?>> r) =>
        r.isEmpty ? 0 : (r.first['v'] as num).toInt();
    final to = meta(
      await db.query('search_meta', where: "k = 'fill_to'", limit: 1),
    );
    var at = meta(
      await db.query('search_meta', where: "k = 'fill_at'", limit: 1),
    );
    if (at >= to) return (at: at, to: to);
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'id > ? AND id <= ?',
      whereArgs: [at, to],
      orderBy: 'id ASC',
      limit: batch,
    );
    at = rows.isEmpty ? to : rows.last['id'] as int;
    final b = db.batch();
    for (final r in rows) {
      indexSearchRowIn(b, r['id'] as int, r);
    }
    b.update('search_meta', {'v': at}, where: "k = 'fill_at'");
    await b.commit(noResult: true);
    return (at: at, to: to);
  }

  /// messages that match [match] (a full-text match, or null for every
  /// message) and [kind], newest first. never a blocked contact's, never a
  /// stranger's who has not been accepted.
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async {
    final rows = await runSearchQuery(await open(), match, kind, limit: limit);
    // the newest that came, shown in the chats' order
    return [...rows]..sort(
      (a, b) => byWritten(
        rowWrittenAt(b),
        (b['id'] as num?)?.toInt() ?? 0,
        rowWrittenAt(a),
        (a['id'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  // what is here of [sender]'s album [albumId]: its count, the places
  // taken, when its first row was written and when its first row came.
  // null while none is
  Future<({int n, Set<int> taken, int first, int came})?> albumHeld(
    String albumId,
    String sender,
    String? groupId,
  ) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['album_n', 'album_i', 'written_at', 'sent_at'],
      where:
          "album_id = ? AND peer_id = ? AND IFNULL(group_id, '') = ? "
          "AND direction = 'in'",
      whereArgs: [albumId, sender, groupId ?? ''],
    );
    if (rows.isEmpty) return null;
    var first = rowWrittenAt(rows.first);
    var came = (rows.first['sent_at'] as num).toInt();
    for (final r in rows) {
      first = min(first, rowWrittenAt(r));
      came = min(came, (r['sent_at'] as num).toInt());
    }
    return (
      n: (rows.first['album_n'] as num?)?.toInt() ?? 0,
      taken: {for (final r in rows) (r['album_i'] as num?)?.toInt() ?? -1},
      first: first,
      came: came,
    );
  }

  Future<bool> messageExists(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['rowid AS rowid'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // an item of an album takes the earliest clock any of the album has, so
  // all of it burns together. gives the clock it took
  Future<int> setMsgBurnAt(String msgUid, int burnAt) async {
    final db = await open();
    return db.transaction((t) async {
      final at = albumItemBurnAt(
        burnAt,
        await _albumClocks(t, msgUid),
        DateTime.now().millisecondsSinceEpoch,
      );
      await t.update(
        'messages',
        {'burn_at': at},
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
      );
      return at;
    });
  }

  // the album [msgUid] is in, as (album, peer, group, direction), or null
  static Future<(String, String, String, String)?> _albumOf(
    DatabaseExecutor t,
    String msgUid,
  ) async {
    final r = await t.query(
      'messages',
      columns: ['album_id', 'peer_id', 'group_id', 'direction'],
      where: 'msg_uid = ? AND album_id IS NOT NULL',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (
      r.first['album_id'] as String,
      r.first['peer_id'] as String,
      (r.first['group_id'] as String?) ?? '',
      r.first['direction'] as String,
    );
  }

  static const _albumMates =
      "album_id = ? AND peer_id = ? AND IFNULL(group_id, '') = ? "
      'AND direction = ? AND msg_uid IS NOT NULL AND msg_uid != ?';

  // the clocks running on the other items of [msgUid]'s album
  static Future<List<int?>> _albumClocks(
    DatabaseExecutor t,
    String msgUid,
  ) async {
    final a = await _albumOf(t, msgUid);
    if (a == null) return const [];
    final (album, peer, group, dir) = a;
    final rows = await t.query(
      'messages',
      columns: ['burn_at'],
      where: '$_albumMates AND burn_at IS NOT NULL AND burn_unseen = 0',
      whereArgs: [album, peer, group, dir, msgUid],
    );
    return [for (final r in rows) (r['burn_at'] as num?)?.toInt()];
  }

  // add or replace a reaction. reactor is '' for self, peer's kryfo id
  // for theirs. one reaction per (msgUid, reactor): re-reacting replaces.
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    final db = await open();
    await db.insert('reactions', {
      'msg_uid': msgUid,
      'reactor': reactor,
      'emoji': emoji,
      'reacted_at': at ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReaction(String msgUid, String reactor) async {
    final db = await open();
    await db.delete(
      'reactions',
      where: 'msg_uid = ? AND reactor = ?',
      whereArgs: [msgUid, reactor],
    );
  }

  // load reactions for a batch of messages. returns
  // { msgUid: [ (reactor, emoji), ... ] }.
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async {
    if (msgUids.isEmpty) return {};
    final db = await open();
    final placeholders = List.filled(msgUids.length, '?').join(',');
    final rows = await db.query(
      'reactions',
      columns: ['msg_uid', 'reactor', 'emoji'],
      where: 'msg_uid IN ($placeholders)',
      whereArgs: msgUids,
    );
    final out = <String, List<MapEntry<String, String>>>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final reactor = r['reactor'] as String;
      final emoji = r['emoji'] as String;
      out.putIfAbsent(uid, () => []).add(MapEntry(reactor, emoji));
    }
    return out;
  }

  // delete messages whose burn_at is past, and what waited unread past a
  // day and its window. called by the periodic sweep started in boot().
  // [gone] hears each one that came in. [blocked] gives everyone blocked
  // on this side, the open vault's list with the everyday one's, so a
  // block made in one starts the other's clocks; this container's own
  // list when null. [ifOpen]: one shut is left shut, and 0
  Future<int> purgeExpired({
    void Function(String msgUid)? gone,
    Future<Set<String>> Function()? blocked,
    bool ifOpen = false,
  }) async {
    // an open one is handed back at once, and nothing below opens it again
    final db = ifOpen && !isOpen ? null : await open();
    if (db == null) return 0;
    await _lightStrandedOnce(db);
    final cut = DateTime.now().millisecondsSinceEpoch;
    final due = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kBurnDue,
      whereArgs: [cut],
    );
    final idle = await _idle(db, [
      ..._kFileCols,
      ..._kUnreadCols,
      ..._kGoneCols,
    ]);
    // after what waits is read: nothing in it was filed past this now
    final now = DateTime.now().millisecondsSinceEpoch;
    final waited = [
      for (final r in idle)
        if (_waitedOut(r, now)) r,
    ];
    final media = [...due, ...waited];
    await _unreadGo(db, media);
    await _noteGone(db, media, burned: true);
    await db.delete(
      'gone_in',
      where: 'at < ?',
      whereArgs: [now - kGoneFor.inMilliseconds],
    );
    if (gone != null) {
      for (final r in media) {
        final uid = r['msg_uid'] as String?;
        if (uid != null && r['direction'] == 'in') gone(uid);
      }
    }
    var n = await db.delete('messages', where: _kBurnDue, whereArgs: [cut]);
    n += await _dropRows(db, waited);
    await _scrubMedia(media);
    await _lightWaited(db, now, idle, blocked);
    return n;
  }

  Future<bool> isSent(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return false;
    return (r.first['sent'] as int? ?? 0) == 1;
  }

  // every outgoing row the wire never accepted, oldest first. the drainer
  // walks this on a timer so a send survives tor warmup, backing out of the
  // chat, and a cold restart. keyed on `sent`, not `delivered`: retrying on
  // a missing ack loops forever when the ack never comes.
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'messages',
      // group text stays out: a group send marks sent on the first ack, so
      // a row still at 0 is one nobody could take, and the screen owns its
      // retry. group media comes along, it has the same chunked path as 1:1.
      where:
          "direction = 'out' AND sent = 0 AND msg_uid IS NOT NULL "
          "AND (group_id IS NULL OR group_id = '' "
          "OR media_path IS NOT NULL OR file_path IS NOT NULL) "
          'AND $kNotBlocked${_notIn(s)}',
      whereArgs: s.isEmpty ? null : s,
      orderBy: 'sent_at ASC',
      limit: 40,
    );
  }

  // rows for these peers stay out of a queue's window
  static String _notIn(List<String> s) => s.isEmpty
      ? ''
      : ' AND peer_id NOT IN (${List.filled(s.length, '?').join(', ')})';

  // every contact held here: verified under one key, holding another now
  Future<Set<String>> heldPeers() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'verified_key IS NOT NULL',
    );
    return {
      for (final r in rows)
        if (await keyHeldIn(db, r['halo_id'] as String, identity: _keySource))
          r['halo_id'] as String,
    };
  }

  // ---- chunked media ----
  // buffered on disk so a restart doesn't lose a transfer

  // store one slice from [from], return how many of this media's slices we
  // now hold. [group] is the group the file is posted in
  Future<int> putMediaChunk(
    String mediaId,
    int idx,
    String slice,
    int total,
    int? burn, {
    required String from,
    String? group,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    // a file sent again in another number of slices is other bytes, a photo
    // cleaned since say: what was held of it no longer fits
    final stale = await db.delete(
      'media_chunks',
      where: 'media_id = ? AND total != ?',
      whereArgs: [mediaId, total],
    );
    if (stale > 0 && _unfinished != null) await _reweigh(mediaId);
    // a slice sent again replaces the one held, and weighs only once
    final held = _unfinished;
    final was = held == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'media_chunks',
            columns: ['length(slice) AS n'],
            where: 'media_id = ? AND idx = ?',
            whereArgs: [mediaId, idx],
            limit: 1,
          );
    await db.rawInsert(
      'INSERT OR REPLACE INTO media_chunks '
      '(media_id, idx, slice, total, burn, at, sender, group_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [mediaId, idx, slice, total, burn, now, from, group],
    );
    if (held != null && identical(held, _unfinished)) {
      final old = was.isEmpty
          ? 0
          : sliceWeight((was.first['n'] as num? ?? 0).toInt());
      final f = held[mediaId];
      held[mediaId] = (
        bytes: (f?.bytes ?? 0) + sliceWeight(slice.length) - old,
        at: now,
      );
    }
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM media_chunks WHERE media_id = ?',
      [mediaId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // burn window rides the slices so it survives a restart too.
  Future<int?> mediaChunkBurn(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['burn'],
      where: 'media_id = ? AND burn IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return r.first['burn'] as int?;
  }

  // one slice, so a file is rebuilt piece by piece instead of all its
  // slices sitting in one list
  Future<String?> mediaChunkSlice(String mediaId, int idx) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['slice'],
      where: 'media_id = ? AND idx = ?',
      whereArgs: [mediaId, idx],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['slice'] as String?;
  }

  // a file's slices, or with [from] only the ones that sender sent
  Future<int> dropMediaChunks(String mediaId, {String? from}) async {
    final db = await open();
    final n = await db.delete(
      'media_chunks',
      where: from == null ? 'media_id = ?' : 'media_id = ? AND sender = ?',
      whereArgs: [mediaId, ?from],
    );
    if (n > 0 && _unfinished != null) await _reweigh(mediaId);
    return n;
  }

  // the unfinished files here, each with what its slices weigh and when its
  // last slice came. read whole the first time it is needed, then kept up
  // as slices come and go
  Map<String, ({int bytes, int at})>? _unfinished;

  Future<Map<String, ({int bytes, int at})>> _unfinishedFiles() async {
    final have = _unfinished;
    if (have != null) return have;
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['media_id', 'length(slice) AS n', 'at'],
    );
    final out = <String, ({int bytes, int at})>{};
    for (final r in rows) {
      final id = r['media_id'] as String;
      final at = (r['at'] as num).toInt();
      final f = out[id];
      out[id] = (
        bytes: (f?.bytes ?? 0) + sliceWeight((r['n'] as num? ?? 0).toInt()),
        at: f == null || at > f.at ? at : f.at,
      );
    }
    return _unfinished = out;
  }

  // one file's entry read again from what is left of it
  Future<void> _reweigh(String mediaId) async {
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['length(slice) AS n', 'at'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    final held = _unfinished;
    if (held == null) return;
    if (rows.isEmpty) {
      held.remove(mediaId);
      return;
    }
    var bytes = 0;
    var at = 0;
    for (final r in rows) {
      bytes += sliceWeight((r['n'] as num? ?? 0).toInt());
      final t = (r['at'] as num).toInt();
      if (t > at) at = t;
    }
    held[mediaId] = (bytes: bytes, at: at);
  }

  // unfinished files past the cap go, whole, the one whose last slice came
  // longest ago first. a file in [keep] is being put together and stays;
  // finished messages are never touched. the files that went
  Future<Set<String>> trimUnfinishedMedia({
    Set<String> keep = const {},
    int bytes = kUnfinishedBytes,
    int files = kUnfinishedFiles,
  }) async {
    final held = await _unfinishedFiles();
    final drop = unfinishedPastCap(
      held,
      bytes: bytes,
      files: files,
      keep: keep,
    );
    if (drop.isEmpty) return const <String>{};
    final db = await open();
    final gone = <String>{};
    for (final id in drop) {
      // one that began to be put together meanwhile stays
      if (keep.contains(id)) continue;
      await db.delete('media_chunks', where: 'media_id = ?', whereArgs: [id]);
      await dropMediaWant(id);
      _unfinished?.remove(id);
      gone.add(id);
    }
    dlog('unfinished files past the cap: ${gone.length} dropped');
    return gone;
  }

  // who sent the slices held for a file, null for none or for slices kept
  // before senders were noted
  Future<String?> mediaChunkSender(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['sender'],
      where: 'media_id = ? AND sender IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['sender'] as String?;
  }

  // how many unfinished files [from] is sending in their own chat, [except]
  // not counted. only those have a want row: a file they post in a group
  // counts for the group, not against their chat
  Future<int> filesInFlightFrom(String from, {String? except}) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id'],
      where: 'sender = ?',
      whereArgs: [from],
    );
    final direct = {
      for (final w in await db.query(
        'media_wants',
        columns: ['media_id'],
        where: 'peer_id = ?',
        whereArgs: [from],
      ))
        w['media_id'],
    };
    return r
        .where((x) => x['media_id'] != except && direct.contains(x['media_id']))
        .length;
  }

  // a slice of an unfinished file just came in. can_resend only ever goes
  // up: one slice from a sender that can answer is enough to know it can.
  // the count of slices is the latest one's, as with the slices held
  Future<void> noteMediaWant(
    String mediaId,
    String peerId,
    int total,
    bool canResend,
  ) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      'INSERT INTO media_wants (media_id, peer_id, total, can_resend, last_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(media_id) DO UPDATE SET last_at = excluded.last_at, '
      'total = excluded.total, '
      'can_resend = MAX(can_resend, excluded.can_resend)',
      [mediaId, peerId, total, canResend ? 1 : 0, now],
    );
  }

  Future<List<Map<String, Object?>>> mediaWants() async {
    final db = await open();
    return db.query('media_wants', where: 'can_resend = 1');
  }

  Future<Set<int>> heldSlices(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['idx'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return {for (final row in r) (row['idx'] as num).toInt()};
  }

  // [at] is the time the ask was decided on, stamped before it goes. read
  // and written in one go, so a slice landing meanwhile is not missed
  Future<void> markMediaAsked(String mediaId, int at) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'media_wants',
        columns: ['last_at', 'asked_at', 'asks'],
        where: 'media_id = ?',
        whereArgs: [mediaId],
        limit: 1,
      );
      if (r.isEmpty) return;
      final w = r.first;
      await t.update(
        'media_wants',
        {
          'asked_at': at,
          'asks': asksAfterAsk(
            lastSliceAt: (w['last_at'] as num).toInt(),
            askedAt: (w['asked_at'] as num).toInt(),
            asks: (w['asks'] as num).toInt(),
          ),
        },
        where: 'media_id = ?',
        whereArgs: [mediaId],
      );
    });
  }

  // a chat put away takes the files still coming in it: their slices, and
  // the asks for the rest that would tell its person to send them again
  Future<void> _dropFilesComingFrom(DatabaseExecutor t, String peerId) async {
    await t.rawDelete(
      'DELETE FROM media_chunks WHERE media_id IN '
      '(SELECT media_id FROM media_wants WHERE peer_id = ?)',
      [peerId],
    );
    await t.delete('media_wants', where: 'peer_id = ?', whereArgs: [peerId]);
    // weighed again from what is left
    _unfinished = null;
    // nothing more comes for them, so the banner would stay paused for a day
    incomingMediaDone(container.chatKey(peerId));
  }

  // a group gone or cleared takes the files still coming in it. slices
  // kept before the group was noted on them go too where they can be told:
  // left by a message of the group, or sent by a room's member keys, which
  // are the room's own. run before the group's messages go
  Future<void> _dropGroupFiles(
    DatabaseExecutor t,
    String groupId, {
    Iterable<String> keys = const [],
  }) async {
    var n = await t.delete(
      'media_chunks',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final uids = [
      for (final r in await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'group_id = ? AND msg_uid IS NOT NULL',
        whereArgs: [groupId],
      ))
        r['msg_uid'] as String,
    ];
    for (final (col, ids) in [
      ('media_id', uids),
      ('sender', keys.toSet().toList()),
    ]) {
      for (var i = 0; i < ids.length; i += 400) {
        final part = ids.sublist(i, min(i + 400, ids.length));
        n += await t.delete(
          'media_chunks',
          where:
              'group_id IS NULL AND '
              '$col IN (${List.filled(part.length, '?').join(', ')})',
          whereArgs: part,
        );
      }
    }
    if (n == 0) return;
    // weighed again from what is left
    _unfinished = null;
    incomingMediaDone(container.chatKey(groupId));
  }

  Future<void> dropMediaWant(String mediaId) async {
    final db = await open();
    await db.delete('media_wants', where: 'media_id = ?', whereArgs: [mediaId]);
  }

  // ---- group messages and files some members still lack ----

  /// a send of [msgUid] to [tried] ended with [short] still lacking slices.
  /// the rest of [tried] have it all and are owed nothing. a short member
  /// keeps its row with what it holds; [first] sends add the ones new to
  /// it, waiting from [now]. a row gone meanwhile leaves nothing owed
  Future<void> settleGroupOwed(
    String msgUid,
    String groupId, {
    required int total,
    required Iterable<String> tried,
    required Map<String, Set<int>> short,
    required int sentTo,
    required bool first,
    required int now,
  }) async {
    final db = await open();
    await db.transaction((t) async {
      final row = await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
        limit: 1,
      );
      if (row.isEmpty) {
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [msgUid],
        );
        return;
      }
      for (final m in tried) {
        if (short.containsKey(m)) continue;
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
      for (final MapEntry(key: m, value: have) in short.entries) {
        final n = await t.update(
          'group_media_owed',
          {'have': packSlices(have), 'total': total},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
        if (n > 0 || !first) continue;
        await t.insert('group_media_owed', {
          'msg_uid': msgUid,
          'group_id': groupId,
          'member': m,
          'total': total,
          'have': packSlices(have),
          'sent_to': sentTo,
          'since': now,
          'tries': 0,
          'next_at': now + groupOwedGap(0),
        });
      }
    });
  }

  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async {
    final db = await open();
    // a member past its tries is not tried again, and keeps its row
    final rows = await db.query(
      'group_media_owed',
      where: 'next_at < ? AND tries < ?',
      whereArgs: [now + 1, kGroupOwedTries],
      orderBy: 'next_at ASC',
    );
    return [for (final r in rows) GroupOwed.fromRow(r)];
  }

  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        final r = await t.query(
          'group_media_owed',
          columns: ['tries'],
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
          limit: 1,
        );
        if (r.isEmpty) continue;
        final tries = (r.first['tries'] as int? ?? 0) + 1;
        await t.update(
          'group_media_owed',
          {'tries': tries, 'next_at': now + groupOwedGap(tries)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
    });
  }

  @override
  Future<void> dropGroupOwed(String msgUid) async {
    final db = await open();
    await db.delete(
      'group_media_owed',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  /// the members of [groupId] no longer in [members] are owed nothing
  Future<void> keepGroupOwedTo(String groupId, List<String> members) async {
    final db = await open();
    await db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['member'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final m in {for (final r in rows) r['member'] as String}) {
        if (members.contains(m)) continue;
        await _owedGone(t, 'group_id = ? AND member = ?', [groupId, m]);
      }
    });
  }

  /// [member]'s session is there now: what they are owed is due at once,
  /// with a try more for one past its tries
  Future<int> groupOwedDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['msg_uid', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_media_owed',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [r['msg_uid'], member],
        );
      }
      return rows.length;
    });
  }

  // a restore's mark outlives any window it could still stop
  static const _kResentKeep = Duration(days: 16);
  // one restore per member a day: each ask names its own date
  static const _kResentEvery = Duration(days: 1);

  /// our group texts since [from], owed again to [member] as texts they
  /// missed are: in each group here they are in, only what went since they
  /// joined, never one that burned. once per [restore] and group, and one
  /// [restore] per member a day. one owed already is left as it is. a
  /// room's members are keys of its own, never a restored phone. how many
  Future<int> oweGroupTextsAfterRestore(
    String member, {
    required String me,
    required int from,
    required int restore,
    required int now,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      await t.delete(
        'group_resent',
        where: 'at < ?',
        whereArgs: [now - _kResentKeep.inMilliseconds],
      );
      // another restore of theirs marked within the day: not this one too
      for (final r in await t.query(
        'group_resent',
        columns: ['since', 'at'],
        where: 'member = ?',
        whereArgs: [member],
      )) {
        final at = (r['at'] as num).toInt();
        if (r['since'] != restore && now - at < _kResentEvery.inMilliseconds) {
          return 0;
        }
      }
      var n = 0;
      for (final m in await t.query(
        'group_members',
        columns: ['group_id', 'joined_at'],
        where: 'halo_id = ?',
        whereArgs: [member],
      )) {
        final g = m['group_id'] as String;
        final group = await t.query(
          'groups',
          columns: ['room_pub'],
          where: 'group_id = ?',
          whereArgs: [g],
          limit: 1,
        );
        if (group.isEmpty || group.first['room_pub'] != null) continue;
        final marked = await t.query(
          'group_resent',
          columns: ['at'],
          where: 'group_id = ? AND member = ? AND since = ?',
          whereArgs: [g, member, restore],
          limit: 1,
        );
        if (marked.isNotEmpty) continue;
        await t.insert('group_resent', {
          'group_id': g,
          'member': member,
          'since': restore,
          'at': now,
        });
        final start = max(from, (m['joined_at'] as num?)?.toInt() ?? now);
        final others = [
          for (final r in await t.query(
            'group_members',
            columns: ['halo_id'],
            where: 'group_id = ?',
            whereArgs: [g],
          ))
            if (r['halo_id'] != me) r,
        ].length;
        // kNotSent is a block's: those wait for a tap
        for (final r in await t.query(
          'messages',
          columns: ['msg_uid', 'sent_at', 'burn_at'],
          where:
              'group_id = ? AND direction = ? AND sent = ? AND msg_uid IS NOT '
              'NULL AND media_path IS NULL AND file_path IS NULL '
              'AND sent_at >= ?',
          whereArgs: [g, 'out', 1, start],
        )) {
          final at = (r['sent_at'] as num?)?.toInt() ?? 0;
          final burn = (r['burn_at'] as num?)?.toInt();
          if (at < start || (burn != null && burn <= now)) continue;
          final uid = r['msg_uid'] as String;
          // one owed already keeps its own tries
          final had = await t.query(
            'group_media_owed',
            columns: ['tries'],
            where: 'msg_uid = ? AND member = ?',
            whereArgs: [uid, member],
            limit: 1,
          );
          if (had.isNotEmpty) continue;
          await t.insert('group_media_owed', {
            'msg_uid': uid,
            'group_id': g,
            'member': member,
            'total': 1,
            'have': '',
            'sent_to': max(others, 1),
            'since': now,
            'tries': 0,
            'next_at': now,
          });
          n++;
        }
      }
      return n;
    });
  }

  /// a group's messages some members still lack, by uid: how many of the
  /// members each went to have it, and how many of the rest are past their
  /// tries
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async {
    final db = await open();
    final rows = await db.query(
      'group_media_owed',
      columns: ['msg_uid', 'sent_to', 'tries'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final owed = <String, int>{};
    final of = <String, int>{};
    final gaveUp = <String, int>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      owed[uid] = (owed[uid] ?? 0) + 1;
      of[uid] = max(of[uid] ?? 0, r['sent_to'] as int? ?? 0);
      if ((r['tries'] as int? ?? 0) >= kGroupOwedTries) {
        gaveUp[uid] = (gaveUp[uid] ?? 0) + 1;
      }
    }
    return {
      for (final MapEntry(key: uid, value: n) in owed.entries)
        uid: (
          have: max(0, of[uid]! - n),
          of: max(of[uid]!, n),
          gaveUp: gaveUp[uid] ?? 0,
        ),
    };
  }

  // members who left or were taken out: their rows go, and each file they
  // were owed counts one fewer it went to, so the others' line stays true
  static Future<void> _owedGone(
    DatabaseExecutor t,
    String where,
    List<Object?> args,
  ) async {
    final rows = await t.query(
      'group_media_owed',
      columns: ['msg_uid', 'member', 'sent_to'],
      where: where,
      whereArgs: args,
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final to = r['sent_to'] as int? ?? 1;
      await t.delete(
        'group_media_owed',
        where: 'msg_uid = ? AND member = ?',
        whereArgs: [uid, r['member']],
      );
      await t.update(
        'group_media_owed',
        {'sent_to': to > 1 ? to - 1 : 1},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
    }
  }

  // ---- group controls on their way to each member ----

  /// [ctl] for each of [members], after what each is still to get of
  /// [groupId]. due at once
  Future<void> queueGroupCtl(
    String groupId,
    Iterable<String> members,
    GroupControl ctl, {
    required int now,
  }) async {
    final body = jsonEncode(ctl.toWire());
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// a frame sealed for all of [members], each to get it in their lane
  Future<void> queueGroupWrapped(
    String groupId,
    Iterable<String> members,
    String wrapped, {
    required int now,
  }) async {
    final body = jsonEncode(groupWrappedRow(wrapped));
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// the take-back of [uid] for each of [members], in the same lanes as the
  /// controls. a member it already waits for gets no second one
  Future<void> queueGroupUnsend(
    String groupId,
    Iterable<String> members,
    String uid, {
    required int now,
  }) async {
    final body = jsonEncode(groupUnsendRow(uid));
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        // taken back, its edit or reaction has nothing left to change
        await _dropGroupFrames(t, groupId, m, uid);
        final held = await t.query(
          'group_ctl_out',
          columns: ['id'],
          where: 'group_id = ? AND member = ? AND ctl = ?',
          whereArgs: [groupId, m, body],
          limit: 1,
        );
        if (held.isNotEmpty) continue;
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// a group edit or reaction ([groupEditRow], [groupReactRow]) for each
  /// of [members]. one of the same kind for the same message still waiting
  /// for a member goes: only the newest word is sent
  Future<void> queueGroupFrame(
    String groupId,
    Iterable<String> members,
    Map<String, String> row, {
    required int now,
  }) async {
    final body = jsonEncode(row);
    final f = groupFrameOf(body);
    if (f == null) return;
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await _dropGroupFrames(t, groupId, m, f.uid, edits: f.edit != null);
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  // [member]'s queued edits ([edits]) or reactions of [uid], or both when
  // null
  static Future<void> _dropGroupFrames(
    DatabaseExecutor t,
    String groupId,
    String member,
    String uid, {
    bool? edits,
  }) async {
    for (final r in await t.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, member],
    )) {
      final o = groupFrameOf(r['ctl']);
      if (o == null || o.uid != uid) continue;
      if (edits != null && (o.edit != null) != edits) continue;
      await t.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
  }

  /// every control still to go, oldest first
  Future<List<Map<String, Object?>>> groupCtlOut() async {
    final db = await open();
    return db.query('group_ctl_out', orderBy: 'id ASC');
  }

  /// what [member] is still to get of [groupId], oldest first
  Future<List<Map<String, Object?>>> groupCtlFor(
    String groupId,
    String member,
  ) async {
    final db = await open();
    return db.query(
      'group_ctl_out',
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, member],
      orderBy: 'id ASC',
    );
  }

  /// a try of [id] is starting: its count goes up and the next wait is set
  Future<void> triedGroupCtl(int id, int now) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'group_ctl_out',
        columns: ['tries'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (r.isEmpty) return;
      final tries = (r.first['tries'] as int? ?? 0) + 1;
      await t.update(
        'group_ctl_out',
        {'tries': tries, 'next_at': now + groupOwedGap(tries)},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> dropGroupCtl(int id) async {
    final db = await open();
    await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [id]);
  }

  /// the members still to get a control of [groupId]
  Future<Set<String>> groupCtlWaiting(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_ctl_out',
      columns: ['member'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return {for (final r in rows) r['member'] as String};
  }

  /// [member]'s session is there now: what it is still to get is due at
  /// once, with a try more for one past its tries
  Future<int> groupCtlDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_ctl_out',
        columns: ['id', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_ctl_out',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
      return rows.length;
    });
  }

  // ---- the newest roster each group took ----

  /// the stamp for a roster this phone makes of [groupId]: above the last
  /// one, and the clock when that is higher
  Future<int> nextRosterStamp(String groupId, int now) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final stamp = max(now, ((held?['stamp'] as int?) ?? 0) + 1);
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return stamp;
    });
  }

  /// keeps [stamp] when it is newer than the last roster [groupId] took.
  /// false for an older one, or the same one again
  Future<bool> takeRosterStamp(String groupId, int stamp) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      if (stamp <= ((held?['stamp'] as int?) ?? 0)) return false;
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return true;
    });
  }

  /// the number for the next frame this phone sends into room [groupId]:
  /// one up from the last, from one. none for a room no longer here: its
  /// roster row would outlive it
  Future<int> nextRoomSeq(String groupId) async {
    final db = await open();
    return db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) throw StateError('no room $groupId here');
      final held = await _rosterRow(t, groupId);
      final seq = ((held?['seq'] as int?) ?? 0) + 1;
      await _putRoster(t, groupId, seq: seq, had: held != null);
      return seq;
    });
  }

  /// the room keys that left [groupId] or were taken out
  Future<Set<String>> rosterGone(String groupId) async {
    final db = await open();
    final held = await _rosterRow(db, groupId);
    return {
      for (final k in ((held?['gone'] as String?) ?? '').split(','))
        if (k.isNotEmpty) k,
    };
  }

  Future<void> noteRosterGone(String groupId, Iterable<String> keys) async {
    final db = await open();
    await db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final gone = {
        for (final k in ((held?['gone'] as String?) ?? '').split(','))
          if (k.isNotEmpty) k,
        for (final k in keys)
          if (k.isNotEmpty && !k.contains(',')) k,
      };
      await _putRoster(t, groupId, gone: gone.join(','), had: held != null);
    });
  }

  /// every member key room [groupId] ever listened to, for its end
  Future<Set<String>> roomKeysOf(String groupId) async {
    final db = await open();
    return {
      for (final r in await db.query(
        'room_keys',
        columns: ['member'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      ))
        r['member'] as String,
    };
  }

  /// room [groupId] listens to [keys] from now on. false for a room no
  /// longer here, which listens to nothing
  Future<bool> noteRoomKeys(String groupId, Iterable<String> keys) =>
      _inRoom(groupId, (t) async {
        for (final k in keys) {
          await t.insert('room_keys', {
            'group_id': groupId,
            'member': k,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });

  /// a message of [key]'s taken in room [groupId], as [roomEntry] names
  /// it: the last [kRoomRecent] are what a remove of [key] lets the others
  /// still take
  Future<void> noteRoomEntry(String groupId, String key, String h) =>
      _inRoom(groupId, (t) async {
        final had = await _roomKey(t, groupId, key);
        final recent = [
          for (final x in _hashes(had?['recent']))
            if (x != h) x,
          h,
        ];
        final keep = recent.length > kRoomRecent
            ? recent.sublist(recent.length - kRoomRecent)
            : recent;
        await _putRoomKey(t, groupId, key, {
          'recent': keep.join(','),
        }, had: had != null);
      });

  /// [key]'s last messages taken in room [groupId] as [roomEntry] names
  /// them, oldest first
  Future<List<String>> roomRecent(String groupId, String key) async {
    final db = await open();
    return _hashes((await _roomKey(db, groupId, key))?['recent']);
  }

  /// [key] is out of room [groupId]. of [listed], its messages the admin
  /// took before that, the ones not taken here are owed: only they still
  /// come in. a second remove keeps what both list
  Future<Set<String>> noteRoomKeyOut(
    String groupId,
    String key, {
    Iterable<String> listed = const [],
  }) async {
    Set<String> owed = const {};
    await _inRoom(groupId, (t) async {
      final had = await _roomKey(t, groupId, key);
      final here = _hashes(had?['recent']).toSet();
      final was = (had?['out'] as int? ?? 0) == 0
          ? null
          : _hashes(had?['owed']).toSet();
      owed = {
        for (final h in listed)
          if (!here.contains(h) && (was == null || was.contains(h))) h,
      };
      await _putRoomKey(t, groupId, key, {
        'owed': owed.join(','),
        // a lane stopped already stays stopped
        if ((had?['out'] as int? ?? 0) != 2) 'out': 1,
      }, had: had != null);
    });
    return owed;
  }

  /// whether the message [entry] names ([roomEntry]) from [key], out of
  /// room [groupId], is one still owed from before it went
  Future<bool> roomOwes(String groupId, String key, String entry) async {
    final db = await open();
    final had = await _roomKey(db, groupId, key);
    return _hashes(had?['owed']).contains(entry);
  }

  /// whether a message by [uid] from [key] may be owed, its words or bytes
  /// not read yet: a file's slices, held until the file is whole
  Future<bool> roomOwesUid(String groupId, String key, String uid) async {
    final db = await open();
    final had = await _roomKey(db, groupId, key);
    final part = roomUidPart(groupId, uid);
    return _hashes(had?['owed']).any((h) => h.startsWith(part));
  }

  /// [uid] from [key] is in: how many of its owed are left
  Future<int> roomOwedIn(String groupId, String key, String uid) async {
    var left = 0;
    await _inRoom(groupId, (t) async {
      final had = await _roomKey(t, groupId, key);
      if (had == null) return;
      final part = roomUidPart(groupId, uid);
      final owed = [
        for (final x in _hashes(had['owed']))
          if (!x.startsWith(part)) x,
      ];
      left = owed.length;
      await _putRoomKey(t, groupId, key, {'owed': owed.join(',')}, had: true);
    });
    return left;
  }

  /// the keys out of room [groupId] whose lane is still to stop
  Future<Set<String>> roomKeysGoing(String groupId) async {
    final db = await open();
    return {
      for (final r in await db.query(
        'room_keys',
        columns: ['member'],
        where: 'group_id = ? AND out = ?',
        whereArgs: [groupId, 1],
      ))
        r['member'] as String,
    };
  }

  /// [key]'s lane in room [groupId] stopped and its files gone: nothing
  /// more of it comes in
  Future<void> roomKeyStopped(String groupId, String key) =>
      _inRoom(groupId, (t) async {
        final had = await _roomKey(t, groupId, key);
        await _putRoomKey(t, groupId, key, {
          'owed': '',
          'out': 2,
        }, had: had != null);
      });

  // [run] in one go with room [groupId] still here. false when it is not:
  // a row of a room gone would outlive it
  Future<bool> _inRoom(
    String groupId,
    Future<void> Function(Transaction t) run,
  ) async {
    final db = await open();
    return db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) return false;
      await run(t);
      return true;
    });
  }

  static List<String> _hashes(Object? text) => [
    for (final h in ((text as String?) ?? '').split(','))
      if (h.isNotEmpty) h,
  ];

  static Future<Map<String, Object?>?> _roomKey(
    DatabaseExecutor t,
    String groupId,
    String key,
  ) async {
    final r = await t.query(
      'room_keys',
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, key],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  static Future<void> _putRoomKey(
    DatabaseExecutor t,
    String groupId,
    String key,
    Map<String, Object?> cols, {
    required bool had,
  }) async {
    if (had) {
      await t.update(
        'room_keys',
        cols,
        where: 'group_id = ? AND member = ?',
        whereArgs: [groupId, key],
      );
    } else {
      await t.insert('room_keys', {
        'group_id': groupId,
        'member': key,
        ...cols,
      });
    }
  }

  static Future<Map<String, Object?>?> _rosterRow(
    DatabaseExecutor t,
    String groupId,
  ) async {
    final r = await t.query(
      'group_roster',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  static Future<void> _putRoster(
    DatabaseExecutor t,
    String groupId, {
    int? stamp,
    String? gone,
    int? seq,
    required bool had,
  }) async {
    final cols = {'stamp': ?stamp, 'gone': ?gone, 'seq': ?seq};
    if (had) {
      await t.update(
        'group_roster',
        cols,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } else {
      await t.insert('group_roster', {'group_id': groupId, ...cols});
    }
  }

  // what a request for slices is checked against and answered from
  Future<Map<String, Object?>?> sentMediaRow(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  // a transfer nobody ever finished shouldn't sit in the db forever.
  // a week for a file from someone here, a day for one from a stranger:
  // someone not accepted and in no group
  Future<void> sweepMediaChunks({DateTime? now}) async {
    final db = await open();
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final cutoff = at - const Duration(days: 7).inMilliseconds;
    final strangers = at - const Duration(days: 1).inMilliseconds;
    var n = await db.delete(
      'media_chunks',
      where: 'at < ?',
      whereArgs: [cutoff],
    );
    final old = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id', 'sender'],
      where: 'at < ? AND sender IS NOT NULL',
      whereArgs: [strangers],
    );
    final known = <String, bool>{};
    for (final r in old) {
      final mid = r['media_id'] as String;
      final from = r['sender'] as String;
      if (known[from] ??= await _heldHere(from)) continue;
      n += await dropMediaChunks(mid, from: from);
      await dropMediaWant(mid);
    }
    if (n > 0) dlog('swept $n stale media chunks');
    await db.delete('media_wants', where: 'last_at < ?', whereArgs: [cutoff]);
    // counted again from what is left, and held to the cap
    _unfinished = null;
    await trimUnfinishedMedia();
  }

  // an accepted contact, or a member of a group here
  Future<bool> _heldHere(String id) async {
    final db = await open();
    final c = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ? AND accepted = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (c.isNotEmpty) return true;
    final g = await db.query(
      'group_members',
      columns: ['group_id'],
      where: 'halo_id = ?$_kRunningGroup',
      whereArgs: [id],
      limit: 1,
    );
    return g.isNotEmpty;
  }

  Future<bool> isDelivered(String msgUid) async =>
      (await sendState(msgUid)).delivered;

  // what the database knows about one of our messages: handed over
  // somewhere (sent), and acknowledged by the peer (delivered)
  Future<({bool sent, bool delivered})> sendState(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent', 'delivered'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return (sent: false, delivered: false);
    return (
      sent: (r.first['sent'] as int? ?? 0) == 1,
      delivered: (r.first['delivered'] as int? ?? 0) == 1,
    );
  }

  // a receipt from [from]: it ticks only a message of ours that went to
  // them, or one in a group they are a member of
  // [before]: only a row written before then
  Future<void> markDelivered(
    String msgUid, {
    required String from,
    int? before,
  }) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['peer_id', 'group_id', 'burn_secs', 'burn_at', 'sent_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
    );
    for (final r in rows) {
      if (before != null && (r['sent_at'] as int? ?? before) >= before) {
        continue;
      }
      final g = r['group_id'] as String?;
      final ok = g == null || g.isEmpty
          ? r['peer_id'] == from
          : (await getGroupMembers(g)).contains(from);
      if (!ok) continue;
      // a timed message whose own send never came back ok is lit here,
      // or once it counts as sent nothing else ever starts its clock
      final secs = (r['burn_secs'] as num?)?.toInt();
      await db.update(
        'messages',
        {
          'sent': 1,
          'delivered': 1,
          if (secs != null && r['burn_at'] == null)
            'burn_at': DateTime.now().millisecondsSinceEpoch + secs * 1000,
        },
        where: g == null || g.isEmpty
            ? 'msg_uid = ? AND direction = ? AND peer_id = ?'
            : 'msg_uid = ? AND direction = ? AND group_id = ?',
        whereArgs: [msgUid, 'out', g == null || g.isEmpty ? from : g],
      );
    }
  }

  // the clock of a timed message of ours that went, started now if nothing
  // started it yet. null for a message with no timer
  Future<int?> lightBurn(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['burn_secs', 'burn_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final lit = (r.first['burn_at'] as num?)?.toInt();
    final secs = (r.first['burn_secs'] as num?)?.toInt();
    if (lit != null || secs == null) return lit;
    final at = DateTime.now().millisecondsSinceEpoch + secs * 1000;
    await db.update(
      'messages',
      {'burn_at': at},
      where: 'msg_uid = ? AND direction = ? AND burn_at IS NULL',
      whereArgs: [msgUid, 'out'],
    );
    return at;
  }

  // timed messages that came in, read just now: each clock starts here,
  // written before the screen counts it down, or a day after it came if
  // that is sooner (kBurnWaitMost). a row lit already keeps its time, and
  // one whose clock started unread keeps the earlier of the two. what came
  // in before them in the same chat has been read as well, scrolled past
  // or not, and starts with them, as the unread count clears for all of
  // it. gives the burn time of every row lit
  Future<Map<String, int>> lightReadBurns(List<String> msgUids) async {
    if (msgUids.isEmpty) return const {};
    final db = await open();
    final marks = List.filled(msgUids.length, '?').join(', ');
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <String, int>{};
    const cols = [
      'id',
      'msg_uid',
      'peer_id',
      'group_id',
      'sent_at',
      'written_at',
      'burn_secs',
      'burn_at',
      'burn_unseen',
    ];
    await db.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: cols,
        where: "msg_uid IN ($marks) AND direction = 'in'",
        whereArgs: msgUids,
      );
      // the newest row read in each chat, by when it was written and as it
      // came: a row older both ways was above it when it was read
      final newest = <(String, String?), (int, int)>{};
      Future<void> lightRow(Map<String, Object?> r) async {
        final uid = r['msg_uid'] as String?;
        final lit = (r['burn_at'] as num?)?.toInt();
        final secs = (r['burn_secs'] as num?)?.toInt();
        if (lit != null && (r['burn_unseen'] != 1 || secs == null)) {
          if (uid != null) out[uid] = lit;
          return;
        }
        if (secs == null) return;
        final sent = (r['sent_at'] as num?)?.toInt() ?? now;
        final from = min(now, burnStartBy(sent, now));
        var at = min(lit ?? from + secs * 1000, from + secs * 1000);
        // an album is read as one and burns as one
        if (uid != null) {
          at = albumItemBurnAt(at, await _albumClocks(t, uid), now);
        }
        await t.update(
          'messages',
          {'burn_at': at, 'burn_unseen': 0},
          where: lit == null
              ? 'id = ? AND burn_at IS NULL'
              : 'id = ? AND burn_unseen = 1',
          whereArgs: [r['id']],
        );
        if (uid == null) return;
        out[uid] = at;
        final a = await _albumOf(t, uid);
        if (a == null) return;
        final (album, peer, group, dir) = a;
        const behind =
            'burn_secs IS NOT NULL '
            'AND (burn_at IS NULL OR burn_at > ? OR burn_unseen = 1)';
        final mates = await t.query(
          'messages',
          columns: ['msg_uid'],
          where: '$_albumMates AND $behind',
          whereArgs: [album, peer, group, dir, uid, at],
        );
        if (mates.isEmpty) return;
        await t.update(
          'messages',
          {'burn_at': at, 'burn_unseen': 0},
          where: '$_albumMates AND $behind',
          whereArgs: [album, peer, group, dir, uid, at],
        );
        for (final m in mates) {
          out[m['msg_uid'] as String] = at;
        }
      }

      for (final r in rows) {
        await lightRow(r);
        final g = r['group_id'] as String?;
        final chat = (g == null || g.isEmpty)
            ? (r['peer_id'] as String, null)
            : ('', g);
        final (w0, id0) = newest[chat] ?? (-1, -1);
        newest[chat] = (
          max(w0, rowWrittenAt(r)),
          max(id0, (r['id'] as num).toInt()),
        );
      }
      for (final MapEntry(key: (peer, group), value: (w, id))
          in newest.entries) {
        final chat = group == null
            ? 'peer_id = ? AND group_id IS NULL'
            : 'group_id = ?';
        // waiting, or counting since before anyone read it
        for (final unread in const ['burn_at IS NULL', 'burn_unseen = 1']) {
          final older = await t.query(
            'messages',
            columns: cols,
            where:
                "$chat AND direction = 'in' AND burn_secs IS NOT NULL"
                ' AND $unread',
            whereArgs: [group ?? peer],
          );
          for (final r in older) {
            if (rowWrittenAt(r) <= w && (r['id'] as num).toInt() <= id) {
              await lightRow(r);
            }
          }
        }
      }
    });
    return out;
  }

  /// texts of ours to [peer] since [since] that went out and never came
  /// back delivered, put back in the outbox. how many
  Future<int> resendUndelivered(String peer, {required int since}) async {
    final db = await open();
    const ours =
        "$_kOneToOne AND direction = 'out' AND sent = 1 AND delivered = 0";
    final rows = await db.query(
      'messages',
      columns: ['msg_uid', 'sent_at'],
      where:
          '$ours AND msg_uid IS NOT NULL '
          'AND media_path IS NULL AND file_path IS NULL',
      whereArgs: [peer],
    );
    var n = 0;
    for (final r in rows) {
      if ((r['sent_at'] as int) < since) continue;
      // a uid is only ours to [peer]: a row of theirs or of another chat
      // with the same one stays as it is
      n += await db.update(
        'messages',
        {'sent': 0},
        where: 'msg_uid = ? AND $ours',
        whereArgs: [r['msg_uid'], peer],
      );
    }
    return n;
  }

  // notification [id] rang for message [msgUid] of [chat]. the shade keeps
  // nothing for longer than a week here
  Future<void> noteRing(int id, String chat, String msgUid) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('notif_rings', {
      'id': id,
      'chat': chat,
      'msg_uid': msgUid,
      'at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete(
      'notif_rings',
      where: 'at < ?',
      whereArgs: [now - kReceiptKeptFor.inMilliseconds],
    );
  }

  // the message notification [id] of [chat] rang for, while it is here
  Future<String?> ringOf(int id, String chat) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT r.msg_uid FROM notif_rings r JOIN messages m '
      'ON m.msg_uid = r.msg_uid WHERE r.id = ? AND r.chat = ? LIMIT 1',
      [id, chat],
    );
    return r.isEmpty ? null : r.first['msg_uid'] as String?;
  }

  // the notifications of [chat], or of [msgUid], left the shade
  Future<void> forgetRings({String? chat, String? msgUid}) async {
    if (!isOpen) return;
    final db = await open();
    if (chat != null) {
      await db.delete('notif_rings', where: 'chat = ?', whereArgs: [chat]);
    }
    if (msgUid != null) {
      await db.delete('notif_rings', where: 'msg_uid = ?', whereArgs: [msgUid]);
    }
  }

  // the tag [chat]'s notifications go under, made on its first one
  Future<String> notifTag(String chat) async => notifTagIn(await open(), chat);

  Future<String?> notifTagOf(String chat) async =>
      notifTagOfIn(await open(), chat);

  // the chat a tapped notification's tag stands for, when it is this
  // container's
  Future<String?> notifChatOf(String tag) async =>
      notifChatIn(await open(), tag);

  Future<void> markSent(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // a bare rowid comes back named after the INTEGER PRIMARY KEY (id), so
  // every read here asks for it AS rowid
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      // group_id IS NULL keeps group messages out of the 1:1 thread: a group
      // row carries peer_id = sender too
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: _kOldestFirst,
    );
  }

  // newest page of a 1:1 thread. beforeRowid, written at beforeAt, pages
  // older on scroll-up so a 5000-message chat doesn't parse the world on
  // open.
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final db = await open();
    final at = beforeRowid == null
        ? null
        : await _at(db, beforeRowid, beforeAt);
    if (beforeRowid != null && at == null) return [];
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: at == null
          ? 'peer_id = ? AND group_id IS NULL'
          : 'peer_id = ? AND group_id IS NULL AND $_kBefore',
      whereArgs: [peerId, ...?at],
      orderBy: _kNewestFirst,
      limit: limit,
    );
    return rows.reversed.toList();
  }

  // a 1:1 thread from row [rowid], written at [at], to its newest: a
  // reload keeps the pages already scrolled in
  Future<List<Map<String, Object?>>> messagesFrom(
    String peerId, {
    required int rowid,
    int? at,
  }) async {
    final db = await open();
    final from = await _at(db, rowid, at);
    if (from == null) return messagesPage(peerId);
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'peer_id = ? AND group_id IS NULL AND $_kFrom',
      whereArgs: [peerId, ...from],
      orderBy: _kOldestFirst,
    );
  }

  // only messages after a rowid, oldest first, for the chat's
  // append-on-receive fast path
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async {
    final db = await open();
    // rowid, not sent_at: clock skew can give a received note a sent_at older
    // than our local newest. rowid always climbs.
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: "peer_id = ? AND group_id IS NULL AND rowid > ?",
      whereArgs: [peerId, afterRowid],
      orderBy: 'Rowid ASC',
    );
  }

  // the newest 1:1 row per peer in the chat's order, for the home list,
  // which refreshes after every send. the burn columns say a timed one
  // still waits to be read (burnWaitsRow)
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT m.peer_id, m.direction, m.plaintext, m.media_path, m.file_name,
             m.sent_at, m.written_at, m.sticker, m.burn_secs, m.burn_at,
             m.burn_unseen
      FROM messages m
      WHERE m.id IN (
        SELECT (
          SELECT y.id FROM messages y
          WHERE y.peer_id = p.peer_id AND y.group_id IS NULL
          ORDER BY y.written_at DESC, y.id DESC LIMIT 1
        )
        FROM (SELECT DISTINCT peer_id FROM messages WHERE group_id IS NULL) p
      )
    ''');
    return {for (final r in rows) r['peer_id'] as String: r};
  }

  // the media a chat holds, newest first, and nothing else about the
  // messages: a contact page has no use for the text. a timed photo not
  // read yet is left out: it shows in the thread alone, where reading it
  // starts its clock
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: [
        'media_path',
        'secure',
        'direction',
        'burn_secs',
        'burn_at',
        'burn_unseen',
      ],
      where:
          'peer_id = ? AND group_id IS NULL AND media_path IS NOT NULL '
          'AND media_path != ?',
      whereArgs: [peerId, ''],
      orderBy: 'rowid DESC',
    );
    return [
      for (final r in rows)
        if (!burnWaitsRow(r))
          {'media_path': r['media_path'], 'secure': r['secure']},
    ];
  }

  // when the first message with a peer was, either way. null before any.
  Future<int?> firstMessageAt(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MIN(sent_at) t FROM messages '
      'WHERE peer_id = ? AND group_id IS NULL',
      [peerId],
    );
    return r.isEmpty ? null : r.first['t'] as int?;
  }

  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    // the newest in the chat's order. group_id IS NULL: a group message is
    // stored under the sender's peer_id too.
    final rows = await db.query(
      'messages',
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: _kNewestFirst,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

// search: every message's words in a full-text index, in this encrypted
// database and nowhere else. a trigger takes a message's words with it
// however it goes (burn, unsend, cleared chat), not each delete. search_meta
// says how far the first fill of an older history got.
Future<void> searchTables(Database db, {bool fresh = false}) async {
  await db.execute(
    'CREATE VIRTUAL TABLE IF NOT EXISTS msg_fts USING fts5('
    "body, tokenize = 'unicode61 remove_diacritics 2')",
  );
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS msg_fts_follow AFTER DELETE ON messages '
    'BEGIN DELETE FROM msg_fts WHERE rowid = old.id; END',
  );
  // a new index forgets from its first delete (searchForgetsOnce)
  if (fresh) {
    await db.execute(
      "INSERT INTO msg_fts(msg_fts, rank) VALUES('secure-delete', 1)",
    );
  }
  await db.execute('''
    CREATE TABLE IF NOT EXISTS search_meta (
      k TEXT PRIMARY KEY,
      v INTEGER NOT NULL
    )
  ''');
  // what the first fill has to cover: every message there is now. a fresh
  // install has none; later ones are indexed as they are saved
  final top = fresh
      ? 0
      : Sqflite.firstIntValue(
              await db.rawQuery('SELECT MAX(id) FROM messages'),
            ) ??
            0;
  await db.insert('search_meta', {
    'k': 'fill_to',
    'v': top,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.insert('search_meta', {
    'k': 'fill_at',
    'v': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// the search query itself, on any database with the schema: the app's,
/// or the debug benchmark's scratch one
Future<List<Map<String, Object?>>> runSearchQuery(
  DatabaseExecutor db,
  String? match,
  SearchKind kind, {
  int limit = 300,
}) async {
  final where = <String>[
    'm.peer_id NOT IN (SELECT halo_id FROM contacts WHERE blocked = 1)',
    // a group's rows only while the group is here: one left before its
    // rows went with it opens nothing
    "(m.group_id IN (SELECT group_id FROM groups) OR (m.group_id IS NULL "
        "AND (m.direction = 'out' OR m.peer_id IN "
        '(SELECT halo_id FROM contacts WHERE accepted = 1))))',
    // a timed message not read yet is found in its own chat alone, where
    // reading it starts its clock
    'NOT ${burnWaitsSql('m')}',
  ];
  final args = <Object?>[];
  final kw = kindWhere(kind);
  if (kw.isNotEmpty) where.add(kw);
  // newest first by row id, the order messages arrived in: the index walks
  // its ids backwards and stops at the limit. sorting by time would sort
  // every match of a common word first
  final String from;
  final String order;
  if (match != null) {
    from = 'msg_fts JOIN messages m ON m.id = msg_fts.rowid';
    where.insert(0, 'msg_fts MATCH ?');
    args.add(match);
    order = 'msg_fts.rowid DESC';
  } else {
    if (kind == SearchKind.all) return const [];
    from = 'messages m';
    order = 'm.id DESC';
  }
  args.add(limit);
  return db.rawQuery(
    'SELECT m.id, m.msg_uid, m.peer_id, m.group_id, m.direction, '
    'm.plaintext, m.sent_at, m.written_at, m.media_path, m.file_path, '
    'm.file_name, m.poll, m.preview FROM $from WHERE ${where.join(' AND ')} '
    'ORDER BY $order LIMIT ?',
    args,
  );
}

// the rows of groups no longer here, which a leave in an older version
// kept: nothing opens them, yet their files sat in the outbox. gives back
// the file columns of what went, for shredding
Future<List<Map<String, Object?>>> dropGroupLeftoversIn(
  DatabaseExecutor db,
) async {
  const gone =
      "group_id IS NOT NULL AND group_id != '' "
      'AND (group_id NOT IN (SELECT group_id FROM groups) '
      'OR group_id IN (SELECT group_id FROM groups WHERE ended_at IS NOT NULL))';
  final files = await db.rawQuery(
    'SELECT media_path, file_path FROM messages WHERE $gone',
  );
  await db.rawDelete(
    'DELETE FROM reactions WHERE msg_uid IN '
    '(SELECT msg_uid FROM messages WHERE $gone AND msg_uid IS NOT NULL)',
  );
  await db.rawDelete('DELETE FROM messages WHERE $gone');
  return files;
}

/// the same, queued on a batch: one trip for many rows
void indexSearchRowIn(Batch b, int id, Map<String, Object?> r) {
  b.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isNotEmpty) b.insert('msg_fts', {'rowid': id, 'body': body});
}

Future<void> indexSearchRow(
  DatabaseExecutor db,
  int id,
  Map<String, Object?> r,
) async {
  await db.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isEmpty) return;
  await db.insert('msg_fts', {'rowid': id, 'body': body});
}

// a poll's votes: one row per voter, the highest seq they sent. a vote can
// overtake its poll (members write to us separately), so a row may wait a
// while for the poll it names. the trigger drops the votes however the
// poll's message goes, not each delete.
Future<void> _pollTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS poll_votes (
      poll_uid TEXT NOT NULL,
      voter TEXT NOT NULL,
      group_id TEXT,
      choices TEXT NOT NULL,
      seq INTEGER NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (poll_uid, voter)
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS poll_votes_follow AFTER DELETE ON messages '
    'WHEN old.msg_uid IS NOT NULL BEGIN '
    'DELETE FROM poll_votes WHERE poll_uid = old.msg_uid; END',
  );
  // a poll that just went, for an hour: a vote naming it after that is
  // dropped at the door instead of waiting for a poll that is not coming
  await db.execute('''
    CREATE TABLE IF NOT EXISTS polls_gone (
      uid TEXT PRIMARY KEY,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS polls_gone_mark AFTER DELETE ON messages '
    'WHEN old.poll IS NOT NULL AND old.msg_uid IS NOT NULL BEGIN '
    'INSERT OR REPLACE INTO polls_gone (uid, at) VALUES '
    "(old.msg_uid, CAST(strftime('%s','now') AS INTEGER) * 1000); END",
  );
}

/// an ALTER TABLE .. ADD COLUMN in an upgrade. two of sqlite's errors mean
/// there is nothing to do: the column is there (an upgrade cut short ran it
/// already), or the table is not there yet (an older step below makes it
/// whole). any other failure stops the upgrade, and the old version runs it
/// again on the next start
Future<void> addColumn(DatabaseExecutor db, String sql) async {
  try {
    await db.execute(sql);
  } catch (e) {
    final m = '$e';
    if (!m.contains('duplicate column name') && !m.contains('no such table')) {
      rethrow;
    }
  }
}

// the upgrade to 66: the key a contact was verified under. one verified
// before is tied to the key held for them now; with none held, the mark goes
Future<void> verifiedKeyColumn(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE contacts ADD COLUMN verified_key TEXT');
  await tieVerifiedToKeys(db);
}

Future<void> tieVerifiedToKeys(DatabaseExecutor db) async {
  final rows = await db.query(
    'contacts',
    columns: ['halo_id', 'xpub'],
    where: 'verified = 1',
  );
  for (final r in rows) {
    final id = r['halo_id'];
    if (id is! String) continue;
    final key = await heldKeyHex(db, id, xpub: r['xpub'] as String?);
    await db.update(
      'contacts',
      key == null ? {'verified': 0} : {'verified_key': key},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
  }
}

// the key someone is known by here, as lowercase hex: the one their sessions
// are built on (asked of [identity], the identity's own signal store, else
// read from this database's), else the one their card brought, else the one
// inside their bundle. the dev chat's is pinned on its row. null when there
// is none. a hidden chat's database keeps no signal tables: [identity] is
// what reads its key
Future<String?> heldKeyHex(
  DatabaseExecutor db,
  String haloId, {
  String? xpub,
  Future<String?> Function(String haloId)? identity,
}) async {
  if (!isDevId(haloId)) {
    final asked = await identity?.call(haloId);
    if (asked != null && asked.isNotEmpty) return asked.toLowerCase();
    final own = await peerIdentityHex(db, haloId);
    if (own != null) return own;
  }
  final rows = await db.query(
    'contacts',
    columns: ['xpub', 'peer_bundle'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  final x = (xpub ?? (rows.isEmpty ? null : rows.first['xpub'] as String?))
      ?.trim()
      .toLowerCase();
  if (x != null && x.isNotEmpty) return x;
  final bundle = rows.isEmpty ? null : rows.first['peer_bundle'] as String?;
  if (isDevId(haloId) || bundle == null || bundle.isEmpty) return null;
  final b = _bundleIdentity(bundle);
  return b == null ? null : _keyHex(b);
}

// a signal identity key as hex, without its one-byte type
String _keyHex(List<int> b) {
  final pub = b.length == 33 ? b.sublist(1) : b;
  return pub.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

// the hidden chats' database keeps no signal tables: the keys of their people
// sit in the everyday database's, read straight from its file, with no wait
// on the signal store. the decoy and its hidden chats never read the everyday
// identity's keys: the decoy goes nowhere, and their cards are all it knows.
// the everyday and the decoy database read their own tables
// freed pages are zeroed, so a row deleted or rewritten does not linger in
// the file. the cost is a few percent on writes
Future<void> eraseFreedPages(DatabaseExecutor db) async {
  await db.rawQuery('PRAGMA secure_delete = 1');
}

// a message's words leave the search index with it, not as a mark laid
// over them, and the marks laid before are merged away. once per database.
// the index then needs sqlite 3.42, which every build since 0.2.9 bundles
Future<void> searchForgetsOnce(DatabaseExecutor db) async {
  if (await RouterRows.meta(db, 'fts_forgets') != null) return;
  final fts = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'msg_fts'",
  );
  if (fts.isNotEmpty) {
    await db.execute(
      "INSERT INTO msg_fts(msg_fts, rank) VALUES('secure-delete', 1)",
    );
    await db.execute("INSERT INTO msg_fts(msg_fts) VALUES('optimize')");
  }
  await RouterRows.putMeta(db, 'fts_forgets', '1');
}

// a delete or "this isn't them" owes the file a tidy: the search index
// keeps a removed message's words in leaves it no longer reads, and only a
// merge and a vacuum leave none of them in the file. run as the app leaves
// the screen, or after the next start
Future<void> oweTidy(DatabaseExecutor t) => RouterRows.oweTidy(t);

Future<void> tidyIfOwed(Database db) async {
  if (!await RouterRows.tidyOwed(db)) return;
  try {
    await db.execute("INSERT INTO msg_fts(msg_fts) VALUES('optimize')");
  } catch (e) {
    dlog('tidy: index not merged (${e.runtimeType})');
  }
  await db.execute('VACUUM');
  await RouterRows.tidyDone(db);
}

// pages freed before that held old rows: one vacuum per database rewrites
// them, off the start
Future<void> wipeFreedOnce(DatabaseExecutor db) async {
  if (await RouterRows.meta(db, 'freed_wiped') != null) return;
  await db.execute('VACUUM');
  await RouterRows.putMeta(db, 'freed_wiped', '1');
}

Future<String?> Function(String haloId)? keySourceFor(HaloContainer c) =>
    identical(c, HaloContainer.vault) ? _everydayKeyOf : null;

// what a key reads as when the everyday database cannot be read, a restore
// putting another file in its place say. it is no key, so it matches no mark
const kKeyUnread = 'unread';

Future<String?> _everydayKeyOf(String haloId) async {
  try {
    final rows = await (await live.open()).query(
      'peer_identities',
      columns: ['identity_key'],
      where: 'address = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _keyHex(rows.first['identity_key'] as List<int>);
  } catch (e) {
    dlog('held key: everyday not read (${e.runtimeType})');
    return kKeyUnread;
  }
}

// the key a database's signal tables hold for someone, null when none
Future<String?> peerIdentityHex(DatabaseExecutor db, String haloId) async {
  try {
    final rows = await db.query(
      'peer_identities',
      columns: ['identity_key'],
      where: 'address = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _keyHex(rows.first['identity_key'] as List<int>);
  } catch (e) {
    // a database with no signal tables knows no key but the card's
    dlog('held key: ${e.runtimeType}');
    return null;
  }
}

// verified counts only while the key it was given for is still theirs: a
// row whose mark names another key reads as not verified
Future<List<Map<String, Object?>>> verifiedNow(
  DatabaseExecutor db,
  List<Map<String, Object?>> rows, {
  String idColumn = 'halo_id',
  Future<String?> Function(String haloId)? identity,
}) async {
  List<Map<String, Object?>>? out;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if ((r['verified'] as int? ?? 0) != 1) continue;
    final id = r[idColumn] as String;
    final key = await heldKeyHex(
      db,
      id,
      xpub: r['xpub'] as String?,
      identity: identity,
    );
    final mark = (r['verified_key'] as String?)?.toLowerCase();
    if (key != null && mark == key) continue;
    out ??= List.of(rows);
    out[i] = {...r, 'verified': 0};
  }
  return out ?? rows;
}

// a mark for the key that was on screen, and only while it is still the one
// held for them. false when it has moved on since: the number shown was for
// another key. the mark and the end of the "changed" banner are one write
Future<bool> markVerified(
  DatabaseExecutor db,
  String haloId,
  bool verified, {
  String? key,
  Future<String?> Function(String haloId)? identity,
}) async {
  if (!verified) {
    await db.update(
      'contacts',
      {'verified': 0, 'verified_key': null},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
    return true;
  }
  final held = await heldKeyHex(db, haloId, identity: identity);
  if (held == null || key == null || key.trim().toLowerCase() != held) {
    return false;
  }
  final was = await db.query(
    'contacts',
    columns: ['verified', 'verified_key', 'key_changed'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  await db.update(
    'contacts',
    {'verified': 1, 'verified_key': held, 'key_changed': 0},
    where: 'halo_id = ?',
    whereArgs: [haloId],
  );
  // read again: a key that moved during the write keeps its banner, and the
  // mark stays on the old key, so the hold stands
  final now = await heldKeyHex(db, haloId, identity: identity);
  if (now == held) return true;
  if (now == kKeyUnread) {
    // a key not read is not a key changed: the row goes back as it was
    if (was.isNotEmpty) {
      await db.update(
        'contacts',
        was.first,
        where: 'halo_id = ? AND verified_key = ?',
        whereArgs: [haloId, held],
      );
    }
    return false;
  }
  await db.update(
    'contacts',
    {'verified': 0, 'key_changed': 1},
    where: 'halo_id = ? AND verified_key = ?',
    whereArgs: [haloId, held],
  );
  return false;
}

// verified under one key, holding another now: the mark stays on the old key
// until the new number is checked (a new mark) or the new key accepted
Future<bool> keyHeldIn(
  DatabaseExecutor db,
  String haloId, {
  Future<String?> Function(String haloId)? identity,
}) async {
  if (isDevId(haloId)) return false;
  final rows = await db.query(
    'contacts',
    columns: ['verified_key', 'xpub'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  if (rows.isEmpty) return false;
  final mark = (rows.first['verified_key'] as String?)?.toLowerCase();
  if (mark == null || mark.isEmpty) return false;
  final held = await heldKeyHex(
    db,
    haloId,
    xpub: rows.first['xpub'] as String?,
    identity: identity,
  );
  return held != null && held != mark;
}

// the new key taken as it is: no mark, no banner, and sending goes on
Future<void> acceptNewKeyIn(DatabaseExecutor db, String haloId) => db.update(
  'contacts',
  {'verified': 0, 'verified_key': null, 'key_changed': 0},
  where: 'halo_id = ?',
  whereArgs: [haloId],
);

// the upgrade to 67: a message a contact sent through the developer chat,
// on his phone. none from before is known
Future<void> viaDevColumn(DatabaseExecutor db) => addColumn(
  db,
  'ALTER TABLE messages ADD COLUMN via_dev INTEGER NOT NULL DEFAULT 0',
);

// the upgrade to 76: whether a chat's voice notes go out disguised, null
// until it is chosen there
Future<void> voiceDisguiseColumns(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE contacts ADD COLUMN voice_disguise INTEGER');
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN voice_disguise INTEGER');
}

/// a name's flags (contacts.name_check). ask: their chat asks for the
/// safety number. says: the name came with a request, an introduction or
/// a group, and shows as not checked. later: the ask is put off, a quiet
/// line in place of the card. a verified key outranks them all, and an add
/// from a qr read with the camera clears them
const kNameAsk = 1;
const kNameSays = 2;
const kNameLater = 4;

// the upgrade to 77. a request or a card from a group or an introduction
// still waiting is a name nobody checked
Future<void> nameCheckColumn(DatabaseExecutor db) async {
  await addColumn(
    db,
    'ALTER TABLE contacts ADD COLUMN name_check INTEGER NOT NULL DEFAULT 0',
  );
  await db.update('contacts', {
    'name_check': kNameAsk | kNameSays,
  }, where: 'accepted = 0 AND IFNULL(archived, 0) = 0 AND verified = 0');
}

// the upgrade to 83: a chat's screenshot block (chat_shots.dart)
Future<void> shotsColumns(DatabaseExecutor db) async {
  for (final col in ChatShots.columns) {
    await addColumn(
      db,
      'ALTER TABLE contacts ADD COLUMN $col INTEGER NOT NULL DEFAULT 0',
    );
  }
}

// the upgrade to 78. a row from before says when it came
Future<void> writtenAtColumn(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE messages ADD COLUMN written_at INTEGER');
  await db.execute(
    'UPDATE messages SET written_at = sent_at WHERE written_at IS NULL',
  );
  await writtenOrder(db);
}

// a chat's rows by when they were written (msg_order.dart). a row stored
// without that time takes the time it came
Future<void> writtenOrder(DatabaseExecutor db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_messages_peer_written '
    'ON messages(peer_id, group_id, written_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_messages_group_written '
    'ON messages(group_id, written_at)',
  );
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS messages_written_at AFTER INSERT ON '
    'messages WHEN new.written_at IS NULL BEGIN UPDATE messages SET '
    'written_at = new.sent_at WHERE id = new.id; END',
  );
}

// the upgrade to 80: an accept still owes them word that they are in. a
// file at 78 or 79 may come from a build that had this step at 78, so the
// steps to 78 and 79 run again first: both are safe twice
Future<void> upgradeTo80(DatabaseExecutor db, int oldV) async {
  if (oldV >= 78) {
    await writtenAtColumn(db);
    await notifRingTables(db);
  }
  await ackOwedColumn(db);
}

// the upgrade to 82: when a group ended here, and who ended it
// (group_end.dart)
Future<void> groupEndColumns(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN ended_at INTEGER');
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN ended_by TEXT');
  await groupEndIndexes(db);
}

// what an ended group may still hold, found by its id at every start
Future<void> groupEndIndexes(DatabaseExecutor db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_media_chunks_group '
    'ON media_chunks(group_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_group_media_owed_group '
    'ON group_media_owed(group_id)',
  );
}

// the upgrade to 84: the album a photo or a video went in (album.dart)
Future<void> albumColumns(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE messages ADD COLUMN album_id TEXT');
  await addColumn(db, 'ALTER TABLE messages ADD COLUMN album_n INTEGER');
  await addColumn(db, 'ALTER TABLE messages ADD COLUMN album_i INTEGER');
  await albumIndex(db);
}

Future<void> albumIndex(DatabaseExecutor db) => db.execute(
  'CREATE INDEX IF NOT EXISTS idx_messages_album ON messages(album_id)',
);

Future<void> ackOwedColumn(DatabaseExecutor db) => addColumn(
  db,
  'ALTER TABLE contacts ADD COLUMN ack_owed INTEGER NOT NULL DEFAULT 0',
);

int nameCheckOf(Map<String, Object?>? row) =>
    (row?['name_check'] as num?)?.toInt() ?? 0;

/// the name on [row] was given, not checked: a request, an introduction or
/// a group named them, and no qr or safety number has settled it since
bool nameUnchecked(Map<String, Object?>? row) =>
    row != null &&
    (nameCheckOf(row) & kNameSays) != 0 &&
    (row['verified'] as num?)?.toInt() != 1 &&
    !isDevId(row['halo_id'] as String? ?? '');

/// [row]'s chat asks for the safety number: added by a code or a link, or
/// taken in from a request, and not verified yet
bool nameAsks(Map<String, Object?>? row) =>
    row != null &&
    (nameCheckOf(row) & kNameAsk) != 0 &&
    (row['verified'] as num?)?.toInt() != 1 &&
    (row['accepted'] as num?)?.toInt() == 1 &&
    !isDevId(row['halo_id'] as String? ?? '');

// the upgrade to 65: when a room joined off a link sent its join, until
// its creator lets this phone in
Future<void> roomJoiningColumn(DatabaseExecutor db) =>
    addColumn(db, 'ALTER TABLE groups ADD COLUMN joining_at INTEGER');

// every member key a room ever listened to, so its end forgets each one's
// address. recent: the last messages taken from it (roomEntry). once it is
// out (1, its lane still to stop; 2, stopped), owed: the hashes of those
// still let in, sent before it went
Future<void> roomKeysTable(DatabaseExecutor db) => db.execute('''
  CREATE TABLE IF NOT EXISTS room_keys (
    group_id TEXT NOT NULL,
    member TEXT NOT NULL,
    recent TEXT NOT NULL DEFAULT '',
    owed TEXT NOT NULL DEFAULT '',
    out INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, member)
  )
''');

// the upgrade to 71: the group a file's slices are for, and the room keys.
// a room_keys from a build before 71 settled gets the columns it lacks
Future<void> roomTeardownTables(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE media_chunks ADD COLUMN group_id TEXT');
  await roomKeysTable(db);
  for (final col in const [
    "recent TEXT NOT NULL DEFAULT ''",
    "owed TEXT NOT NULL DEFAULT ''",
    'out INTEGER NOT NULL DEFAULT 0',
  ]) {
    await addColumn(db, 'ALTER TABLE room_keys ADD COLUMN $col');
  }
}

// the upgrade to 68: the key a reset room link knocks on, none until a
// reset and the room's own key takes the knocks, and the door before it
// until its files are gone
Future<void> roomDoorColumns(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN door_priv TEXT');
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN door_pub TEXT');
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN door_was TEXT');
}

// the upgrade to 62: a timed message whose clock started before it was
// read, and the index the burn sweep reads
Future<void> burnUnseenTables(DatabaseExecutor db) async {
  await addColumn(
    db,
    'ALTER TABLE messages ADD COLUMN burn_unseen INTEGER NOT NULL DEFAULT 0',
  );
  await burnIndex(db);
}

// what the burn sweep reads every few seconds: the timed rows alone, lit
// or waiting
Future<void> burnIndex(DatabaseExecutor db) => db.execute(
  'CREATE INDEX IF NOT EXISTS idx_messages_burn ON messages(burn_at) '
  'WHERE burn_at IS NOT NULL OR burn_secs IS NOT NULL',
);

// wrapped: one throw in a migration and the app never opens again. without
// the table there is simply no developer row
Future<void> _devChatTables(Database db) async {
  try {
    await devChatTables(db);
  } catch (e) {
    dlog('devchat table: $e');
  }
}

// wrapped like the dev chat's: without the table there is no support
// inbox, and the app still opens
Future<void> _supportTables(Database db) async {
  try {
    await supportTables(db);
  } catch (e) {
    dlog('support table: $e');
  }
}

// someone blocked before the spans were kept counts as blocked from the
// start, and is listened on from now. one with a span open already keeps
// that one
const kSeedBlockSpans =
    'INSERT INTO block_spans (peer_id, from_at, listen_from) '
    "SELECT halo_id, 0, CAST(strftime('%s', 'now') AS INTEGER) * 1000 "
    'FROM contacts WHERE blocked = 1 AND halo_id NOT IN '
    '(SELECT peer_id FROM block_spans WHERE to_at IS NULL)';

// every blocked row, and whether its open span is listened on from after
// the argument: from its start, or from when a seeded one was made
const kBlockedRowsSql =
    'SELECT c.*, EXISTS (SELECT 1 FROM block_spans s WHERE '
    's.peer_id = c.halo_id AND s.to_at IS NULL AND '
    'COALESCE(s.listen_from, s.from_at) > ?) AS listen '
    'FROM contacts c WHERE c.blocked = 1';

// the stamp is the sender's clock, which may run behind this one. what
// they wrote in the last minutes before the unblock is let in, or a slow
// clock costs them what they sent once they were free to
const kUnblockGrace = 10 * 60 * 1000;

// a stamp further ahead of this clock than this is taken as now
const kStampAhead = 10 * 60 * 1000;

// whether a copy from someone not blocked now may be what a block of
// theirs held back. [ended]: their spans that ended, from and to.
// [reached]: when it reached the relay, or this phone, by this clock: a
// stored one between what the relay was known to have handed over and the
// subscribe, a live one as it came. one that reached it while a block
// held stays out whatever it says. one whose window runs past the unblock,
// or that no lane dates, is judged by its stamps as it was before the
// lanes said (stampHeld). one that reached it after is still kept out if
// their own two stamps say it was written while one held: the wrap time
// less when it was written is how long before it went it was written,
// whatever their clock reads; with no wrap time, its written stamp and the
// grace. nothing is noted by this: a copy sent again after the unblock
// comes live, and only the uids noted while the block held keep that out
bool heldBySpans(
  List<(int, int)> ended, {
  Reached? reached,
  required int came,
  int? now,
  int? written,
  int? wrapped,
}) {
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  if (reached == null) {
    return stampHeld(
      ended,
      written: written,
      wrapped: wrapped,
      came: came,
      now: at,
    );
  }
  final r = reached;
  for (final span in ended) {
    final (from, to) = span;
    if (r.until <= from) continue;
    if (r.until <= to) return true;
    if (r.from < to || wrapped == null) {
      if (stampHeld(
        [span],
        written: written,
        wrapped: wrapped,
        came: r.until,
        now: at,
      )) {
        return true;
      }
      continue;
    }
    final age = written != null && wrapped > written ? wrapped - written : 0;
    final wrote = r.until - age;
    if (wrote >= from && wrote < to) return true;
  }
  return false;
}

// the stamps alone: when it was written by their clock, never past the
// wrap, never far ahead of this clock, inside an ended span less how far
// behind ours their clock may run, no further than the copy took to come
bool stampHeld(
  List<(int, int)> ended, {
  int? written,
  int? wrapped,
  required int came,
  required int now,
}) {
  var at = written ?? wrapped;
  if (at == null || at <= 0) return false;
  if (wrapped != null && wrapped > 0 && wrapped < at) at = wrapped;
  if (at > now + kStampAhead) at = now;
  final slack = wrapped == null || wrapped <= 0
      ? kUnblockGrace
      : (came - wrapped).clamp(0, kUnblockGrace);
  for (final (from, to) in ended) {
    if (from <= at && to > at + slack) return true;
  }
  return false;
}

// a contact row that goes ends its open span, so what is left of a block
// never holds over someone added again
const kCloseSpansOnDelete = '''
  CREATE TRIGGER IF NOT EXISTS block_spans_row_gone
  AFTER DELETE ON contacts
  BEGIN
    UPDATE block_spans
    SET to_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
    WHERE peer_id = OLD.halo_id AND to_at IS NULL;
  END
''';

// how many dropped uids are kept per person, the newest
const kBlockedDropsKept = 2000;

// keeps [uid] as dropped from [haloId] at [now], their newest
// kBlockedDropsKept only, and at most once a day lets go of what has not
// come again in sixty days. when it last swept
Future<int> noteBlockedDropIn(
  DatabaseExecutor db,
  String haloId,
  String uid, {
  required int now,
  required int sweptAt,
}) async {
  await db.rawInsert(
    'INSERT OR REPLACE INTO blocked_drops (peer_id, uid, at) '
    'VALUES (?, ?, ?)',
    [haloId, uid, now],
  );
  await db.rawDelete(
    'DELETE FROM blocked_drops WHERE peer_id = ?1 AND rowid NOT IN '
    '(SELECT rowid FROM blocked_drops WHERE peer_id = ?1 '
    'ORDER BY at DESC, rowid DESC LIMIT ?2)',
    [haloId, kBlockedDropsKept],
  );
  if (now - sweptAt < 86400000) return sweptAt;
  await db.rawDelete('DELETE FROM blocked_drops WHERE at < ?', [
    now - 60 * 86400000,
  ]);
  return now;
}

// whether [uid] from [haloId] was dropped while they were blocked
Future<bool> droppedIn(DatabaseExecutor db, String haloId, String uid) async =>
    (await db.rawQuery(
      'SELECT 1 FROM blocked_drops WHERE peer_id = ? AND uid = ? LIMIT 1',
      [haloId, uid],
    )).isNotEmpty;

// when each block held, and the uids of what came while it did. a copy of
// one, or one stamped inside a block that ended, is dropped after an
// unblock as it was during it. someone already blocked is taken as blocked
// from the start. wrapped: without them a block still drops what comes
// while it holds
Future<void> blockTables(DatabaseExecutor db, {bool seed = false}) async {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS block_spans (
        peer_id TEXT NOT NULL,
        from_at INTEGER NOT NULL,
        to_at INTEGER,
        listen_from INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS block_spans_peer ON block_spans(peer_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_drops (
        peer_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        at INTEGER NOT NULL,
        PRIMARY KEY (peer_id, uid)
      )
    ''');
    // the daily sweep goes by age
    await db.execute(
      'CREATE INDEX IF NOT EXISTS blocked_drops_at ON blocked_drops(at)',
    );
    await db.execute(kCloseSpansOnDelete);
    if (seed) {
      // a table made before the column was: the seed names it
      await addColumn(
        db,
        'ALTER TABLE block_spans ADD COLUMN listen_from INTEGER',
      );
      await db.execute(kSeedBlockSpans);
    }
  } catch (e) {
    dlog('block tables: $e');
  }
}

// the upgrade to 81: keys taken as not who they said ("this isn't them"),
// blocked by the key alone, never by a name, and the words they went by,
// which nobody who writes first is given again
Future<void> blockedKeysTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS blocked_keys (
      x TEXT PRIMARY KEY,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS name_tombs (
      name TEXT PRIMARY KEY,
      at INTEGER NOT NULL
    )
  ''');
}

/// a group whose admin "this isn't them" took off this phone: it has none,
/// so no change to it is taken from anyone. never an id's shape
const kAdminGone = 'gone:admin';

// the upgrade to 75: when a seeded span is listened on from. one seeded
// before is listened on from now, for as long as a new block would be.
// and when a kept opener reached the relay
@visibleForTesting
Future<void> blockListenColumn(DatabaseExecutor db) async {
  try {
    await addColumn(
      db,
      'ALTER TABLE first_kept ADD COLUMN reached_from INTEGER',
    );
    await addColumn(
      db,
      'ALTER TABLE first_kept ADD COLUMN reached_until INTEGER',
    );
  } catch (e) {
    dlog('first kept columns: $e');
  }
  try {
    await addColumn(
      db,
      'ALTER TABLE block_spans ADD COLUMN listen_from INTEGER',
    );
    await db.execute(
      "UPDATE block_spans SET listen_from = CAST(strftime('%s', 'now') AS "
      'INTEGER) * 1000 WHERE from_at = 0 AND to_at IS NULL AND '
      'listen_from IS NULL',
    );
  } catch (e) {
    dlog('block listen column: $e');
  }
}

// steps 63 and 64. a phone at 63 may hold either table, so both are made
// from below 64, and making one again changes nothing
@visibleForTesting
Future<void> upgradeTo64(DatabaseExecutor db, int oldV) async {
  if (oldV >= 64) return;
  // what someone blocked sent while it held, and when it held
  await blockTables(db, seed: true);
  // what came in and went, known by its uid and sender (kGoneFor)
  await _goneTable(db);
}

// a direct-onion message past a stranger's two has no relay to wait on. it
// waits here instead, still sealed, and opens when the person is accepted.
Future<void> _heldTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS held_onion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      peer_id TEXT NOT NULL,
      cipher TEXT NOT NULL,
      at INTEGER NOT NULL,
      media_id TEXT,
      chunk INTEGER
    )
  ''');
}

// the invite counter as the key store holds it; a stand-in in tests
@visibleForTesting
Future<String?> Function() readFcCounter = () =>
    secureStore.read(key: 'fc_counter');

const kOpenerGoesWithRow = '''
  CREATE TRIGGER IF NOT EXISTS opener_again_row_gone
  AFTER DELETE ON messages
  BEGIN
    DELETE FROM opener_again WHERE msg_uid = OLD.msg_uid;
  END
''';

// an opener kept to be tried again (HaloDb.keepFirst)
typedef FirstKept = ({
  String hash,
  String cipher,
  String peer,
  int at,
  int tries,
  int nextAt,
  // when it reached the relay or this phone, by this clock, where the lane
  // said: null for one kept before that was kept
  Reached? reached,
});

// a stranger's opener that opened and did not file here, kept as it came
// under its hash, with its sender and uid, and tried again; and an opener
// of ours with no receipt yet: how often it went again, when it last did,
// the words it went as, and whether its onion and relay copies both went
@visibleForTesting
Future<void> firstContactTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS first_kept (
      hash TEXT PRIMARY KEY,
      cipher TEXT NOT NULL,
      peer TEXT NOT NULL DEFAULT '',
      uid TEXT,
      at INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL,
      reached_from INTEGER,
      reached_until INTEGER
    )
  ''');
  // the words an opener went as go with it, however it goes
  await db.execute(kOpenerGoesWithRow);
  await db.execute('''
    CREATE TABLE IF NOT EXISTS opener_again (
      msg_uid TEXT PRIMARY KEY,
      tries INTEGER NOT NULL DEFAULT 0,
      last_at INTEGER NOT NULL,
      wire TEXT,
      both_went INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

// a chat's notifications go under a random tag kept here, in the
// container that holds the chat. chat is a contact's id, 'group:' and a
// group's, or a support chat's payload
Future<void> notifTagTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS notif_tags (
      chat TEXT PRIMARY KEY,
      tag TEXT NOT NULL UNIQUE
    )
  ''');
}

// which message each notification still in the shade rang for, by its
// android id, kept here in the chat's own container: the tap hands back the
// id alone and opens the chat on it. a row goes with its message, and when
// the notification leaves the shade
Future<void> notifRingTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS notif_rings (
      id INTEGER PRIMARY KEY,
      chat TEXT NOT NULL,
      msg_uid TEXT NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS notif_rings_follow AFTER DELETE ON '
    'messages BEGIN DELETE FROM notif_rings WHERE msg_uid = old.msg_uid; END',
  );
}

// a chat's own wallpaper photo, and the default every chat without a choice
// of its own shows. chat is a contact's id, 'group:' and a group's id, or
// '' for the default. atmo is kPhotoWall with a photo, or for the default a
// built-in by name. the photo's bytes live here, under the container's own
// key, and nowhere else. a chat's photo lasts while its atmosphere says
// photo: whatever clears that or drops the row (a delete, a wipe of the
// chat's settings) takes the photo with it, by the triggers below
const kPhotoWall = 'photo';

String wallKey(String chatId, {bool group = false}) =>
    group ? 'group:$chatId' : chatId;

Future<void> wallpaperTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS wallpapers (
      chat TEXT PRIMARY KEY,
      atmo TEXT NOT NULL,
      photo BLOB
    )
  ''');
  for (final (table, key) in const [
    ('contacts', 'X.halo_id'),
    ('groups', "'group:' || X.group_id"),
  ]) {
    final oldKey = key.replaceAll('X.', 'old.');
    final newKey = key.replaceAll('X.', 'new.');
    await db.execute(
      'CREATE TRIGGER IF NOT EXISTS wallpapers_${table}_gone AFTER DELETE ON '
      '$table BEGIN DELETE FROM wallpapers WHERE chat = $oldKey; END',
    );
    await db.execute(
      'CREATE TRIGGER IF NOT EXISTS wallpapers_${table}_off AFTER UPDATE OF '
      "atmosphere ON $table WHEN new.atmosphere IS NOT '$kPhotoWall' BEGIN "
      'DELETE FROM wallpapers WHERE chat = $newKey; END',
    );
  }
}

// a photo no chat here says it shows: one written for a row that went or
// was replaced whole (INSERT OR REPLACE fires no delete trigger). the
// default ('') is never a chat's
@visibleForTesting
const kOrphanWallpapers =
    "chat <> '' AND NOT EXISTS "
    "(SELECT 1 FROM contacts c WHERE c.halo_id = wallpapers.chat "
    "AND c.atmosphere = '$kPhotoWall') AND NOT EXISTS "
    "(SELECT 1 FROM groups g WHERE substr(wallpapers.chat, 1, 6) = 'group:' "
    "AND g.group_id = substr(wallpapers.chat, 7) "
    "AND g.atmosphere = '$kPhotoWall')";

Future<void> dropOrphanWallpapers(DatabaseExecutor db) async {
  const orphan = kOrphanWallpapers;
  // an open with nothing to sweep writes nothing
  final any = await db.rawQuery(
    'SELECT 1 FROM wallpapers WHERE $orphan LIMIT 1',
  );
  if (any.isEmpty) return;
  await db.execute('DELETE FROM wallpapers WHERE $orphan');
}

// the photos an older version kept as files in the clear, taken in at the
// upgrade to 85: each cleaned as a photo that leaves is, kept here, its
// chat marked photo. one that will not read or clean leaves its chat on the
// default. the files are handed back to be shredded once the upgrade is
// written; only a file in this container's own [folder] is ever read or
// named
Future<List<String>> adoptWallpaperFiles(
  DatabaseExecutor db,
  String folder,
) async {
  final files = <String>[];
  for (final (table, id, group) in const [
    ('contacts', 'halo_id', false),
    ('groups', 'group_id', true),
  ]) {
    for (final r in await db.query(
      table,
      columns: [id, 'atmosphere'],
      where: "atmosphere LIKE 'image:%'",
    )) {
      final chat = r[id];
      final atmo = r['atmosphere'];
      if (chat is! String || atmo is! String || !atmo.startsWith('image:')) {
        continue;
      }
      final path = atmo.substring(6);
      final inFolder = p.equals(p.dirname(path), folder);
      Uint8List? photo;
      if (inFolder) {
        try {
          // off the ui thread, as every photo cleaning is
          photo = await photoToSendOffUi(await File(path).readAsBytes());
        } catch (e) {
          dlog('wallpaper: an old file did not read (${e.runtimeType})');
        }
      }
      if (photo != null) {
        await db.insert('wallpapers', {
          'chat': wallKey(chat, group: group),
          'atmo': kPhotoWall,
          'photo': photo,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await db.update(
        table,
        {'atmosphere': photo == null ? null : kPhotoWall},
        where: '$id = ?',
        whereArgs: [chat],
      );
      if (inFolder) files.add(path);
    }
  }
  return files;
}

// a group's texts sent again to a member who restored a backup: once per
// restore, known by its backup's day (0 when the ask had none)
Future<void> groupResentTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_resent (
      group_id TEXT NOT NULL,
      member TEXT NOT NULL,
      since INTEGER NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (group_id, member, since)
    )
  ''');
}

Future<String?> notifTagOfIn(DatabaseExecutor db, String chat) async {
  final r = await db.query(
    'notif_tags',
    columns: ['tag'],
    where: 'chat = ?',
    whereArgs: [chat],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['tag'] as String;
}

// made once: a second caller at the same moment takes the first one's
Future<String> notifTagIn(DatabaseExecutor db, String chat) async {
  final had = await notifTagOfIn(db, chat);
  if (had != null) return had;
  await db.insert('notif_tags', {
    'chat': chat,
    'tag': newNotifTag(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  return (await notifTagOfIn(db, chat))!;
}

Future<String?> notifChatIn(DatabaseExecutor db, String tag) async {
  final r = await db.query(
    'notif_tags',
    columns: ['chat'],
    where: 'tag = ?',
    whereArgs: [tag],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['chat'] as String;
}

// the upgrade to 69: the file a held slice is of and its place in it, so a
// file takes one place and each slice one row
Future<void> heldMediaColumn(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE held_onion ADD COLUMN media_id TEXT');
  await addColumn(db, 'ALTER TABLE held_onion ADD COLUMN chunk INTEGER');
}

// a file coming in that is not whole yet: who is sending it, whether they
// can be asked for the missing slices, and how many asks in a row brought
// nothing.
Future<void> _mediaWantsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS media_wants (
      media_id TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      total INTEGER NOT NULL,
      can_resend INTEGER NOT NULL,
      last_at INTEGER NOT NULL,
      asked_at INTEGER NOT NULL DEFAULT 0,
      asks INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

// a pin in a 1:1 chat that has not reached the other person yet. a pin is
// shared state; sent once and lost, the two lists differ for good.
Future<void> _pinsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pins_out (
      msg_uid TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      pinned INTEGER NOT NULL,
      at INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

// an edit made offline queues like a message, or it shows as edited here
// and never arrives there
Future<void> _editsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS edits_out (
      msg_uid TEXT PRIMARY KEY,
      peer_id TEXT NOT NULL,
      new_text TEXT NOT NULL,
      at INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

// the upgrade to 72: a queued edit, pin or frame keeps its tries and its
// next turn on disk, and the time of the last edit and reaction taken from
// each sender is kept for each message
Future<void> queueTurnColumns(DatabaseExecutor db) async {
  for (final t in const ['edits_out', 'pins_out', 'frames_out']) {
    await addColumn(
      db,
      'ALTER TABLE $t ADD COLUMN tries INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      db,
      'ALTER TABLE $t ADD COLUMN next_at INTEGER NOT NULL DEFAULT 0',
    );
  }
  await frameOrderTable(db);
}

// per message, sender and kind (edit or reaction): the sender's time on
// the last one taken. an older copy that comes after it is left out
Future<void> frameOrderTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS frame_order (
      msg_uid TEXT NOT NULL,
      sender TEXT NOT NULL,
      kind TEXT NOT NULL,
      w INTEGER NOT NULL,
      PRIMARY KEY (msg_uid, sender, kind)
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS frame_order_follow AFTER DELETE ON '
    'messages WHEN old.msg_uid IS NOT NULL BEGIN '
    'DELETE FROM frame_order WHERE msg_uid = old.msg_uid; END',
  );
}

// a 1:1 message that came in and burned or was deleted here (kGoneFor).
// a copy sent again, after a restore on the far side say, is known by its
// uid and sender: acked again and never shown again. a group's or a room's
// is known by its group and sender, read again from the relays after a
// restore too
Future<void> _goneTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS gone_in (
      msg_uid TEXT NOT NULL,
      peer_id TEXT NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (msg_uid, peer_id)
    )
  ''');
}

/// what a message that came in and went is kept under in gone_in: its
/// sender, or in a group its group and sender. a hidden group's rows move
/// with it, and one member's word never stands for another's
String goneKey(String sender, {String? group}) =>
    group == null ? sender : 'group:$group:$sender';

/// the gone_in rows of [group]: its own, every sender's
String goneGroupPrefix(String group) => 'group:$group:';

/// whether what of [group] went is written down. an id with a ':' in it
/// could read as another group's start, so its records stay in memory
bool goneKept(String? group) => group == null || !group.contains(':');

// an unsend or a reaction in a 1:1 chat that has not reached the other
// person yet, one of each kind a message and person: the latest word
// replaces the last. a reaction's body is its emoji, empty when it was
// taken off. the uid of what came in is the sender's to pick, so the
// person is in the key
Future<void> _framesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS frames_out (
      msg_uid TEXT NOT NULL,
      kind TEXT NOT NULL,
      peer_id TEXT NOT NULL,
      body TEXT NOT NULL,
      at INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (msg_uid, kind, peer_id)
    )
  ''');
}

// a group file some members still lack once its row reads sent: per member,
// the slices they hold and when to try them again. the trigger drops them
// however the message goes, as poll_votes does
Future<void> groupOwedTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_media_owed (
      msg_uid TEXT NOT NULL,
      group_id TEXT NOT NULL,
      member TEXT NOT NULL,
      total INTEGER NOT NULL,
      have TEXT NOT NULL DEFAULT '',
      sent_to INTEGER NOT NULL,
      since INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL,
      PRIMARY KEY (msg_uid, member)
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS group_media_owed_follow AFTER DELETE ON '
    'messages WHEN old.msg_uid IS NOT NULL BEGIN '
    'DELETE FROM group_media_owed WHERE msg_uid = old.msg_uid; END',
  );
}

// a group control each member is still to get, in the order it was made: a
// member takes them one after the other. and per group, the stamp of the
// newest roster taken, with the room keys that left, which an older roster
// does not bring back
Future<void> groupCtlTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_ctl_out (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id TEXT NOT NULL,
      member TEXT NOT NULL,
      ctl TEXT NOT NULL,
      since INTEGER NOT NULL,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_roster (
      group_id TEXT PRIMARY KEY,
      stamp INTEGER NOT NULL DEFAULT 0,
      gone TEXT NOT NULL DEFAULT '',
      seq INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

Future<void> _shieldTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS shield (
      halo_id TEXT PRIMARY KEY,
      headline TEXT NOT NULL,
      lines TEXT NOT NULL,
      dismissed INTEGER NOT NULL DEFAULT 0,
      at INTEGER NOT NULL
    )
  ''');
}

Future<void> _vouchTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vouches (
      halo_id TEXT NOT NULL,
      voucher_id TEXT NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (halo_id, voucher_id)
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_vouches_halo_id ON vouches(halo_id)',
  );
}

// one store's tables. under a prefix, another store in the same database
Future<void> _signalTables(Database db, {String prefix = ''}) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, created_at INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (address, device_id))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}peer_identities (address TEXT PRIMARY KEY, identity_key BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  );
}

// wrapped like the dev chat's row: without them an anonymous start fails
// closed, and the app still opens
Future<void> _devSignalTables(Database db) async {
  try {
    await _signalTables(db, prefix: kDevSignalPrefix);
  } catch (e) {
    dlog('dev signal tables: $e');
  }
}

/// the contacts rows the requests inbox holds: someone not accepted who
/// wrote one to one, waits sealed, or was introduced. a group member's
/// key-only row is none of these and asked for nothing
@visibleForTesting
const kRequestRows =
    'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0 AND ('
    'EXISTS (SELECT 1 FROM messages m WHERE m.peer_id = contacts.halo_id '
    'AND m.group_id IS NULL) OR '
    'EXISTS (SELECT 1 FROM held_onion h WHERE h.peer_id = contacts.halo_id) OR '
    'EXISTS (SELECT 1 FROM vouches v WHERE v.halo_id = contacts.halo_id))';

/// [sent] on a row of ours a block kept from going: not sent, and only a
/// tap sends it, an unblock never does
const kNotSent = -1;

/// a queue's rows for no one blocked here: one list in the database, so
/// however many there are none is a variable of its own
@visibleForTesting
const kNotBlocked =
    'peer_id NOT IN (SELECT halo_id FROM contacts WHERE blocked = 1)';

/// the people the shelf may let in without an accept: accepted already and
/// not blocked. a stranger's rows wait for theirs
@visibleForTesting
const kHeldOfAccepted =
    'SELECT DISTINCT h.peer_id FROM held_onion h '
    'JOIN contacts c ON c.halo_id = h.peer_id '
    'WHERE c.accepted = 1 AND IFNULL(c.blocked, 0) = 0';

/// a request as the inbox shows it, or one declined and parked since
@visibleForTesting
const kAskedRows =
    '($kRequestRows) OR '
    '(accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1)';
