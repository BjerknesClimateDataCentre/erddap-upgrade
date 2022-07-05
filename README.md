# erddap-upgrade
script to upgrade ERDDAP release

# usage
usage : upgrade.sh server [-h] [-v] [-e [RELEASE]] [-t [REALEASE]] [-i] [-u]

- positional arguments :  
    server: server name  
- optional arguments :  
    -h, --help                 : show this help message  
	-v, --verbose              : activate verbose mode  
	-e, --erddap    [RELEASE]  : erddap        release to installed [default 2.16]  
	-t, --tomcat    [RELEASE]  : apache-tomcat release to installed [default 9.0.58]  
	-i, --install              : install this new release [default false]  
	-u, --undo                 : uninstall current release and back to pevious release    [default false]  

> By default the new release is installed in a tmp directory.  
  So you could check everythings before rerun the script to really install this release.

 Examples:  
 ```bash
	./upgrade.sh erddap.localhost --erddap 2.16 --tomcat 9.0.58  
	./upgrade.sh bluecloud.icos-cp.eu --erddap 2.16 --tomcat 9.0.58  
	./upgrade.sh erddap.icos-cp.eu    --erddap 2.16 --tomcat 9.0.58  
 ```
