#!/bin/bash

##############################################
#                                            #
# What: This script provisions the AWS AMI   #
# ami-c86c3f23 Red Hat 7.5.                  #
# It is deploys an environment with          #
#                                            #
# - Lmod                                     #
# - EasyBuild                                #
# - Singularity 2.6.1                        #
# - Singularity 3                            #
#                                            #
# Who: Diego Lasa                            #
# When: 2019-02-14                           #
# Why: to create an AMI to train my          #
#      colleagues in the use of the tools.   #
#                                            #
##############################################


#######################################
# Clean previous installations if any #
#######################################

# If the node is not clean remove startup files

rm -f /etc/profile.d/{lmod.sh,easybuild.sh}

###########################
# Install system packages #
###########################

cd /tmp
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install epel-release-latest-7.noarch.rpm
yum -y install wget \
               vim \
               make \
	       gcc \
	       gcc-c++ \
	       glibc-static \
	       glibc.i686 \
	       make \
	       libibverbs-devel \
	       tar bzip2 gzip unzip \
	       which \
	       wget \
	       epel-release \
	       python-pip \
	       python-setuptools \
	       git \
	       patch \
	       GitPython \
	       file \
	       perl-Data-Dumper  \
	       perl-Thread-Queue \
	       libX11-devel \
	       m4 \
	       strace \
	       emacs-nox \
	       ncurses-devel \
	       tcl \
	       tk \
               squashfs-tools \
               libarchive \
               libuuid-devel \
               openssl-devel

wget http://mirror.centos.org/centos/7/os/x86_64/Packages/libarchive-devel-3.1.2-10.el7_2.x86_64.rpm
yum -y install libarchive-devel-3.1.2-10.el7_2.x86_64.rpm

# EasyBuild cannot be used by root user, so we create one to take care of this

export EASYBUILD_USER="hpc"
useradd ${EASYBUILD_USER}

##############################
# Create directory structure #
##############################

export HEAD="/scratch/scicomp"
export OS="CentOS"
export OS_VERSION="7.5.1810"

mkdir -p ${HEAD}
mkdir -p ${HEAD}/{EasyBuild/source,EasyBuild/build,EasyBuild/tmp}
mkdir -p ${HEAD}/source
mkdir -p ${HEAD}/${OS}/${OS_VERSION}/{Common/modules,Common/software,Skylake/modules,Skylake/software,Haswell/modules,Skylake/software}
chown -R ${EASYBUILD_USER}. ${HEAD}

###############
# Install Lua #
###############

export LUA_VERSION="5.1.4.5"
export LUA_DIR="$HEAD/source/Lua/${LUA_VERSION}"
export LUA_PREFIX="$HEAD/$OS/$OS_VERSION/Common/software/Lua/${LUA_VERSION}"
mkdir -p ${LUA_DIR}
cd ${LUA_DIR}
wget https://sourceforge.net/projects/lmod/files/lua-${LUA_VERSION}.tar.gz
tar -zxvf lua-${LUA_VERSION}.tar.gz
cd lua-${LUA_VERSION}
./configure --prefix=${LUA_PREFIX} && make && make install

# Set enviroment to compile Lmod
export CPATH="${LUA_PREFIX}/include:$CPATH"
export PATH="${LUA_PREFIX}/bin:$PATH"
export LD_LIBRARY_PATH="${LUA_PREFIX}/lib:$LD_LIBRARY_PATH"

################
# Install Lmod #
################

export LMOD_VERSION="7.8.18"
export LMOD_DIR="${HEAD}/source/Lmod/${LMOD_VERSION}"
export LMOD_PREFIX="${HEAD}/${OS}/${OS_VERSION}/Common/software/Lmod/${LMOD_VERSION}"
mkdir -p ${LMOD_DIR}
cd ${LMOD_DIR}
wget https://github.com/TACC/Lmod/archive/$LMOD_VERSION.tar.gz
tar -zxvf $LMOD_VERSION.tar.gz
cd Lmod-${LMOD_VERSION}
./configure --prefix=${LMOD_PREFIX} && make install

# Add path to modules to the MODULEPATH variable for the shell BASH
sed -i '28iexport MODULEPATH=$(/scratch/scicomp/CentOS/7.5.1810/Common/software/Lmod/7.8.18/lmod/lmod/libexec/addto --append MODULEPATH /scratch/scicomp/CentOS/7.5.1810/Haswell/modules/all)' ${HEAD}/${OS}/${OS_VERSION}/Common/software/Lmod/${LMOD_VERSION}/lmod/lmod/init/profile
ln -s ${HEAD}/${OS}/${OS_VERSION}/Common/software/Lmod/${LMOD_VERSION}/lmod/lmod/init/profile /etc/profile.d/lmod.sh

# Set environment to install EasyBuild
source /etc/profile.d/lmod.sh
module load lmod

#####################
# Install EasyBuild #
#####################

export EASYBUILD_VERSION="3.8.1"
export EASYBUILD_DIR="${HEAD}/source/EasyBuild/${EASYBUILD_VERSION}"
export EASYBUILD_PREFIX="${HEAD}/${OS}/${OS_VERSION}/Common/software/EasyBuild/${EASYBUILD_VERSION}"

# Configure EasyBuild
cat <<EOF >> /etc/profile.d/easybuild.sh
#!/bin/bash
export EASYBUILD_PREFIX=${HEAD}/EasyBuild
export EASYBUILD_INSTALLPATH=${HEAD}/EasyBuild/${OS}/${OS_VERSION}/Haswell
export EASYBUILD_SOURCEPATH=${HEAD}/EasyBuild/source
export EASYBUILD_INSTALLPATH_MODULES=${HEAD}/${OS}/${OS_VERSION}/Haswell/modules
export EASYBUILD_TMP_LOGDIR=${HEAD}/EasyBuild/tmp                             
export EASYBUILD_MODULES_TOOL=Lmod 
EOF

