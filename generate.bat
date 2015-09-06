pushd ..\mrmdavidson.github.io-master
git pull origin
popd
Tools\pretzel bake --destination ..\mrmdavidson.github.io-master\
pushd ..\mrmdavidson.github.io-master
git commit -am "Generated site"
git push origin master:master
popd