source load_parse_yaml.sh
eval $(parse_yaml config.yaml)

gsutil rm -r gs://$STORAGE_BUCKET_NAME
