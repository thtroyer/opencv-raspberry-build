#!/bin/bash

### Defaults ###
auto=false
threads=1
default_command="all"

### Config ###

opencv_version="3.2.0"

### Usage ###
usage() {
    echo "
usage: ./build.sh [options] [command]

Note -- script should be run only when in the same directory as the script.

Available commands:
    all - run all of the following, in order.
    update - download updates and build dependencies (via apt-get)
    download - download and decompress source code
    build - run the configure and build steps
    install - install opencv globally

Available options:
--auto - No \"Are you sure\" questions.
--threads n  - execute the build process with n number of threads.  1 is recommended due to opencv stability issues with multiple threads running.
--usage - show this text.

Examples:
./build.sh all  (runs all steps)
./build.sh build --threads 2  (runs the build step only with 2 threads (update and download need to already have been run)
    "

    exit 0
}

### Get arguments using getopt###
getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "I’m sorry, `getopt --test` failed in this environment."
    exit 1
fi

SHORT=aft:u
LONG=auto,threads:,usage

PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    exit 2
fi

eval set -- "$PARSED"

while true; do
    case "$1" in
        -a|--auto)
            auto=true
            shift
            ;;
        -t|--threads)
            threads="$2"
            shift 2
            ;;
        -u|--usage)
            usage
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            shift
            echo "Internal error"
            exit 3
            ;;
    esac
done

if [[ $# -ne 1 ]]; then
    read -p "No command given.  Did you want to run all steps for global installation (y/n)? " choice
    case "$choice" in 
        y|Y ) 
            echo 
            ;;
        n|N ) 
            usage
            exit 1
            ;;
        * ) 
            echo "Invalid choice."
            usage
            exit 1
            ;;
    esac
fi

### WARNING ###
echo "Designed for only for Raspberry Pis running Raspbian Jessie."
echo "This script is in active development and may contain bugs."
echo "Please ensure all your files are backed up before continuing."
echo "--------------------------------------------------------------"
echo

if [ "$auto" = false ]; then
    read -p "Continue (y/n)? " choice
    case "$choice" in 
        y|Y ) 
            echo 
            ;;
        n|N ) 
            exit 1
            ;;
        * ) 
            echo "Invalid choice."
            exit 1
            ;;
    esac
fi

### Defining functions ###
main() {
    command=$1
    threads=$2

    case "$command" in
        all)
            update
            get_dependencies
            download
            expand
            configure
            build $threads
            install
            ;;
        update)
            update
            get_dependencies
            ;;
        download)
            download
            expand
            ;;
        build)
            configure
            build $threads
            ;;
        install)
            install
            ;;
    esac
}

update() {
    ### system upgrade ###
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get upgrade --yes
}

get_dependencies() {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install --yes build-essential cmake pkg-config libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev libgtk2.0-dev libgstreamer0.10-0-dbg libgstreamer0.10-0 libgstreamer0.10-dev libv4l-0 libv4l-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libatlas-base-dev gfortran python-numpy python-scipy python-matplotlib default-jdk ant libgtkglext1-dev v4l-utils 

    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
    sudo apt install python2.7-dev
    sudo pip install numpy
}

download() {
    echo 'Downloading opencv source'

    ### Get opencv ###
    wget -O opencv.zip https://github.com/opencv/opencv/archive/"$opencv_version".zip
    ### Get opencv_contrib ###
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/"$opencv_version".zip
}

expand() {
    echo 'Expanding source code'
    unzip opencv.zip
    unzip opencv_contrib.zip
}

configure() {
    echo 'Configuring opencv'

    cd $PWD/opencv-3.2.0/
    mkdir build
    cd build
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D INSTALL_C_EXAMPLES=OFF \
        -D INSTALL_PYTHON_EXAMPLES=ON \
        -D OPENCV_EXTRA_MODULES_PATH=$PWD/../../opencv_contrib-3.2.0/modules \
        -D BUILD_EXAMPLES=ON \
        -D ENABLE_NEON=ON ..

    cd ..
    cd ..
}

build() {
    threads=$1
    echo "Building with $threads thread(s)."

    cd $PWD/opencv-3.2.0/
    cd build

    threadArg="-j$threads"

    make "$threadArg"

    cd ..
    cd ..
}

install() {
    echo 'Installing opencv to system.'
    sudo make install
}

#todo implement cleanup()
#todo implement uninstall()

### End function definitions ###

### Execute command
command=$1
main $command $threads
