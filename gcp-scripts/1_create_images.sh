source load_parse_yaml.sh
eval $(parse_yaml config.yaml)

function create_instance(){
    gcloud compute  instances create $1-template \
        --zone=$ZONE \
        --machine-type=n1-standard-1 \
        --image-family ubuntu-1804-lts --image-project ubuntu-os-cloud \
        --boot-disk-size=10GB \
        --scopes compute-ro,storage-full
}

function setup_condor_master(){
gcloud compute ssh condor-master-template --zone $ZONE -- "
sudo apt-get update
sudo apt-get install -y wget curl net-tools vm git
wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | sudo apt-key add -
echo \"deb http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib\" | sudo tee -a /etc/apt/sources.list
echo \"deb-src http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib\" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y libglobus-gss-assist3 htcondor

sudo mkdir -p /etc/condor/config.d/

echo 'CONDOR_HOST = condor-master
BIND_ALL_INTERFACES = False
IN_HIGHPORT = 9999
IN_LOWPORT = 9000
ALLOW_READ = *
ALLOW_WRITE = *
JOB_RENICE_INCREMENT = 0

UID_DOMAIN = \$(CONDOR_HOST)
FILESYSTEM_DOMAIN = \$(CONDOR_HOST)
COLLECTOR_NAME = \$(CONDOR_HOST)

START = TRUE
SUSPEND = FALSE
PREEMPT = FALSE
KILL = FALSE

DAEMON_LIST = COLLECTOR, MASTER, NEGOTIATOR, SCHEDD
TRUST_UID_DOMAIN = TRUE
' > condor_config.local

sudo mv condor_config.local /etc/condor/config.d/
sudo systemctl start condor
sudo systemctl enable condor

echo '==============================='
echo 'condor installed'
echo '==============================='
"
}

function setup_condor_compute(){
gcloud compute ssh condor-compute-template --zone $ZONE -- "
sudo apt-get update
sudo apt-get install -y wget curl net-tools vm git
wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | sudo apt-key add -
echo \"deb http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib\" | sudo tee -a /etc/apt/sources.list
echo \"deb-src http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib\" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y libglobus-gss-assist3 htcondor

sudo mkdir -p /etc/condor/config.d/

echo 'CONDOR_HOST = condor-master
BIND_ALL_INTERFACES = False
IN_HIGHPORT = 9999
IN_LOWPORT = 9000
ALLOW_READ = *
ALLOW_WRITE = *
JOB_RENICE_INCREMENT = 0

UID_DOMAIN = \$(CONDOR_HOST)
FILESYSTEM_DOMAIN = \$(CONDOR_HOST)

SLOT_TYPE_1 = cpus=100%,disk=100%,swap=100%
SLOT_TYPE_1_PARTITIONABLE = TRUE
NUM_SLOTS = 1
NUM_SLOTS_TYPE_1 = 1

CLUSTER = \"node\"
STARTD_ATTRS = \$(STARTD_ATTRS) CLUSTER
COLLECTOR_NAME = \$(CONDOR_HOST)

START = TRUE
SUSPEND = FALSE
PREEMPT = FALSE
KILL = FALSE

DAEMON_LIST = MASTER, SCHEDD, STARTD
TRUST_UID_DOMAIN = TRUE
' > condor_config.local

sudo mv condor_config.local /etc/condor/config.d/
sudo systemctl start condor
sudo systemctl enable condor

echo '==============================='
echo 'condor installed'
echo '==============================='
"
}

function install_custom_packages(){
    # NFS connection
    NFS_IP=`gcloud compute instances describe nfs-instance --zone=$ZONE --format='get(networkInterfaces[0].networkIP)'`
    gcloud compute ssh $1-template --zone $ZONE -- "\
        sudo apt-get install -y nfs-common; \
        sudo mkdir -p /mnt/nfs; \
        sudo mount -t nfs $NFS_IP:/var/nfs-export /mnt/nfs/; \
        sudo chmod o+w /mnt/nfs/; \
        echo \"$NFS_IP:/var/nfs-export /mnt/nfs/ nfs\" | sudo tee -a /etc/fstab; \
    "

    # Insatll miniconda & conda environment from github repository
    gcloud compute ssh $1-template --zone $ZONE -- "
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh;
        bash Miniconda3-latest-Linux-x86_64.sh -b -p \$HOME/miniconda;
        rm Miniconda3-latest-Linux-x86_64.sh;
        eval \"\$(\$HOME/miniconda/bin/conda shell.bash hook)\";
        conda init;

        # for mpi4py
        sudo apt-get install -y libmpich-dev libsm6;  # libopenmpi-dev

        # for mujoco_py
        sudo apt-get install -y zip libosmesa6-dev libgl1-mesa-dev patchelf libglfw3-dev;
        wget https://www.roboti.us/download/mujoco200_linux.zip;
        mkdir -p .mujoco; unzip mujoco200_linux.zip -d .mujoco;
        mv .mujoco/mujoco200_linux .mujoco/mujoco200; rm mujoco200_linux.zip;
        export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$HOME/.mujoco/mujoco200/bin;
        echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$HOME/.mujoco/mujoco200/bin' >> \$HOME/.bashrc;

        # download mjkey.txt to ~/.mujoco/mjkey.txt
        /snap/bin/gsutil cp gs://$STORAGE_BUCKET_NAME/mjkey.txt \$HOME/.mujoco/mjkey.txt

        # conda environment
        git clone https://$GITHUB_USERNAME:$GITHUB_PASSWORD@github.com/$GITHUB_REPOSITORY.git repo;
        cd repo; conda env create -f $GITHUB_REPOSITORY_CONDA_ENVFILE_PATH;
        cd \$HOME; rm repo -rf;
    "
}

function stop_instance(){
    gcloud compute instances stop --zone=$ZONE $1-template
}

function create_image(){
    gcloud compute images create $1 \
	     --source-disk $1-template \
	     --source-disk-zone $ZONE \
	     --family htcondor-ubuntu
}

function delete_instance(){
    gcloud compute instances delete --quiet --zone=$ZONE $1-template
}

function process_all(){
    create_instance $1
    echo 'Sleep for a while... (60 seconds)'
    sleep 60

    if [ "$1" == "condor-master" ]; then
        echo "Setup condor-master..."
        setup_condor_master
    elif [ "$1" == "condor-compute" ]; then
        echo "Setup condor-compute..."
        setup_condor_compute
    else
        echo "Not defined..."
        exit
    fi

    echo 'Install custom packages...'
    install_custom_packages $1

    echo 'Stop instances...'
    stop_instance $1
    echo 'Create images...'
    create_image $1
    echo 'Delete instances...'
    delete_instance $1
    echo "====================================="
    echo "$1 Finished!"
    echo "====================================="
}

process_all condor-master
process_all condor-compute
