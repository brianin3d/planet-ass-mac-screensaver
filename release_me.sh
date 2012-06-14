#!/bin/bash	

_release_me_main() {
	if [ -d build/Release/PlanetAss.saver ] ; then
		cd build/Release
		local pinhead=PlanetAss.saver-$( timestamp='date +"%Y.%m.%d.%H.%M.%S"' ).zip
		zip -r ../../releases/${pinhead} PlanetAss.saver
		cd ../..
		git add releases/${pinhead}
		git commit -m "a release? oh, boy..." releases/${pinhead}
		git push
	else
		echo 'there is no "ass" in "team"'
	fi
}

_release_me_main ${*}
