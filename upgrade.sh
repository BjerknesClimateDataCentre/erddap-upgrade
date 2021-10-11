#!/bin/bash
#
# script to upgrade ERDDAP release
#
# -----------
# Default value
# -----------
server='bluecloud.icos-cp.eu'
erddap='2.14'
tomcat='9.0.41'
verbo=false
install=false
undo=false
#
tstep=5

# ---------------
# useful function
# ---------------
pause ()
{
   echo " to confirm, press : ENTER"
   echo " to cancel,  press : CTRL C"
   read
}

show_help()
{
   echo -e "\n usage : $(basename "$0") server [-h] [-v] [-e [RELEASE]] [-a [REALEASE]]\n"
   echo -e " positional arguments :"
   echo -e "\tserver                   server name"
   echo -e " optional arguments :"
   echo -e "\t-h, --help                 : show this help message"
   echo -e "\t-v, --verbose              : activate verbose mode"
   echo -e "\t-e, --erddap    [RELEASE]  : erddap        release to installed [default $erddap]"
   echo -e "\t-t, --tomcat    [RELEASE]  : apache-tomcat release to installed [default $tomcat]"
   echo -e "\t-i, --install              : install this new release [default $install]"
   echo -e "\t-u, --undo                 : uninstall current release and back to pevious release    [default $undo]"
   echo -e "\n Note: by default the new release is installed in a tmp directory."
   echo -e   "       So you could check everythings before rerun the script to really install this release."
   echo -e "\n Examples:"
   echo -e "\t./$(basename "$0") bluecloud.icos-cp.eu --erddap $erddap --tomcat $tomcat"
   echo -e "\t./$(basename "$0") erddap.icos-cp.eu    --erddap $erddap --tomcat $tomcat"
}


show_usage()
{
   echo -e "$(basename "$0") $@"
   echo -e "\nYou want to install:"
   echo -e "\terrdap: $erddap"
   echo -e "\tapache-tomcat: $tomcat"
   echo -e "\ton $server"
}

get_crtime()
{
   # return create date
   target="$1"
   # for target in "${@}"; do
   inode=$(stat -c '%i' "${target}")
   fs=$(df  --output=source "${target}"  | tail -1)
   crtime=$(sudo debugfs -R 'stat <'"${inode}"'>' "${fs}" 2>/dev/null | grep -oP 'crtime.*--\s*\K.*')
   printf "%s" "${crtime}"
   echo ${crtime}
   # printf "%s\t%s\n" "${target}" "${crtime}"
   # done
}

get_date()
{
   if [ -f ${1}/ERDDAP-RELEASE.md ] ; then
      # date of installation
      d=$(sed -n '2p' ${1}/ERDDAP-RELEASE.md | cut -d' ' -f1)
   else
      # unknown date
      d="XXX-XX-XX"
   fi
   echo $d
}

# look for help argument first, to not overwrite default value
[[ "$@" != "${@/--help/}" ]] && { show_help ; exit 0 ;}
[[ "$@" != "${@/-h/}"     ]] && { show_help ; exit 0 ;}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
   key="$1"
   case $key in
      -v|--verbose)
         verbo=true
         shift # past argument
         ;;
      -e|--erddap)
         [ "$2" != "" ] && [ "${2:0:1}" != "-" ] && { erddap=$2 ; shift ; } # past value
         shift # past argument
         ;;
      -t|--tomcat)
         [ "$2" != "" ] && [ "${2:0:1}" != "-" ] && { tomcat=$2 ; shift ; } # past value
         shift # past argument
         ;;
      -i|--install)
         install=true
         shift # past argument
         ;;
      -u|--undo)
         undo=true
         shift # past argument
         ;;
      *)    # unknown option
         POSITIONAL+=("$1") # save it in an array for later
         shift # past argument
         ;;
   esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

