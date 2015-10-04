#!/bin/sh
DYNDOCKER_HOME="${HOME}/dyndocker"
DYNDOCKER_ROOT="${HOME}/.dyndocker"
DYNDOCKER_INSTALL="${DYNDOCKER_ROOT}/install"

mkdir -p ${DYNDOCKER_HOME}
mkdir -p ${DYNDOCKER_ROOT}/library/{R,dyndoc,ruby}
mkdir -p ${DYNDOCKER_ROOT}/bin
mkdir -p ${DYNDOCKER_INSTALL}

cd ${DYNDOCKER_INSTALL}
git clone https://github.com/rcqls/dyndocker.git
cp dyndocker/client/dyndocker.sh ${DYNDOCKER_ROOT}/bin/dyndocker
chmod u+x ${DYNDOCKER_ROOT}/bin/dyndocker

echo "To finalize your installation, add in your .bash_profile (or equivalent):"
echo "export PATH=\${PATH}:${DYNDOCKER_ROOT}/bin"
read -p "Do you want to do it now? Add ${DYNDOCKER_HOME}/bin to your PATH? [1=~/.profile,*=No]" -n 1 -r
echo    # (optional) move to a new line
case "$REPLY" in
1)   
    rcFile=".profile"
    echo "WARNING: if you have a linux system, maybe you'll need to reopen your windows manager!"
    ;;
*)
    ""
	;;
esac
if [[ "${rcFile}" != "" ]]
then
	echo "" >> ${HOME}/${rcFile}
    echo "## added automatically when installing dyndocker" >>  ${HOME}/${rcFile}
    echo "export PATH=\${PATH}:${DYNDOCKER_ROOT}/bin" >> ${HOME}/${rcFile}
    . ${HOME}/${rcFile}
fi


