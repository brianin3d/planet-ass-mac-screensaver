#!/bin/bash	

_runme_main() {
	xcodebuild && open ./build/Release/PlanetAss.saver
}

_runme_main ${*}
