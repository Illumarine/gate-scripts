ROOT_I386=/root/Desktop/illumos-gate/proto/root_i386
cd ~
git clone https://github.com/illumarine/4th
cp ~/4th/illumarine-brand.png "$ROOT_I386/boot"
cp ~/4th/illumarine-logo.png "$ROOT_I386/boot"
cp ~/4th/brand-illumarine.png "$ROOT_I386/boot/forth"
cp ~/4th/logoillumarine.png "$ROOT_I386/boot/forth"
cp ~/4th/loader.conf "$ROOT_I386/boot"
