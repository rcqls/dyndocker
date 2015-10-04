#!/bin/sh
DYNDOCKER_ROOT=$1
if [ -d $DYNDOCKER_ROOT ]; then
	DYNDOCKER_HOME=$DYNDOCKER_ROOT/.dyndocker
	if [ -d $DYNDOCKER_HOME ]; then
		echo "$DYNDOCKER_ROOT" > ~/.dyndocker_root
		echo "To finalize your installation, add in your .profile:"
		echo "export PATH=\${PATH}:${DYNDOCKER_HOME}/bin"
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
		    echo "export PATH=\${PATH}:${DYNDOCKER_HOME}/bin" >> ${HOME}/${rcFile}
		    . ${HOME}/${rcFile}
		fi

	else
		echo "Error: $DYNDOCKER_ROOT is not a proper dyndocker root!"
	fi
fi

