import json

def lambda_handler(event, context):
    print("S3 event received")

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        print(f"File uploaded: {key}")
        print(f"Bucket: {bucket}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "S3 file processed successfully"
        })
    }