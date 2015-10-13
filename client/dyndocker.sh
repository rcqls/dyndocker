#!/bin/sh

DOCKER_CMD="docker"

if [ "$(which docker-machine)" != "" ];then
	DOCKER_MACHINE_NAME="default"
	eval "$(docker-machine env ${DOCKER_MACHINE_NAME})"
	#DOCKER_CMD="docker $(docker-machine config ${DOCKER_MACHINE_NAME})"
fi

ROOT_FILE=""

case "$(uname)" in
MINGW*)
	ROOT_FILE="/"
	;;
esac

# This allows us to change the root of dyndocker
# Useful when using VBox for Win and MacOSX by working inside the Virtual Box
# at the same place than outside the Virtual Box
DYNDOCKER_ROOT_FILE="$HOME/.dyndocker_root"
if [ -f "$DYNDOCKER_ROOT_FILE" ];then
	DYNDOCKER_ROOT=`cat $DYNDOCKER_ROOT_FILE`
else
	DYNDOCKER_ROOT="$HOME"
fi

echo "DYNDOCKER_ROOT=$DYNDOCKER_ROOT"

DYNDOCKER_HOME="$DYNDOCKER_ROOT/.dyndocker"
DYNDOCKER_HOME_DOC="$DYNDOCKER_ROOT/dyndocker"
DYNDOCKER_CACHE="${DYNDOCKER_HOME_DOC}/.cache"

mkdir -p ${DYNDOCKER_CACHE}


DYNDOCKER_LIBRARY="$DYNDOCKER_HOME/library"

if [ ! -d "$DYNDOCKER_HOME_DOC" ]; then
	mkdir -p "$DYNDOCKER_HOME_DOC"
fi
if [ ! -d "$DYNDOCKER_LIBRARY" ];then
	mkdir -p "$DYNDOCKER_LIBRARY"
fi

DYNDOCKER_DEFAULT_CONTAINER="$DYNDOCKER_HOME/.default"

if [ -f "$DYNDOCKER_DEFAULT_CONTAINER" ];then
	DYNDOCKER_CONTAINER=`cat $DYNDOCKER_DEFAULT_CONTAINER`
else 
	DYNDOCKER_CONTAINER="dyndocker"
fi

cmd="$1"

if [ "$cmd" = "" ]; then
	cmd="--help"
fi

# see https://www.wanadev.fr/docker-vivre-avec-une-baleine-partie-2/
# no more use of "docker run -d" but "docker create" and then docker start|stop|restart

create_dyndoc_container() {
	tag="latest"
	if [ "$1" != "" ]; then tag="$1"; fi
	${DOCKER_CMD} create \
		-p 7777:7777 \
		-v ${ROOT_FILE}${DYNDOCKER_HOME_DOC}:/dyndoc-proj \
		-v ${ROOT_FILE}${DYNDOCKER_LIBRARY}:/dyndoc-library \
		-t -i --name dyndocker \
		rcqls/${DYNDOCKER_CONTAINER}:${tag}
}

create_pdflatex_container() {
	tag="latest"
	if [ "$1" != "latest" ]; then tag="$1"; fi
	${DOCKER_CMD} create \
		-v ${ROOT_FILE}${DYNDOCKER_HOME_DOC}:/dyndoc-proj \
		-t -i --name dyndocker-pdflatex \
		rcqls/dyndocker-pdflatex:${tag}

	create_pdflatex_wrap
}

remove_container() {
	if [ "$1" = "" ];then
		CONTAINER="dyndocker"
	else 
		if [ "$1" = "pdflatex" ];then
			CONTAINER="dyndocker-pdflatex"
		fi
	fi
	if [ "$CONTAINER" != "" ];then
		${DOCKER_CMD} stop $CONTAINER
		${DOCKER_CMD} rm $CONTAINER
	fi
}