if [ ${#POSITIONAL[@]} -ne 1 ] ; then
   echo -e "\nUsage error: $0 $@"
   echo -e "\tArguments number (${#POSITIONAL[@]}) not correct ==> exit\n"
   show_help
   exit 1
else
   server=${POSITIONAL[0]}
fi

$verbo && show_usage

# ---------------
# Check path
# ---------------
# check server directory exist
if [[ ${server} != *"${HOME}"* ]]; then
   # echo "HOME not here! add it"
   path_server=${HOME}/${server}
else
   path_server=${server}
   server=$(basename ${server})
fi
[ -d "${path_server}" ] || { echo "Error: Directory ${path_server} does not exists."; exit 1;}

if ! ${undo} ; then
   # check erddap directory exist
   if [[ ${erddap} != *"${HOME}/Code/Erddap"* ]]; then
      # echo "${HOME}/Code/Erddap not here! add it"
      path_erddap=${HOME}/Code/Erddap/${erddap}
   else
      path_erddap=${erddap}
      erddap=$(basename ${erddap})
   fi
   [ -d "${path_erddap}" ] || { echo "Error: Directory ${path_erddap} does not exists."; exit 1;}
   # check erddap exist
   list="erddap.war erddapContent.zip"
   for file in $list ; do
      if [ ! -f ${path_erddap}/${file} ] ; then
         # if file does not exist, exit
         { echo "Error: File ${path_erddap}/${file} does not exists."; exit 1;}
      fi
   done

   # check tomcat directory exist
   path_tomcat=${HOME}/Code/Apache-tomcat
   [ -d "${path_tomcat}" ] || { echo "Error: Directory ${path_tomcat} does not exists."; exit 1;}
   # check tomcat file exist
   suffix=".tar.gz"
   if [[ ${tomcat} == *"apache-tomcat-"*"${suffix}" ]]; then
      file_tomcat=${tomcat}
   else
      file_tomcat="apache-tomcat-${tomcat}${suffix}"
   fi
   file="${path_tomcat}/${file_tomcat}"
   if [ ! -f ${file} ] ; then
      # if file does not exist, exit
      { echo "Error: File ${file} does not exists."; exit 1;}
   fi

   # ---------------
   # keep and rename former release
   # ---------------
   old="$(readlink -f ${path_server}/apache-tomcat)"
   crtime=$(get_date ${old})
   keep="${old}_${crtime}"
   if [ -d "${keep}" ] ; then
      { echo "Error: Directory ${keep} already exists."; exit 1;}
   fi
   # ---------------
   path_tmp=${path_server}/tmp
   mkdir -p ${path_tmp}
   if [ -d ${path_tmp}/${file_tomcat%"$suffix"} ] ; then
      { echo "Error: Directory ${path_tmp}/${file_tomcat%$suffix} already exists."; exit 1;}
   fi

   fileout="${path_tmp}/upgrade.log"
   echo $(date +"%Y-%m-%d")           > ${fileout}
   echo -e "\nYou want to install:"  >> ${fileout}
   echo -e "\tERDDAP-$erddap"        >> ${fileout}
   echo -e "\tAPACHE-TOMCAT-$tomcat" >> ${fileout}
   echo -e "\ton $server"            >> ${fileout}
   # ---------------
   # deploy a new version of apache-tomcat-xx (here after [tomcat]) in [server]
   # ---------------
   cp ${path_tomcat}/${file_tomcat} ${path_tmp}
   gzip -d ${path_tmp}/${file_tomcat}
   tar -xf ${path_tmp}/${file_tomcat%".gz"} -C ${path_tmp}
   # clean
   rm ${path_tmp}/${file_tomcat%".gz"}
   #
   new=${path_tmp}/${file_tomcat%"$suffix"}
   # ---------------
   # deploy a new version of ERDDAP-X.XX
   # ---------------
   #
   if [[ ${server} == *"localhost"* ]]; then
      cp    ${path_erddap}/erddap.war           ${new}/webapps/erddap.war
   else
      rm -rf ${new}/webapps/ROOT
      cp    ${path_erddap}/erddap.war           ${new}/webapps/ROOT.war
   fi
   unzip ${path_erddap}/erddapContent.zip -d ${new}                  > /dev/null 2>&1

   # ---------------
   # copy/create ERDDAP-RELEASE
   # ---------------
   if [ ! -f ${old}/ERDDAP-RELEASE.md ] ; then
      # no ERDDAP RELEASE file
      echo '# Version'          > ${new}/ERDDAP-RELEASE.md
   else
      cp ${old}/ERDDAP-RELEASE.md ${new}
   fi
   sed -i "1 a$(date +"%Y-%m-%d") ERDDAP: ${erddap}" ${new}/ERDDAP-RELEASE.md
   # ---------------
   # make sone changes in [tomcat]/bin
   # ---------------
   ln -s ${path_server}/Erddap/Custom/bin/setenv.sh ${new}/bin
   echo -e "\nCheck changes in [tomcat]/bin"  >> ${fileout}
   echo -e "\t ${new}/bin/setenv.sh"          >> ${fileout}
   # ---------------
   # make sone changes in [tomcat]/conf
   # ---------------
   echo -e "\nCheck changes in [tomcat]/conf"  >> ${fileout}
   mv ${new}/conf/context.xml ${new}/conf/context.xml.origin
   mv ${new}/conf/server.xml  ${new}/conf/server.xml.origin
   ln -s ${path_server}/Erddap/Custom/conf/context.xml ${new}/conf
   ln -s ${path_server}/Erddap/Custom/conf/server.xml  ${new}/conf
   echo -e "\tcheck diff with origin files:"                                  >> ${fileout}
   echo -e "\tvim -d ${new}/conf/context.xml ${new}/conf/context.xml.origin"  >> ${fileout}
   echo -e "\tvim -d ${new}/conf/server.xml  ${new}/conf/server.xml.origin"   >> ${fileout}
   # ---------------
   # make sone changes in [tomcat]/content
   # ---------------
   echo -e "\nCheck changes in [tomcat]/content"  >> ${fileout}
   mv ${new}/content/erddap ${new}/content/erddap.origin
   mkdir -p ${new}/content/erddap
   ln -s ${path_server}/Erddap/Custom/content/erddap/images    ${new}/content/erddap
   ln -s ${path_server}/Erddap/Custom/content/erddap/setup.xml ${new}/content/erddap
   # copy datasets.xml from older release
   if [ -f ${old}/content/erddap/datasets.xml ] ; then
      cp ${old}/content/erddap/datasets.xml ${new}/content/erddap/datasets.xml
   else
      cp ${new}/content/erddap.origin/datasets.xml ${new}/content/erddap/datasets.xml
   fi
   echo -e "\tcheck diff with origin files:"                                     >> ${fileout}
   echo -e "\tvim -d ${new}/content/erddap/setup.xml    ${new}/content/erddap.origin/setup.xml"   >> ${fileout}
   echo -e "\tvim -d ${new}/content/erddap/datasets.xml ${new}/content/erddap.origin/datasets.xml">> ${fileout}
   # ---------------
   # make sone changes in [tomcat]/logs
   # ---------------
   cp -R ${old}/logs/* ${new}/logs/.
   # ---------------
   # make sone changes in [tomcat]/webapps
   # ---------------
   # cp -R ${old}/ROOT ${new}/.

   if $install ; then
      show_usage
      pause
      # ---------------
      # shutdown apache-tomcat
      # ---------------
      ${path_server}/apache-tomcat/bin/shutdown.sh
      # wait server to get down
      sleep $tstep
      # ---------------
      # install apache-tomcat to new release
      # ---------------
      mv ${old} ${keep}
      mv ${new} ${path_server} # new path is now ${path_server}/${file_tomcat%"$suffix"}
      rm ${path_server}/apache-tomcat
      ln -sf ${path_server}/${file_tomcat%"$suffix"} ${path_server}/apache-tomcat
      # ---------------
      # restart apache-tomcat
      # ---------------
      ${path_server}/apache-tomcat/bin/startup.sh
      # clean
      rm -rf ${path_tmp}
      # # keep archive
      # rm -rf ${keep}/webapps/ROOT # save space
      # tar -czf ${keep}.tgz ${keep}
      # rm -rf ${keep}
   else
      echo -e "\nWarning: the new release is not yet installed."
      echo -e "\tyou may check changes. see ${fileout}"
      echo -e "\nformer release will be saved in  ${keep}"
   fi
else # undo
   release=${path_server}/apache-tomcat/ERDDAP-RELEASE.md
   if [ -f ${release} ] ; then
      # read second line
      d=$(sed -n '3p' ${release} | cut -d' ' -f1)
      # overwrite new release
      old=$(find ${path_server} -maxdepth 1 -name apache-tomcat-*_${d})
      new=$(readlink -f ${path_server}/apache-tomcat)
      echo "old ${old}"
      echo "new ${new}"
      if [ -d "${new}" ] ; then
         echo "You will remove former release"
         erddap=$(sed -n '2p' ${new}/ERDDAP-RELEASE.md| cut -d':' -f2)
         tomcat=$(basename ${new} | cut -d'-' -f3)
         echo -e "\terrdap: $erddap"
         echo -e "\tapache-tomcat: $tomcat"
         if [ -d "${old}" ] ; then
            echo "and reinstall release"
            erddap=$(sed -n '3p' ${new}/ERDDAP-RELEASE.md| cut -d':' -f2)
            tomcat=$(basename ${old%_${d}} | cut -d'-' -f3)
            echo -e "\terrdap: $erddap"
            echo -e "\tapache-tomcat: $tomcat"
         fi
         echo -e "\ton $server"
         pause
         # ---------------
         # shutdown apache-tomcat
         # ---------------
         ${path_server}/apache-tomcat/bin/shutdown.sh
         # wait server to get down
         sleep $tstep
         # ---------------
         # install apache-tomcat to new release
         # ---------------
         rm -rf ${new}
         if [ -d "${old}" ] ; then
            mv ${old} ${old%"_$d"}
            rm ${path_server}/apache-tomcat
            ln -sf ${old%"_$d"} ${path_server}/apache-tomcat
            # ---------------
            # restart apache-tomcat
            # ---------------
            ${path_server}/apache-tomcat/bin/startup.sh
         fi
      else
         #if [ -d ${old} ] ; then
         #   { echo "Error: can not undo. can not find directory ${old} " ; exit 1;}
         if [ -d "${new}" ] ; then
            { echo "Error: can not undo. can not find directory ${new} " ; exit 1;}
         fi
      fi
   else
      { echo "Error: can not undo. can not find ${release} " ; exit 1;}
   fi
fi
