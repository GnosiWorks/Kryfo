import sys
s = open('my_halo_screen.dart', encoding='utf-8').read()
orig = s

if 'my id is' in s:
    print('share-text: already applied'); sys.exit(0)

# anchor on the minimal stable bit: Share.share(\n <ws> _uri!,
old = "Share.share(\n              _uri!,\n              subject: 'add me on halo',\n            );"
new = ('Share.share(\n'
       '              "add me on halo. my id is ${appState.myId}\\n\\n"\n'
       '              "tap to add me:\\n$_uri\\n\\n"\n'
       '              "halo is a private messenger. no phone number, no email.",\n'
       "              subject: 'add me on halo',\n"
       '            );')
n = s.count(old)
if n == 1:
    s = s.replace(old, new, 1); print('share-text: ok')
else:
    print(f'share-text: MISS ({n})'); sys.exit(1)

open('my_halo_screen.dart', 'w', encoding='utf-8').write(s)
print('sharetext2 ok')