set_default() {
	if [ "$1" = "dyndocker-julia" ] || [ "$1" = "dyndocker" ] ;then
		DEFAULT="$1"
	fi
	if [ "$DEFAULT" != "" ]; then
		echo "WARNING: $DYNDOCKER_HOME/.default changed!"
		echo "$DEFAULT" > "$DYNDOCKER_HOME/.default"
	fi
}

load_image() {
	if [ "$1" = "" ];then
		IMAGE="dyndocker"
		set_default "dyndocker"
	else 
		if [ "$1" = "julia" ];then
			IMAGE="dyndocker-julia"
			set_default "dyndocker-julia"
		fi
		if [ "$1" = "pdflatex" ];then
			IMAGE="dyndocker-pdflatex"
		fi
	fi
	if [ "$IMAGE" != "" ];then
		IMAGE_TGZ="${DYNDOCKER_CACHE}/$IMAGE.tar.gz"
		if [ -f "$IMAGE_TGZ" ]; then
			echo "Loading $IMAGE_TGZ" 
			${DOCKER_CMD} load -i ${IMAGE_TGZ}
		fi
	fi
}


start_container() {
	if [ "$1" = "" ];then
		CONTAINER="dyndocker"
	else 
		if [ "$1" = "pdflatex" ];then
			CONTAINER="dyndocker-pdflatex"
		fi
	fi
	if [ "$CONTAINER" != "" ];then
		${DOCKER_CMD} start $CONTAINER
	fi
}

stop_container() {
	if [ "$1" = "" ];then
		CONTAINER="dyndocker"
	else 
		if [ "$1" = "pdflatex" ];then
			CONTAINER="dyndocker-pdflatex"
		fi
	fi
	if [ "$CONTAINER" != "" ];then
		${DOCKER_CMD} stop $CONTAINER
	fi
}

restart_container() {
	if [ "$1" = "" ];then
		CONTAINER="dyndocker"
	else 
		if [ "$1" = "pdflatex" ];then
			CONTAINER="dyndocker-pdflatex"
		fi
	fi
	if [ "$CONTAINER" != "" ];then
		${DOCKER_CMD} restart $CONTAINER
	fi
}

create_pdflatex_wrap() {
	# the following wrapper allows us to compile a file giving its name relatively to the dyndocker home root
	echo "Create pdflatex wrapper to use inside container"
	echo '#!/bin/bash' > ${DYNDOCKER_CACHE}/pdflatex.sh
	echo 'filename="${@: -1}";dirname=`dirname ${filename}`;basename=`basename ${filename} .tex`;length=$(($#-1));pdflatex_options="${@:1:$length}"' >> ${DYNDOCKER_CACHE}/pdflatex.sh
	echo 'cd /dyndoc-proj/$dirname' >> ${DYNDOCKER_CACHE}/pdflatex.sh
	echo 'pdflatex $pdflatex_options $basename' >> ${DYNDOCKER_CACHE}/pdflatex.sh
}

awk_last() {
	last=$(echo "$*" | awk '{print $NF;}' -)
	echo $last
}

awk_head() {
	head=$(echo "$*" | awk '{$NF=""; print $0}' -)
	echo $head
}

test_awk_last() {
	filename=$(awk_last $*)
	echo $filename
}

pdflatex_wrap() {
	filename=$(awk_last $*) 
	dirname=`dirname ${filename}`
	basename=`basename ${filename} .tex`
	pdflatex_options=$(awk_head $*) #all but last
	if [ "$(which pdflatex)" = "" ]; then
		${DOCKER_CMD} exec -ti dyndocker-pdflatex ${ROOT_FILE}/bin/bash -i ${ROOT_FILE}/dyndoc-proj/.cache/pdflatex.sh $pdflatex_options $filename
	else
		owd="$(pwd)"
		wd="${DYNDOCKER_HOME_DOC}/${dirname}"
		cd ${wd}
		pdflatex ${pdflatex_options} ${basename}
		cd "${owd}"
	fi
}

awk_tasks() {
	tasks=$(echo "$*" | awk 'BEGIN{ORS=" "}{n=split($0,a,",");for(;i++<n;) {print a[i];}}' -)
	echo $tasks
}

