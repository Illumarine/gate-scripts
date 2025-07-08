# This file is more of a guide for building Illumarine's illumos-gate.
# * Requires Git to be installed.
# * Requires build-essential on OpenIndiana or illumos-tools on OmniOS
# * Only tested on OpenIndiana at the moment
git clone https://github.com/Illumarine/illumos-gate
cd illumos-gate
cp ./usr/src/tools/env/illumos.sh . # No modifications to the shell script are made (yet)
time ./usr/src/tools/scripts/nightly illumos.sh
cd -
