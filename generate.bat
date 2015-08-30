Tools\pretzel bake --destination ..\mrmdavidson.github.io.output\
pushd ..\mrmdavidson.github.io.output
git commit -am "Generated site"
git push
popd