test_awk_tasks() {
	tasks=$(awk_tasks $*)
	for t in $tasks; do
		echo "task $t"
	done
}

test_tasks() {
	var="/dyndoc-proj/demo;first;1"
	oldIFS=$IFS
	IFS=";"
	set -- $var
	echo "$1"
	echo "$2"
	echo "$3"      # Note: if more than $9 you need curly braces e.g. "${10}"
	IFS=$oldIFS
}

pdflatex_complete() {
	task=`cat ${DYNDOCKER_CACHE}/task_latex_file`
	#echo "task is $task"
	tasks=$(awk_tasks $task)
	oldIFS=$IFS
	for t in $tasks; do
		echo "task $t"
		#IFS=';' read dir file nb <<< "$t"
		var="$t"
		IFS=";"
		set -- $var
		dir="$1"
		file="$2"
		nb="$3"
		#
		case $dir in
			/dyndoc-proj/*)
			dir="$(echo $dir | cut -c14-)"
			;;
		esac
		#echo "dir=$dir file=$file nb=$nb"
		for i in $(seq 1 $nb); do
			pdflatex_wrap ${ROOT_FILE}$dir/$file.tex
		done
	done
	IFS=$oldIFS
}

# From: http://stackoverflow.com/questions/17577093/how-do-i-get-the-absolute-directory-of-a-file-in-bash
readLink() {
  # (
  # cd $(dirname $1)         # or  cd ${1%/*}
  # echo $PWD/$(basename $1) # or  echo $PWD/${1##*/}
  # )
{ # this is my bash try block

    cd $(dirname $1) > /dev/null 2>&1 &&
    #save your output
    echo $PWD/$(basename $1)
} || { # this is catch block
    # save log for exception
    echo "_Error_"
}

}

