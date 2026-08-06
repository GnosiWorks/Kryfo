#!/bin/bash

go version
go env
autoconf --version
automake --version
make --version
gcc --version

echo "Building"

go run build/wrap.go --nobuild
if [ "$?" != "0" ] ; then
 echo "Error building"
 exit 1
fi

cd ..
tar cvf /tmp/go-libtor.tar go-libtor/
