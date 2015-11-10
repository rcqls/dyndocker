#!/bin/sh

DOCKER_CMD="docker"

if [ "$(which docker-machine)" != "" ];then
	DOCKER_MACHINE_NAME="default"
	if [ "$(docker-machine status ${DOCKER_MACHINE_NAME})" = "Stopped" ] || [ "$(docker-machine status ${DOCKER_MACHINE_NAME})" = "Saved" ]; then
		echo "Please start the docker machine first: docker-machine start ${DOCKER_MACHINE_NAME}"
		exit
	fi
	eval "$(docker-machine env ${DOCKER_MACHINE_NAME})"
	if [ $DOCKER_CERT_PATH = "" ]; then
		export DOCKER_CERT_PATH="$HOME/.docker/machine/machines/$DOCKER_MACHINE_NAME"
	fi
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

init_workdir() {
	DYNDOCKER_WORKDIR_FILE="$DYNDOCKER_HOME/.workdir"
	if [ -f "$DYNDOCKER_WORKDIR_FILE" ];then
		DYNDOCKER_WORKDIR=`cat $DYNDOCKER_WORKDIR_FILE`
		DYNDOCKER_CACHE_NAME=".dyndocker_cache"
		DYNDOCKER_WORKDIR_TYPE="user"
	else
		DYNDOCKER_WORKDIR="$DYNDOCKER_ROOT/dyndocker"
		DYNDOCKER_CACHE_NAME=".cache"
		DYNDOCKER_WORKDIR_TYPE="normal"
	fi
}

init_workdir

if [ "$DYNDOCKER_WORKDIR_TYPE" = "user" ] && [ ! -d "$DYNDOCKER_WORKDIR" ];then
	echo "Error: as a working directory $DYNDOCKER_WORKDIR does not exist!!!"
	exit
fi


DYNDOCKER_CACHE="${DYNDOCKER_WORKDIR}/${DYNDOCKER_CACHE_NAME}"
DYNDOCKER_HOME_DOC="$DYNDOCKER_ROOT/dyndocker"

mkdir -p ${DYNDOCKER_CACHE}


DYNDOCKER_LIBRARY="$DYNDOCKER_HOME/library"

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
check_state() {
	if [ ! -d "${DYNDOCKER_LIBRARY}/pandoc-extra" ]; then
		echo "WARNING: To use pandoc extra revealjs and s5, you need to install pandoc-extra: dyndocker get-pandoc-extra"
	fi
	if [ ! -d "$HOME/.dyntask/share/tasks" ]; then
		echo "WARNING: To use atom-dyndocker package, you need to init tasks: dyndocker init-dyntask-share"
	fi
}

check_state

create_dyndoc_container() {
	tag="latest"
	if [ "$1" != "" ]; then tag="$1"; fi
	${DOCKER_CMD} create \
		-p 7777:7777 \
		-v ${ROOT_FILE}${DYNDOCKER_WORKDIR}:/dyndoc-proj \
		-v ${ROOT_FILE}${DYNDOCKER_LIBRARY}:/dyndoc-library \
		-t -i --name dyndocker \
		rcqls/${DYNDOCKER_CONTAINER}:${tag}
}

