import boto3
import os

# S3 details
BUCKET_NAME = "ams-data-platform-ml-data"
PREFIX = "OSRM_Extractions/"
LOCAL_DIR = "osrm-data"

# Get credentials from environment variables
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
REGION_NAME = os.getenv("AWS_REGION", "us-east-1")  # fallback to us-east-1

# Ensure local directory exists
os.makedirs(LOCAL_DIR, exist_ok=True)

# Initialize S3 client
s3_client = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=REGION_NAME
)

def download_files():
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=PREFIX):
        if "Contents" in page:
            for obj in page["Contents"]:
                key = obj["Key"]
                if key.endswith("/"):  # skip directories
                    continue

                # Keep original folder structure inside osrm-data
                local_path = os.path.join(LOCAL_DIR, key.replace(PREFIX, ""))
                os.makedirs(os.path.dirname(local_path), exist_ok=True)

                print(f"Downloading {key} -> {local_path}")
                s3_client.download_file(BUCKET_NAME, key, local_path)

if __name__ == "__main__":
    download_files()
    print("✅ All files downloaded successfully.")