relative_path_from_dyndocker_home() {
	path_file="$(readLink $1)"
	# DEBUG: echo "rel_path=$path_file"
	case $path_file in
	${DYNDOCKER_HOME_DOC}/*)
		i=$(expr ${#DYNDOCKER_HOME_DOC} + 2)
		path_file="$(echo $path_file | cut -c${i}-)"
		;;
	esac
	echo "$path_file"
}

complete_path() {
	path_file="$1"
	ext="$2"
	#echo $path_file
	case $path_file in
	%*)
		path_file="${DYNDOCKER_HOME_DOC}/$(echo $path_file | cut -c2-)"
		;;
	esac
	#echo "path_file=$path_file"
	#echo $ext
	dirname=`dirname ${path_file}`
	basename=`basename ${path_file} $ext`
	#DEBUG: echo "filename=${dirname}/${basename}$ext"
	if [ -f "${dirname}/${basename}$ext" ]; then
		#DEBUG: echo "complete_path: $path_file"
		path_file=$(relative_path_from_dyndocker_home ${path_file})
		#DEBUG: echo $path_file
		case $path_file in
		"/*")
			echo "_Error_File $path_file is not a proper filename"
			;;
		*)
			echo "$path_file"
		esac
	else
		echo "_Error_File ${dirname}/${basename}$2 does not exists"
	fi
}

update_dyndoc() {
	echo "dyndoc_tmp=/.dyndoc_install_tmp" > ${DYNDOCKER_CACHE}/dyndoc_update.sh
	echo 'mkdir -p $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	#echo 'echo GEM_PATH=$GEM_PATH' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	if [ "$1" = "core" ] || [ "$1" = "" ];then
		echo 'cd $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'git clone https://github.com/rcqls/dyndoc-ruby-core.git' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'cd dyndoc-ruby-core;rake docker'>> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	fi
	if [ "$1" = "doc" ] || [ "$1" = "" ];then
		echo 'cd $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'git clone https://github.com/rcqls/dyndoc-ruby-doc.git' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'cd dyndoc-ruby-doc;rake docker'>> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	fi
	if [ "$1" = "bin" ] || [ "$1" = "" ];then
		echo 'cd $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'git clone https://github.com/rcqls/dyndoc-ruby-install.git' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'cp -r ./dyndoc-ruby-install/dyndoc_basic_root_structure/* /dyndoc'>> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	fi
	echo 'rm -fr $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	${DOCKER_CMD} exec -ti dyndocker ${ROOT_FILE}/bin/bash -i /dyndoc-proj/.cache/dyndoc_update.sh
}

dyndocker_help() {
	echo "dyndocker [cmd] [options]"
	echo "Different choices of <cmd> are:"
	echo "-> for use inside container:"
	echo "   ------------------------"
	echo "	-> dyndocker build <relative_path_from_dyndocker_home/dyn_file>"
	echo "	-> dyndocker pdflatex <relative_path_from_dyndocker_home/tex_file>"
	echo "	-> dyndocker bash: open a bash inside the default container"
	echo "-> for container maintenance:"
	echo "   -------------------------"
	echo "	-> dyndocker [start|stop|restart] [pdflatex]: to start, stop or restart dyndocker (or pdflatex) container"
	echo "	-> dyndocker default [container]: set or get default dyndocker container name"
	echo "	-> dyndocker new [pdflatex]: create the default or pdflatex container"
	echo "	-> dyndocker rm [pdflatex]: remove the default or pdflatex container"
	echo "-> for updates:"
	echo "    ----------"
	echo "	-> dyndocker update-client: to update the current dyndocker client"
	echo "	-> dyndocker update-dyndoc [core|doc|bin]: to update dyndoc-ruby core, doc and bin"
}

case "$cmd" in
--help)
	dyndocker_help
	;;
create | new)
	shift
	if [ "$1" = "pdflatex" ];then
		shift
		create_pdflatex_container $*
	else
		create_dyndoc_container $*
	fi
	;;
start)
	shift
	start_container $*
	;;
stop)
	shift
	stop_container $*
	;;
restart)
	shift
	restart_container $*
	;;
remove | delete | rm)
	shift
	remove_container $*
	;;
default)
	shift
	if [ "$1" = "" ];then
		echo "Default dyndocker container is $(cat $DYNDOCKER_HOME/.default)"
	else
		set_default $1
	fi
	;;
load-image) #put the tar.gz file inside dyndocker/.cache
	shift
	load_image $*
	;;
R | irb  | gem | ruby | dpm) 
	shift
	${DOCKER_CMD} exec -ti dyndocker $cmd $*
	;;
bash)
	${DOCKER_CMD} exec -ti dyndocker ${ROOT_FILE}/bin/bash
	;;
pdflatex)
	shift
	if [ "$1" = "" ]; then
		${DOCKER_CMD} exec -ti dyndocker-pdflatex ${ROOT_FILE}/bin/bash
	else
		pdflatex_wrap $*
	fi
	;;
build)
	shift
	filename="$(awk_last $*)" 
	# dirname=`dirname ${filename}`
	# basename=`basename ${filename} .dyn`
	dyn_options="$(awk_head $*) " #all but last
	relative_filename=$(complete_path ${filename} .dyn)
	case "$relative_filename" in
	_Error_*)
		echo "ERROR: $(echo $relative_filename | cut -c8-)"
		;;
	*)
		${DOCKER_CMD} exec dyndocker dyn --docker $dyn_options ${ROOT_FILE}/dyndoc-proj/$relative_filename
		pdflatex_complete
		;;
	esac
	;;
update-client)
	old="$(pwd)"
	cd "$DYNDOCKER_HOME/install/dyndocker"
	git pull
	cp client/dyndocker.sh ../../bin/dyndocker
	cd $old
	;;
update-dyndoc)
	shift
	update_dyndoc $1
	;;
update-pdflatex-wrap)
	create_pdflatex_wrap
	;;
test)
	shift
	relative_path_from_dyndocker_home /Users/remy/dyndocker/demo/first.dyn
	#complete_path $*
	;;
*)
	docker $*
esac
