# TODO: Add tests to make sure values below exist
mkisofs -o $2 \
  -b boot/cdboot \
  -c boot.catalog \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -R -J -T \
  -V "Illumarine" \
  $1
