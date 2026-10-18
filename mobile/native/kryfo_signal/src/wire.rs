// SPDX-License-Identifier: GPL-3.0-or-later
// the framing every call takes and gives: fields one after another, each a
// u32 little endian length and its bytes. an empty field is an absent one,
// numbers are 4 or 8 bytes little endian

use crate::Error;

// no field the protocol has comes near this; a length past it is garbage
pub const MAX_FIELD: usize = 1 << 24;

pub struct Reader<'a> {
    rest: &'a [u8],
}

impl<'a> Reader<'a> {
    pub fn new(b: &'a [u8]) -> Self {
        Reader { rest: b }
    }

    pub fn bytes(&mut self) -> Result<&'a [u8], Error> {
        let (n, tail) = self.rest.split_first_chunk::<4>().ok_or(Error::Args)?;
        let n = u32::from_le_bytes(*n) as usize;
        if n > MAX_FIELD || n > tail.len() {
            return Err(Error::Args);
        }
        let (v, tail) = tail.split_at(n);
        self.rest = tail;
        Ok(v)
    }

    pub fn need(&mut self) -> Result<&'a [u8], Error> {
        match self.bytes()? {
            [] => Err(Error::Args),
            v => Ok(v),
        }
    }

    pub fn opt(&mut self) -> Result<Option<&'a [u8]>, Error> {
        Ok(Some(self.bytes()?).filter(|v| !v.is_empty()))
    }

    pub fn u32(&mut self) -> Result<u32, Error> {
        let v: [u8; 4] = self.bytes()?.try_into().map_err(|_| Error::Args)?;
        Ok(u32::from_le_bytes(v))
    }

    pub fn opt_u32(&mut self) -> Result<Option<u32>, Error> {
        match self.bytes()? {
            [] => Ok(None),
            v => Ok(Some(u32::from_le_bytes(
                v.try_into().map_err(|_| Error::Args)?,
            ))),
        }
    }

    pub fn u64(&mut self) -> Result<u64, Error> {
        let v: [u8; 8] = self.bytes()?.try_into().map_err(|_| Error::Args)?;
        Ok(u64::from_le_bytes(v))
    }

    #[cfg(test)]
    pub fn is_done(&self) -> bool {
        self.rest.is_empty()
    }

    // every field read, nothing left over
    pub fn end(self) -> Result<(), Error> {
        if self.rest.is_empty() {
            Ok(())
        } else {
            Err(Error::Args)
        }
    }
}

#[derive(Default)]
pub struct Writer {
    pub out: Vec<u8>,
}

impl Writer {
    pub fn bytes(&mut self, v: &[u8]) -> &mut Self {
        self.out.extend_from_slice(&(v.len() as u32).to_le_bytes());
        self.out.extend_from_slice(v);
        self
    }

    pub fn opt(&mut self, v: Option<&[u8]>) -> &mut Self {
        self.bytes(v.unwrap_or_default())
    }

    pub fn u32(&mut self, v: u32) -> &mut Self {
        self.bytes(&v.to_le_bytes())
    }

    pub fn opt_u32(&mut self, v: Option<u32>) -> &mut Self {
        match v {
            Some(v) => self.u32(v),
            None => self.bytes(&[]),
        }
    }

    #[cfg(test)]
    pub fn u64(&mut self, v: u64) -> &mut Self {
        self.bytes(&v.to_le_bytes())
    }

    pub fn done(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let b = Writer::default()
            .bytes(b"abc")
            .opt(None)
            .u32(7)
            .opt_u32(None)
            .u64(1 << 40)
            .done();
        let mut r = Reader::new(&b);
        assert_eq!(r.need().unwrap(), b"abc");
        assert_eq!(r.opt().unwrap(), None);
        assert_eq!(r.u32().unwrap(), 7);
        assert_eq!(r.opt_u32().unwrap(), None);
        assert_eq!(r.u64().unwrap(), 1 << 40);
        r.end().unwrap();
    }

    #[test]
    fn short_and_long_fail() {
        assert!(Reader::new(&[3, 0, 0, 0, 1, 2]).bytes().is_err());
        assert!(Reader::new(&[1, 0]).bytes().is_err());
        assert!(Reader::new(&[0xff, 0xff, 0xff, 0xff]).bytes().is_err());
        let mut r = Reader::new(&[0, 0, 0, 0, 9]);
        r.bytes().unwrap();
        assert!(r.end().is_err());
        assert!(Reader::new(&[2, 0, 0, 0, 1, 2]).u32().is_err());
        assert!(Reader::new(&[0, 0, 0, 0]).need().is_err());
    }
}
