source load_parse_yaml.sh
eval $(parse_yaml config.yaml)

if [ $# -eq 0 ]; then
    echo "No arguments supplied."
    echo "ex1) ./3_ssh_condor_compute.sh 0"
    echo "ex2) ./3_ssh_condor_compute.sh 1"
    exit
fi

echo "instance list..."
INSTANCES=`gcloud compute instances list --filter="name~condor-compute AND status:RUNNING" --format='get(name)'`
echo "=========================="
echo "$INSTANCES"
echo "=========================="
INSTANCE_ID=$(expr $1 + 1)
INSTANCE_NAME=`echo "$INSTANCES" | sed -n "$INSTANCE_ID p"`

if [ "$INSTANCE_NAME" == "" ]; then
    echo "cannot find $1-th instance"
    exit
fi
echo $INSTANCE_NAME
gcloud compute ssh $INSTANCE_NAME --zone $ZONE
