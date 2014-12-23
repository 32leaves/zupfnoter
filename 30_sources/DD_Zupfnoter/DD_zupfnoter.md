# Handling google analytics

* Analytics ia applied for webserver-installation only, not for localhost nor desktop
* this is done by the method `javascript_include_analytics` which is defined in the related rake tasks.
* for localhost, the method is not defined, and therefore the template does not include the script

# build environments

## project documentation

* goto `30_source/ZSUPP_Tools`
* `rake`

## maintain the application

* goto `30_source/SRC_Zupfnoter/src`
* `rake`

## updating syntax highlighting

* goto your clone of the ace reporitory (../200_zupfnoter_external_components/ace)
* update the files as described in <http://ace.c9.io/#nav=higlighter>
* perform 

	node Makefile.dryice.js -nc -m fiull

* copy the contents of `200_zupfnoter_external_components/ace/build/src-min-noconflict` to 
`30_sources/SRC_Zupfnoter/vendor/ace`

# preparing a release

Zupfnoter uses gitflow http://nvie.com/posts/a-successful-git-branching-model/

Before preparing a release, everything that should go to this release shall be committed to the develop branch.

* start new release
* remove ".dev" from version src/version.rb
* perform all the builds
	`rake build`
* finish the release
* switch back to the develpment branch
* bump version in src/version.rb, add ".dev"

# building the desktop app

The desktop app is built based on node-webkit. The major steps to build it are described in

https://github.com/rogerwang/node-webkit/wiki/How-to-package-and-distribute-your-apps

Approach follows nodebob but uses rake to do this.

1. create the webapp
2. create zupfnoter.nw
3. create the binaries for windows and osx



