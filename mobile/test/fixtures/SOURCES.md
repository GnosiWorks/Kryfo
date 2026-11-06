# Test files from other projects

## gopro_hero5_cut.mp4

The first second of `samples/hero5.mp4` from GoPro's GPMF parser,
https://github.com/gopro/gpmf-parser (the file as added in commit
2f54a2c11039d1fe4f7514e0f9288beb61ba3e06, sha256
04e45b2f41dff195b525fa18b7ed5517e5fc2d651127d1b57d1d931de306f915), used under the MIT licence that
project offers (it is dual licensed, Apache 2.0 or MIT). The video, sound,
timecode and GPMF tracks are kept as they were; the sample tables were cut to
the chunks before the first second's end and the file was shortened there.

```
Copyright 2017 GoPro, Inc.

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included 
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.
```

## credentials/credentials.*

Pictures signed with content credentials by c2patool 0.27.22 from
https://github.com/contentauth/c2pa-rs (MIT or Apache 2.0), with its built in
test certificate, no thumbnail, and one action: created, digital source type
trainedAlgorithmicMedia, by "Image Generator". The pictures signed were made
here (png, gif), are this folder's photo_512.jpg, motion_photo.heic and
motion_photo.avif, and for webp `examples/test.webp` from
https://github.com/webmproject/libwebp (commit
8aacc7b05621309f238742c52a0c4475a021152c, sha256
1bf9449d529b491c6eb22ec84d42217e43cf9af0ffe391fa7a30b29b037f098a, BSD 3-clause,
Copyright (c) 2010, Google Inc.).

## credentials/c2pa_dashinit.mp4

`sdk/tests/fixtures/dashinit.mp4` from https://github.com/contentauth/c2pa-rs
(commit 1a6d42c0a161af6722aa4612ef9c76f2e9c4d0aa, sha256
98932f75cc3f796ce77bbb3b7306c9e09756b099d7fd4335219eec73a9ea0bf8), used under
the MIT licence that project offers (dual licensed, MIT or Apache 2.0).
Copyright 2020 Adobe.
