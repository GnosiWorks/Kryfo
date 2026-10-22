// SPDX-License-Identifier: GPL-3.0-or-later
// the database: HaloDb with its tables and upgrade steps

part of '../main.dart';

class HaloDb
    with
        _ContactRows,
        _BlockRows,
        _MessageRows,
        _GroupRows,
        _RoomRows,
        _DeleteRows,
        _ChatSettingRows
    implements GroupOwedStore {
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
  @override
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
  @override
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

  @override
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

  // how long one that came in and went is known by its uid: as far back
  // as a resend reaches, and our relay's fortnight, which a fresh install
  // after a restore reads again. other relays keep what they choose
  static const kGoneFor = Duration(days: 15);

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
  @override
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
  @override
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

  @override
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
}

Future<void> _dropQueuedTo(DatabaseExecutor db, String peerId) async {
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

// members who left or were taken out: their rows go, and each file they
// were owed counts one fewer it went to, so the others' line stays true
Future<void> _owedGone(
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
// the table there is no developer row
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
