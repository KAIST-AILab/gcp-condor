source load_parse_yaml.sh
eval $(parse_yaml config.yaml)

gcloud compute ssh condor-master --zone $ZONE
