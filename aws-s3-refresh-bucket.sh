#!/bin/bash

# Usage: ./sync_to_s3.sh <bucket_name> <folder_name> <matching_files>

# Validate the number of arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <bucket_name> <folder_name> <matching_files>"
    exit 1
fi

# Extract arguments
BUCKET_NAME="$1"
FOLDER_NAME="$2"
MATCHING_FILES="$3"

# Remove files from the specified bucket recursively
aws s3 rm "s3://$BUCKET_NAME" --recursive

# Sync local files to the specified bucket
aws s3 sync . "s3://$BUCKET_NAME"

# Remove specific folders from the bucket
aws s3 rm "s3://$BUCKET_NAME/$FOLDER_NAME" --recursive --exclude "*" --include="$MATCHING_FILES"
