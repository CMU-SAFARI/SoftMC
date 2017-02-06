for f in ./patches/*.patch
do
    patch -p0 < $f
done
