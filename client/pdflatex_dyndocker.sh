ROOT_FILE=""

case "$(uname)" in
MINGW*)
	ROOT_FILE="/"
	;;
esac

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