create_pdflatex_container() {
	tag="dyntask"
	if [ "$1" != "" ] && [ "$1" != "dyntask" ]; then tag="$1"; fi
	${DOCKER_CMD} create \
		-v ${ROOT_FILE}${DYNDOCKER_WORKDIR}:/dyndoc-proj \
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

set_workdir() {
	WORKDIR="$1"
	if [ -d $WORKDIR ];then
		echo "WARNING: $DYNDOCKER_HOME/.workdir changed!"
		echo "$WORKDIR" > "$DYNDOCKER_HOME/.workdir"
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

build_image() {
	if [ "$1" = "--no-cache" ];then
		OPTS="--no-cache"
		shift
	fi
	mkdir ~/tmp/.build-image
	cd ~/tmp/.build-image
	if [ "$1" = "" ];then
		TAG="rcqls/dyndocker:latest"
		URL="git://github.com/rcqls/dyndocker.git"
		DIR="dyndocker/dockerfile"
	else 
		if [ "$1" = "julia" ];then
			TAG="rcqls/dyndocker-julia:latest"
			URL="git://github.com/rcqls/dyndocker-julia.git"
			DIR="dyndocker-julia"
		fi
		if [ "$1" = "pdflatex" ];then
			TAG="rcqls/dyndocker-pdflatex:dyntask"
			URL="git://github.com/rcqls/dyndocker-pdflatex.git"
			DIR="dyndocker-pdflatex/dyntask"
		fi
	fi
	if [ "$IMAGE" != "" ];then
		IMAGE_TGZ="${DYNDOCKER_CACHE}/$IMAGE.tar.gz"
		if [ -f "$IMAGE_TGZ" ]; then
			echo "Loading $IMAGE_TGZ" 
			${DOCKER_CMD} load -i ${IMAGE_TGZ}
		fi
	fi
	git clone --depth 1 ${URL}
	cd ${DIR}
	${DOCKER_CMD} build ${OPTS} -t ${TAG} .
	rm -fr ~/tmp/.build-image
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
		wd="${DYNDOCKER_WORKDIR}/${dirname}"
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
		/dyndoc-proj)
			dir="."
			;;
		/dyndoc-proj/*)
			dir="$(echo $dir | cut -c14-)"
			;;
		esac
		#echo "dir=$dir file=$file nb=$nb"
		for i in $(seq 1 $nb); do
			pdflatex_wrap $dir/$file.tex
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
	${DYNDOCKER_WORKDIR}/*)
		i=$(expr ${#DYNDOCKER_WORKDIR} + 2)
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
		path_file="${DYNDOCKER_WORKDIR}/$(echo $path_file | cut -c2-)"
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
	if [ "$1" = "exec" ] || [ "$1" = "" ];then
		echo 'cd $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'git clone https://github.com/rcqls/dyndoc-ruby-exec.git' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'cd dyndoc-ruby-exec;rake docker'>> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	fi
	if [ "$1" = "bin" ] || [ "$1" = "" ];then
		echo 'cd $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'git clone https://github.com/rcqls/dyndoc-ruby-install.git' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
		echo 'cp -r ./dyndoc-ruby-install/dyndoc_basic_root_structure/* /dyndoc'>> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	fi
	echo 'rm -fr $dyndoc_tmp' >> ${DYNDOCKER_CACHE}/dyndoc_update.sh
	${DOCKER_CMD} exec -ti dyndocker ${ROOT_FILE}/bin/bash -i ${ROOT_FILE}/dyndoc-proj/.cache/dyndoc_update.sh
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

create_container() {
	if [ "$1" = "--all" ];then
		create_dyndoc_container
		create_pdflatex_container
	elif [ "$1" = "pdflatex" ];then
		shift
		create_pdflatex_container $*
	else
		create_dyndoc_container $*
	fi
}

upgrade_container() {
	if [ "$1" = "" ];then
		name="dyndocker"
	elif [ "$1" = "pdflatex" ];then
		name="dyndocker-pdflatex"
	fi
	echo "stopping container $name"
	stop_container $1
	echo "removing container $name"
	remove_container $1
	echo "creating container $name"
	create_container $1
	echo "starting container $name"
	start_container $1
}

case "$cmd" in
--help)
	dyndocker_help
	;;
create | new)
	shift
	if [ "$1" = "--all" ];then
		create_dyndoc_container
		create_pdflatex_container
	elif [ "$1" = "pdflatex" ];then
		shift
		create_pdflatex_container $*
	else
		shift
		create_dyndoc_container $*
	fi
	;;
upgrade)
	shift
	if [ "$1" = "--all" ];then
		if [ "$2" != "" ] && [ -d "$2" ];then
			set_workdir $2
			init_workdir
		fi
		upgrade_container 
		upgrade_container pdflatex
	else
		upgrade_container $1
	fi
	;;
start)
	shift
	if [ "$1" = "--all" ];then
		start_container
		start_container pdflatex
	else
		start_container $*
	fi
	;;
stop)
	shift
	if [ "$1" = "--all" ];then
		stop_container
		stop_container pdflatex
	else
		stop_container $*
	fi
	;;
restart)
	shift
	if [ "$1" = "--all" ];then
		restart_container
		restart_container pdflatex
	else
		restart_container $*
	fi
	;;
remove | delete | rm)
	shift
	if [ "$1" = "--all" ];then
		remove_container
		remove_container pdflatex
	else
		remove_container $*
	fi
	;;
default)
	shift
	if [ "$1" = "" ];then
		if [ -f $DYNDOCKER_HOME/.default ];then
			echo "Default dyndocker container is $(cat $DYNDOCKER_HOME/.default)"
		else
			echo "Default container is not set!"
		fi
	else
		set_default $1
	fi
	;;
workdir| wd)
	shift
	if [ "$1" = "" ];then
		if [ -f $DYNDOCKER_HOME/.workdir ];then
			echo "Workdir is $(cat $DYNDOCKER_HOME/.workdir)"
		else
			echo "Workdir is not set!"
		fi
	else
		set_workdir $1
	fi
	;;
load-image) #put the tar.gz file inside dyndocker/.cache
	shift
	if [ "$1" = "--all" ];then
		shift
		load_image
		load_image pdflatex
	else
		load_image $*
	fi
	;;
build-image) #build the image from scratch: 
	shift
	if [ "$1" = "--all" ];then
		shift
		## --no-cache by default!
		build_image --no-cache
		build_image --no-cache pdflatex
	else
		build_image $*
	fi
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
pdflatex-complete) #OBSOLETE SOON!
	pdflatex_complete
	;;
build) #OBSOLETE SOON! REPLACED WITH TASK!
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
		${DOCKER_CMD} exec dyndocker dyn $dyn_options ${ROOT_FILE}/dyndoc-proj/$relative_filename
		;;
	esac
	;;
check-state)
	check_state
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
init-dyntask-share) #to initialize some predefined tasks (in a ruby form) useable as template 
	mkdir ~/.tmp && cd ~/.tmp && git clone --depth 1 git://github.com/rcqls/dyntask-ruby.git
	mkdir -p ~/.dyntask/share
	cp -r dyntask-ruby/share/* ~/.dyntask/share/
	rm -fr ~/.tmp
	;;
get-pandoc-extra)
	## Stuff!	
	mkdir -p ${DYNDOCKER_LIBRARY}/pandoc-extra
	cd ${DYNDOCKER_LIBRARY}/pandoc-extra
  	version="3.1.0"
  	puts "Installing reveal-js-${version}"
  	wget -O revealjs.tgz https://github.com/hakimel/reveal.js/archive/${version}.tar.gz && tar xzvf revealjs.tgz && rm revealjs.tgz 
  	puts "Installing s5-11"
  	wget -O s5.zip http://meyerweb.com/eric/tools/s5/v/1.1/s5-11.zip && mkdir -p s5-tmp && unzip -d s5-tmp s5.zip && mv s5-tmp/ui s5-ui && rm s5.zip && rm -fr s5-tmp
	;;
test)
	shift
	relative_path_from_dyndocker_home /Users/remy/dyndocker/demo/first.dyn
	#complete_path $*
	;;
*)
	docker $*
esac
