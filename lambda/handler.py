import os, json, boto3, urllib.parse, datetime

rek = boto3.client("rekognition")
ddb = boto3.client("dynamodb")

TABLE = os.environ["TABLE_NAME"]

def main(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        resp = rek.detect_labels(
            Image={"S3Object": {"Bucket": bucket, "Name": key}},
            MaxLabels=15,
            MinConfidence=60.0
        )

        labels = [
            {"M": {"name": {"S": l["Name"]}, "confidence": {"N": f'{l["Confidence"]:.2f}'}}}
            for l in resp.get("Labels", [])
        ]

        ddb.put_item(
            TableName=TABLE,
            Item={
                "image_key": {"S": key},
                "labels":    {"L": labels},
                "processed_at": {"S": datetime.datetime.utcnow().isoformat() + "Z"}
            }
        )

    return {"status": "ok"}
