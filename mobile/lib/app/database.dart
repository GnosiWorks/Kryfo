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
        _ChatSettingRows,
        _FirstContactRows,
        _OutboxRows,
        _PollRows,
        _SearchRows,
        _MediaRows,
        _GroupOwedRows,
        _NotifRows,
        _DraftRows,
        _GroupShotsRows,
        _PhotoRows
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

  // the schema open() upgrades every file to
  // moves with version: below
  static const schema = 98;

  Database? _db;
  String? _given;
  // its files' key was handed to the desktop, once per open
  bool _keyed = false;

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
    if (_keyed) containerClosed?.call(container.id);
    _keyed = false;
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

  // a wrapped container's folders readable under its key without its file
  // open: a vault just made, while chats move into it attached elsewhere.
  // close() lets them go, as after an open
  void keyFolders() {
    final given = _given;
    if (given == null) throw StateError('${container.dbFile} has no key here');
    if (_keyed) return;
    containerOpened?.call(container.id, container.folderSuffix, given);
    _keyed = true;
  }

  @override
  Future<Database> open() async {
    if (_retired) throw StateError('${container.dbFile} was replaced');
    if (_db != null) return _db!;
    final path = await container.dbPath();
    final pw = await _passphrase();
    // on desktop its files open from here on, the upgrade's own too
    if (!_keyed) {
      containerOpened?.call(container.id, container.folderSuffix, pw);
    }
    _keyed = true;
    // photo files an upgrade took in, shredded once it is written
    var adopted = const <String>[];
    _db = await openDatabase(
      path,
      password: pw,
      // the upgrade tests read this line: it stays the number, = schema
      version: 98,
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
            shots_when INTEGER NOT NULL DEFAULT 0,
            opus_can INTEGER NOT NULL DEFAULT 0,
            caps TEXT NOT NULL DEFAULT '',
            caps_at INTEGER NOT NULL DEFAULT 0,
            ident INTEGER NOT NULL DEFAULT 0,
            ikey TEXT,
            heal_last INTEGER,
            chat_burn INTEGER
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
            spoiler INTEGER NOT NULL DEFAULT 0,
            silent INTEGER NOT NULL DEFAULT 0,
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
            chat_burn INTEGER,
            ended_at INTEGER,
            ended_by TEXT,
            shots_on INTEGER NOT NULL DEFAULT 0,
            shots_at INTEGER NOT NULL DEFAULT 0,
            shots_all INTEGER NOT NULL DEFAULT 0,
            shots_by INTEGER NOT NULL DEFAULT 0,
            shots_when INTEGER NOT NULL DEFAULT 0,
            shots_line INTEGER NOT NULL DEFAULT 0,
            shots_told INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE group_members (
            group_id TEXT NOT NULL,
            halo_id TEXT NOT NULL,
            joined_at INTEGER NOT NULL,
            opus_can INTEGER NOT NULL DEFAULT 0,
            shots_nudged INTEGER NOT NULL DEFAULT 0,
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
        await dropFetchTable(db);
        await _heldTable(db);
        await _signalTables(db);
        await identityTables(db);
        await inviteTables(db);
        await pqRestartTables(db);
        await contactKeyIndex(db);
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
        await draftsTable(db);
        await photoTables(db);
        await healTables(db);
        await takenTables(db);
        await deviceTables(db, addColumn);
      },
      onUpgrade: (db, oldV, newV) async {
        // 62 runs after every older step, below: its index names columns
        // they add. 66 runs after it: it reads what they all make. 67 to 89
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
              chat_burn INTEGER,
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
        if (oldV < 86) {
          // unsent words, kept per chat so a stopped process keeps them
          await draftsTable(db);
        }
        if (oldV < 87) {
          // which phones play opus voice notes (voice_format.dart)
          await opusColumns(db);
        }
        if (oldV < 88) {
          // what a contact's phone understands (typing.dart)
          await capsColumns(db);
        }
        if (oldV < 89) {
          // a group's screenshot block (group_shots.dart)
          await groupShotsColumns(db);
        }
        if (oldV < 90) {
          // the files on their way in from the files service, and the ids
          // of the ones already here (file_drop.dart)
          await dropFetchTable(db);
        }
        if (oldV < 91) {
          // the post-quantum prekeys the shim keeps (signal_stores.dart),
          // and what a kept first contact opened to
          await upgradeTo91(db);
        }
        if (oldV < 92) {
          // identities, and the signal stores per identity (identities.dart)
          await upgradeTo92(db);
        }
        if (oldV < 94) {
          // v4 invites, the hellos waiting on them, the hellos seen
          // (invites.dart)
          await inviteTables(db);
        }
        if (oldV < 95) {
          // linked devices: lists, proofs, quiet devices, the pool and
          // what the later steps keep (devices/device_store.dart)
          await deviceTables(db, addColumn);
        }
        // the pq restart of held chats, and the one-time invites an
        // opener went to (pq_restart.dart, 3c)
        if (oldV < 96) {
          await pqRestartTables(db, upgrade: true);
        }
        // a photo sent as a spoiler (batch 3)
        if (oldV < 97) {
          await spoilerColumn(db);
        }
        // each chat's own flame timer (batch 3)
        if (oldV < 98) {
          await chatBurnColumns(db);
        }
        // profile photos (profile_photo.dart), first made at 93. every
        // step is safe twice and runs on any upgrade, last, so a file that
        // took a later number without them still gets them
        await photoTables(db);
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
    try {
      await rosterTableAtOpen(_db!);
    } catch (e) {
      dlog('roster invite: table not made (${e.runtimeType})');
    }
    // the heal's lines and nonces (heal.dart): no version step, so a file
    // that took 95 or 96 first gets them all the same
    try {
      await healTablesAtOpen(_db!);
    } catch (e) {
      dlog('heal: tables not made (${e.runtimeType})');
    }
    // our unsends and edits kept for a contact's restore (restore_undo.dart)
    try {
      await takenTablesAtOpen(_db!);
    } catch (e) {
      dlog('restore: taken table not made (${e.runtimeType})');
    }
    // a file that took a later number without them (a build of another
    // branch) still gets them
    try {
      await deviceTablesAtOpen(_db!, addColumn);
    } catch (e) {
      dlog('devices: tables not made (${e.runtimeType})');
    }
    // ours sent without sound: no version step, so any file gets it
    try {
      await silentColumnAtOpen(_db!);
    } catch (e) {
      dlog('silent: column not made (${e.runtimeType})');
    }
    // folders by number and files under names that say nothing, before a
    // row is read; then the phone seals what is still plain
    try {
      await mediaNamesAtOpen(_db!, container, p.dirname(path));
    } catch (e) {
      dlog('media names: not all renamed (${e.runtimeType})');
    }
    containerSettled?.call(container);
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
// the file. the cost is a few percent on writes. a journal or wal left
// behind is cut back to nothing, so it keeps no old pages either
Future<void> eraseFreedPages(DatabaseExecutor db) async {
  await db.rawQuery('PRAGMA secure_delete = 1');
  await db.rawQuery('PRAGMA journal_size_limit = 0');
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

// the upgrade to 87: a contact's or a member's word that their phone plays
// opus voice notes, beside the rest of the chat's state, so it moves, ends
// and goes with it
Future<void> opusColumns(DatabaseExecutor db) async {
  for (final table in const ['contacts', 'group_members']) {
    await addColumn(
      db,
      'ALTER TABLE $table ADD COLUMN $kOpusCol INTEGER NOT NULL DEFAULT 0',
    );
  }
}

// the upgrade to 88: what a contact's phone has said it understands, and
// when by their clock (capsAfter)
Future<void> capsColumns(DatabaseExecutor db) async {
  await addColumn(
    db,
    "ALTER TABLE contacts ADD COLUMN caps TEXT NOT NULL DEFAULT ''",
  );
  await addColumn(
    db,
    'ALTER TABLE contacts ADD COLUMN caps_at INTEGER NOT NULL DEFAULT 0',
  );
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

// a photo sent as a spoiler: blurred on both ends until it is tapped
Future<void> spoilerColumn(DatabaseExecutor db) => addColumn(
  db,
  'ALTER TABLE messages ADD COLUMN spoiler INTEGER NOT NULL DEFAULT 0',
);

// a chat's own flame timer: null until one is set there, 0 off, else how
// many seconds its messages live
Future<void> chatBurnColumns(DatabaseExecutor db) async {
  await addColumn(db, 'ALTER TABLE contacts ADD COLUMN chat_burn INTEGER');
  await addColumn(db, 'ALTER TABLE groups ADD COLUMN chat_burn INTEGER');
}

// a row of ours sent without sound, so its retry goes quietly too. made at
// open, not by a version step: a file of any number gets it once
Future<void> silentColumnAtOpen(DatabaseExecutor db) async {
  final cols = await db.rawQuery('PRAGMA table_info(messages)');
  if (cols.any((c) => c['name'] == 'silent')) return;
  await addColumn(
    db,
    'ALTER TABLE messages ADD COLUMN silent INTEGER NOT NULL DEFAULT 0',
  );
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
      reached_until INTEGER,
      opened_id TEXT,
      opened_plain TEXT
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

// a chat's unsent words, under its wallKey, and a timed chat's clock for
// them. a table that will not make costs only the drafts: their reads and
// writes give up quietly, and a vault move goes on without it
Future<void> draftsTable(DatabaseExecutor db) async {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drafts (
        chat TEXT PRIMARY KEY,
        body TEXT NOT NULL,
        reply_to TEXT,
        updated_at INTEGER NOT NULL,
        burn_secs INTEGER
      )
    ''');
    for (final (table, key) in const [
      ('contacts', 'old.halo_id'),
      ('groups', "'group:' || old.group_id"),
    ]) {
      await db.execute(
        'CREATE TRIGGER IF NOT EXISTS drafts_${table}_gone AFTER DELETE ON '
        '$table BEGIN DELETE FROM drafts WHERE chat = $key; END',
      );
    }
  } catch (e) {
    dlog('drafts: no table (${e.runtimeType})');
  }
}

// a photo no chat here says it shows: one written for a row that went or
// was replaced whole (INSERT OR REPLACE fires no delete trigger). the
// default ('') and the dim (kDimWall) are never a chat's
@visibleForTesting
const kOrphanWallpapers =
    "chat <> '' AND chat <> '$kDimWall' AND NOT EXISTS "
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

// one store's tables. under a prefix, another store in the same database.
// every row names the identity it belongs to (identities.id, 0 the main
// one); the prekey tables also say what each key is for: 'invite' (with
// the invite's id, '' for the main one), 'session' or 'heal'
Future<void> _signalTables(
  DatabaseExecutor db, {
  String prefix = '',
  // each statement as it runs, or null to skip it (a rebuild, _identColumns)
  String? Function(String sql)? as,
}) async {
  Future<void> x(String sql) async {
    final run = as == null ? sql : as(sql);
    if (run != null) await db.execute(run);
  }

  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}prekeys (ident INTEGER NOT NULL DEFAULT 0, id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (ident, id))',
  );
  await x(
    "CREATE TABLE IF NOT EXISTS ${prefix}signed_prekeys (ident INTEGER NOT NULL DEFAULT 0, id INTEGER NOT NULL, record BLOB NOT NULL, created_at INTEGER NOT NULL, use TEXT NOT NULL DEFAULT 'invite', invite_id TEXT NOT NULL DEFAULT '', retired_at INTEGER, PRIMARY KEY (ident, id))",
  );
  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}sessions (ident INTEGER NOT NULL DEFAULT 0, address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (ident, address, device_id))',
  );
  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}peer_identities (ident INTEGER NOT NULL DEFAULT 0, address TEXT NOT NULL, identity_key BLOB NOT NULL, PRIMARY KEY (ident, address))',
  );
  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  );
  await x(
    "CREATE TABLE IF NOT EXISTS ${prefix}kyber_prekeys (ident INTEGER NOT NULL DEFAULT 0, id INTEGER NOT NULL, record BLOB NOT NULL, last_resort INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, use TEXT NOT NULL DEFAULT 'invite', invite_id TEXT NOT NULL DEFAULT '', retired_at INTEGER, PRIMARY KEY (ident, id))",
  );
  // a last resort kyber key outlives its use: the base keys it opened for,
  // so a replayed opener does not build a second session on it
  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}kyber_used (ident INTEGER NOT NULL DEFAULT 0, kyber_id INTEGER NOT NULL, signed_id INTEGER NOT NULL, base_key BLOB NOT NULL, PRIMARY KEY (ident, kyber_id, base_key))',
  );
  // every opener read on a kyber key, by a fingerprint of what its mac
  // covers: one opener opens once, whatever path it comes back on
  await x(
    'CREATE TABLE IF NOT EXISTS ${prefix}opener_reads (ident INTEGER NOT NULL DEFAULT 0, kyber_id INTEGER NOT NULL, opener BLOB NOT NULL, PRIMARY KEY (ident, kyber_id, opener))',
  );
}

// the signal tables that carry an identity, with the columns each had
// before it did
const _identTables = {
  'prekeys': ['id', 'record'],
  'signed_prekeys': ['id', 'record', 'created_at'],
  'sessions': ['address', 'device_id', 'record'],
  'peer_identities': ['address', 'identity_key'],
  'kyber_prekeys': ['id', 'record', 'last_resort', 'created_at'],
  'kyber_used': ['kyber_id', 'signed_id', 'base_key'],
  'opener_reads': ['kyber_id', 'opener'],
};

// the identities this container holds: 0 the main one (its words, onion
// and face), the others with keys of their own and nothing else. each has
// its own random keys: nothing is derived from another
Future<void> identityTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS identities (
      id INTEGER PRIMARY KEY,
      kind TEXT NOT NULL,
      x_priv BLOB NOT NULL,
      reg_id INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      retired_at INTEGER,
      name TEXT,
      photo INTEGER,
      about TEXT
    )
  ''');
  // the addresses of one pair of devices: 3 from the two keys alone, as
  // every chat before 0.6; 4 with the seed the opener carried
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pairs (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      their_device INTEGER NOT NULL DEFAULT 1,
      my_device INTEGER NOT NULL DEFAULT 1,
      conv INTEGER NOT NULL,
      seed BLOB,
      PRIMARY KEY (ident, peer, their_device, my_device),
      CHECK ((conv = 3 AND seed IS NULL) OR (conv = 4 AND length(seed) = 32))
    )
  ''');
  // a random first-contact key per invite, retired with it
  await db.execute('''
    CREATE TABLE IF NOT EXISTS fc_keys (
      ident INTEGER NOT NULL,
      invite_id TEXT NOT NULL,
      sk BLOB NOT NULL,
      created_at INTEGER NOT NULL,
      retired_at INTEGER,
      PRIMARY KEY (ident, invite_id)
    )
  ''');
}

// v4 invites: a row per invite with its times (unix
// hours), its keys by id and its signed frames, with and without the
// bundle. hellos: one in, waiting for the person's accept, or one
// out, waiting for the opener to my one-time invite inside it. the hellos
// seen, by hash, for 16 days
Future<void> inviteTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS invites (
      ident INTEGER NOT NULL,
      id TEXT NOT NULL,
      kind TEXT NOT NULL,
      issued INTEGER NOT NULL,
      expires INTEGER NOT NULL,
      used_at INTEGER,
      retired_at INTEGER,
      spk_id INTEGER,
      kyber_id INTEGER,
      ec_id INTEGER,
      link BLOB NOT NULL,
      qr BLOB,
      never_expires INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (ident, id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS hellos (
      ident INTEGER NOT NULL,
      way TEXT NOT NULL,
      peer TEXT NOT NULL,
      invite_id TEXT NOT NULL,
      hello BLOB,
      fc TEXT,
      at INTEGER NOT NULL,
      once INTEGER NOT NULL DEFAULT 0,
      went_at INTEGER,
      PRIMARY KEY (ident, way, peer, invite_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS hello_seen (
      ident INTEGER NOT NULL,
      hash TEXT NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (ident, hash)
    )
  ''');
  await rosterTable(db);
}

/// each group's members' roster invites, in the container the group
/// is in. pushed (kRosterPassed and the rest): an admin's, still to go to
/// the other members or not. kept: when, by this phone's clock
Future<void> rosterTable(DatabaseExecutor db) => db.execute('''
  CREATE TABLE IF NOT EXISTS roster_invites (
    group_id TEXT NOT NULL,
    member TEXT NOT NULL,
    id TEXT NOT NULL,
    issued INTEGER NOT NULL,
    invite BLOB NOT NULL,
    pushed INTEGER NOT NULL DEFAULT 1,
    kept INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, member)
  )
''');

/// at every open: a file that took 94 before the roster invites came gets
/// their table, and a dev build's table its kept. one that has both is
/// only read
Future<void> rosterTableAtOpen(DatabaseExecutor db) async {
  final cols = await db.rawQuery("PRAGMA table_info('roster_invites')");
  if (cols.isEmpty) {
    await rosterTable(db);
  } else if (!cols.any((c) => c['name'] == 'kept')) {
    await addColumn(
      db,
      'ALTER TABLE roster_invites ADD COLUMN kept INTEGER NOT NULL DEFAULT 0',
    );
  }
}

// my identity for each contact, and their identity key (0x05 and the x
// key, hex): one contact per key
Future<void> contactIdentColumns(DatabaseExecutor db) async {
  await addColumn(
    db,
    'ALTER TABLE contacts ADD COLUMN ident INTEGER NOT NULL DEFAULT 0',
  );
  await addColumn(db, 'ALTER TABLE contacts ADD COLUMN ikey TEXT');
  await contactKeyIndex(db);
}

Future<void> contactKeyIndex(DatabaseExecutor db) => db.execute(
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_ikey ON contacts(ikey)',
);

/// the upgrade to 96: per held chat, its pq restart (pq_restart.dart):
/// [key] the identity its session runs on, when the last KDB1 went and
/// how many, when their first message opened on the pq state, and when
/// the classic states went. and on an open hello row, whether its invite
/// was one-time and when the first frame went to it (3c)
Future<void> pqRestartTables(
  DatabaseExecutor db, {
  bool upgrade = false,
}) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pq_restarts (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      key TEXT NOT NULL,
      asked_at INTEGER,
      asks INTEGER NOT NULL DEFAULT 0,
      pq_at INTEGER,
      dropped_at INTEGER,
      PRIMARY KEY (ident, peer)
    )
  ''');
  // a file made at 96 or later has them in its hellos already
  if (!upgrade) return;
  await addColumn(
    db,
    'ALTER TABLE hellos ADD COLUMN once INTEGER NOT NULL DEFAULT 0',
  );
  await addColumn(db, 'ALTER TABLE hellos ADD COLUMN went_at INTEGER');
}

/// the upgrade to 92: identities, the signal tables per identity, pairs,
/// first-contact keys and the contacts' identity keys. the main identity
/// is row 0, from the key and registration id the file holds; every
/// contact is on it, on the addresses of 0.5 (conv 3)
@visibleForTesting
Future<void> upgradeTo92(DatabaseExecutor db) async {
  for (final prefix in const ['', kDevSignalPrefix]) {
    await _identColumns(db, prefix);
  }
  await identityTables(db);
  await contactIdentColumns(db);
  final me = await db.query('identity', columns: ['x_priv'], limit: 1);
  final x = me.isEmpty ? null : _unhex(me.first['x_priv'] as String?);
  if (x != null && x.length == 32) {
    final reg = await db.query(
      'signal_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: ['regId'],
      limit: 1,
    );
    await db.insert('identities', {
      'id': 0,
      'kind': kIdentFace,
      'x_priv': x,
      'reg_id': reg.isEmpty
          ? newRegistrationId()
          : int.parse(reg.first['v'] as String),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await claimContactKeys(db);
}

// one store's tables with the identity in their keys: sqlite changes no
// primary key, so each table made before is renamed, made again, its rows
// copied in as the main identity's, and dropped. a table that has it, or
// that the store never made, is left
Future<void> _identColumns(DatabaseExecutor db, String prefix) async {
  for (final e in _identTables.entries) {
    final t = '$prefix${e.key}';
    final cols = [
      for (final c in await db.rawQuery(
        'SELECT name FROM pragma_table_info(?)',
        [t],
      ))
        '${c['name']}',
    ];
    if (cols.isEmpty || cols.contains('ident')) continue;
    // the table as a new install makes it, under a name of its own first
    final made = 'IF NOT EXISTS $t (';
    await _signalTables(
      db,
      prefix: prefix,
      as: (sql) =>
          sql.contains(made) ? sql.replaceFirst(made, '${t}_92 (') : null,
    );
    final keep = e.value.join(', ');
    await db.execute(
      'INSERT INTO ${t}_92 (ident, $keep) SELECT 0, $keep FROM $t',
    );
    await db.execute('DROP TABLE $t');
    await db.execute('ALTER TABLE ${t}_92 RENAME TO $t');
  }
}

Uint8List? _unhex(String? h) {
  if (h == null || h.length.isOdd) return null;
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final b = int.tryParse(h.substring(i * 2, i * 2 + 2), radix: 16);
    if (b == null) return null;
    out[i] = b;
  }
  return out;
}

/// the upgrade to 91: the kyber tables, and a kept first contact's opened
/// text, which signal opens once only
@visibleForTesting
Future<void> upgradeTo91(Database db) async {
  await kyberTables(db);
  // addColumn takes a column there already; anything else fails the open,
  // and the step runs again
  await addColumn(db, 'ALTER TABLE first_kept ADD COLUMN opened_id TEXT');
  await addColumn(db, 'ALTER TABLE first_kept ADD COLUMN opened_plain TEXT');
}

/// one signal store's tables under [prefix], for a store kept in a file of
/// its own, as this version keeps them: one made before has the identity
/// put in its keys, in one write
Future<void> signalStoreTables(Database db, {String prefix = ''}) =>
    db.transaction((t) async {
      await _identColumns(t, prefix);
      await _signalTables(t, prefix: prefix);
      // the main store's identity is a row (identities.dart)
      if (prefix.isEmpty) await identityTables(t);
    });

/// the kyber prekey tables of the everyday store and the dev chat's, with
/// whatever else of either store a file lacks (version 91)
Future<void> kyberTables(Database db) async {
  await _signalTables(db);
  await _devSignalTables(db);
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
