source load_parse_yaml.sh
eval $(parse_yaml config.yaml)

echo 'Update default-allow-internal firewall rule (source-ranges=0.0.0.0/0) ...'
gcloud compute firewall-rules update default-allow-internal --source-ranges=0.0.0.0/0 --rules=all

gcloud compute  instances create nfs-instance \
    --zone=$ZONE \
    --machine-type=g1-small \
    --image-family ubuntu-1804-lts --image-project ubuntu-os-cloud \
    --boot-disk-size=30GB \
    --deletion-protection \
    --metadata-from-file startup-script=startup-scripts/nfs.sh \
    --scopes compute-ro,default

# Create storage bucket (e.g. to store mjkey.txt)
echo "==========================================="
gsutil mb gs://$STORAGE_BUCKET_NAME
echo "Please update 'mjkey.txt' to the created bucket ($STORAGE_BUCKET_NAME)!"
echo "Link: https://console.cloud.google.com/storage/browser/$STORAGE_BUCKET_NAME?project=$DEVSHELL_PROJECT_ID"
echo "==========================================="

echo "NFS instance creation completed! Sleep 180 seconds..."
sleep 180
