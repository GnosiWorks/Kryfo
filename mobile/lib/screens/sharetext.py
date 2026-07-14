import sys
s = open('my_halo_screen.dart', encoding='utf-8').read()
orig = s

MARK = 'add me on halo'
NEW_BODY = '''          onTap: () {
            Share.share(
              "add me on halo. my id is ${appState.myId}\\n\\n"
              "tap to add me:\\n$_uri\\n\\n"
              "halo is a private messenger. no phone number, no email.",
              subject: 'add me on halo',
            );
          },'''
OLD_BODY = """          onTap: () {
            Share.share(
              _uri!,
              subject: 'add me on halo',
            );
          },"""

if 'my id is' in s:
    print('share-text: already applied')
elif s.count(OLD_BODY) == 1:
    s = s.replace(OLD_BODY, NEW_BODY, 1)
    print('share-text: ok')
else:
    print('share-text: MISS (%d)' % s.count(OLD_BODY))
    sys.exit(1)

if s != orig:
    open('my_halo_screen.dart', 'w', encoding='utf-8').write(s)
print('sharetext ok')