# EasyBuild boostrap procedure
cd ${EASYBUILD_DIR}
su - ${EASYBUILD_USER} -c "mkdir -p ${EASYBUILD_DIR} ${EASYBUILD_PREFIX}"
su - ${EASYBUILD_USER} -c "curl -O https://raw.githubusercontent.com/easybuilders/easybuild-framework/develop/easybuild/scripts/bootstrap_eb.py"
su - ${EASYBUILD_USER} -c "chmod 700 bootstrap_eb.py"
su - ${EASYBUILD_USER} -c "source /etc/profile.d/easybuild.sh; python bootstrap_eb.py ${EASYBUILD_PREFIX}"

#############################
# Install Singularity 2.6.1 #
#############################

export SINGULARITY_2_VERSION="2.6.1"
export SINGULARITY_2_DIR="${HEAD}/source/Singularity/${SINGULARITY_2_VERSION}"
export SINGULARITY_2_PREFIX="${HEAD}/${OS}/${OS_VERSION}/Common/software/Singularity/${SINGULARITY_2_VERSION}"
mkdir -p ${SINGULARITY_2_DIR}
cd ${SINGULARITY_2_DIR}
wget https://github.com/sylabs/singularity/releases/download/${SINGULARITY_2_VERSION}/singularity-${SINGULARITY_2_VERSION}.tar.gz
tar -zxvf singularity-${SINGULARITY_2_VERSION}.tar.gz
cd singularity-${SINGULARITY_2_VERSION}
./configure --prefix=${SINGULARITY_2_PREFIX} && make && make install

chown -R ${EASYBUILD_USER}. ${HEAD}

mkdir -p ${HEAD}/${OS}/${OS_VERSION}/Haswell/modules/all/Singularity

# Crearte modulefile

cat <<EOF >> ${HEAD}/${OS}/${OS_VERSION}/Haswell/modules/all/Singularity/2.6.1.lua
help([==[

Description
===========
Singularity is a portable application stack packaging and runtime utility.


More information
================
 - Homepage: http://gmkurtzer.github.io/singularity
]==])

whatis([==[Description: Singularity is a portable application stack packaging and runtime utility.]==])
whatis([==[Homepage: http://gmkurtzer.github.io/singularity]==])

local root = "${SINGULARITY_2_PREFIX}"

conflict("Singularity")

prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("PATH", pathJoin(root, "bin"))
EOF

#########################
# Singularity 3 install #
#########################

# Modify the easyconfig and the modulefile of Go 1.8.1 shipped with EasyBuild 3.8.1
# so it works with version 1.11.5. 
sed -i -e 's/bin\/go/go\/bin\/go/g' -e "s/'api', 'doc', 'lib', 'pkg'/'go\/api', 'go\/doc', 'go\/lib', 'go\/pkg'/g" ${HEAD}/${OS}/${OS_VERSION}/Common/software/EasyBuild/3.8.1/software/EasyBuild/3.8.1/lib/python2.7/site-packages/easybuild_easyconfigs-3.8.1-py2.7.egg/easybuild/easyconfigs/g/Go/Go-1.8.1.eb

# Install Go 1.11.5
su - ${EASYBUILD_USER} -c "source /etc/profile.d/easybuild.sh; source /etc/profile.d/lmod.sh; module load EasyBuild/3.8.1; eb --try-software-version=1.11.5 Go-1.8.1.eb; sed -i 's/Go\/1.11.5/Go\/1.11.5\/go/g' ${HEAD}/${OS}/${OS_VERSION}/Haswell/modules/all/Go/1.11.5.lua; sed -i '27i prepend_path(\"PATH\", \"/scratch/scicomp/EasyBuild/CentOS/7.5.1810/Haswell/software/Go/1.11.5/go/bin\")' ${HEAD}/${OS}/${OS_VERSION}/Haswell/modules/all/Go/1.11.5.lua"
module load Go

export SINGULARITY_VERSION="master"
export SINGULARITY_PREFIX="${HEAD}/${OS}/${OS_VERSION}/Common/software/Singularity/$SINGULARITY_VERSION"
mkdir -p /root/go
export GOPATH="/root/go"
cd ${GOPATH}
go get -d github.com/sylabs/singularity
cd src/github.com/sylabs/singularity
git fetch
git checkout ${SINGULARITY_VERSION}

./mconfig --prefix=${SINGULARITY_PREFIX}
make -C ./builddir
make -C ./builddir install
chmod 755 ${HEAD}/${OS}/${OS_VERSION}/Common/software/Singularity/${SINGULARITY_VERSION}/etc/singularity/*

# Create modulefile

cat <<EOF >> ${HEAD}/${OS}/${OS_VERSION}/Haswell/modules/all/Singularity/latest.lua
help([==[

Description
===========
Singularity is a portable application stack packaging and runtime utility.


More information
================
 - Homepage: http://gmkurtzer.github.io/singularity
]==])

whatis([==[Description: Singularity is a portable application stack packaging and runtime utility.]==])
whatis([==[Homepage: http://gmkurtzer.github.io/singularity]==])

local root = "${SINGULARITY_PREFIX}"

conflict("Singularity")

prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("PATH", pathJoin(root, "bin"))
EOF

chown -R root. ${HEAD}/${OS}/${OS_VERSION}/Common/software/Singularity
