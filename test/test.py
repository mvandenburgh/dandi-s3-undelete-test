from uuid import uuid4

import boto3
import pytest
from botocore.exceptions import ClientError

BUCKET_NAME = "dandi-s3-experiment-bucket"


def test_deletion() -> None:
    client = boto3.client("s3")

    key = str(uuid4())
    body = b"Hello world"

    # Create object
    resp = client.put_object(Bucket=BUCKET_NAME, Key=key, Body=body)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200

    # Get object and ensure it's correct
    resp = client.get_object(Bucket=BUCKET_NAME, Key=key)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200
    assert resp["Body"].read() == body

    # Delete the object. This should create a delete marker.
    resp = client.delete_object(Bucket=BUCKET_NAME, Key=key)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 204

    # Get the object versions.
    # A version should still exist due to versioning being enabled
    resp = client.list_object_versions(Bucket=BUCKET_NAME, Prefix=key)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200

    # Only one version should exist
    versions = resp["Versions"]
    assert len(versions) == 1

    # Ensure that we can't delete this version due to the bucket policy
    # denying everyone from the `s3:DeleteObjectVersion` action.
    with pytest.raises(ClientError) as e:
        client.delete_object(
            Bucket=BUCKET_NAME, Key=key, VersionId=versions[0]["VersionId"]
        )

    assert e.value.response["Error"] == {
        "Code": "AccessDenied",
        "Message": "Access Denied",
    }
    assert e.value.response["ResponseMetadata"]["HTTPStatusCode"] == 403

    # Upload the exact same object again. This should create a new version of the
    # object *without* a delete marker.
    resp = client.put_object(Bucket=BUCKET_NAME, Key=key, Body=body)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200

    # Now there should be two versions of the object - the old one with the delete marker
    # on it, and the newly uploaded one without a delete marker.
    resp = client.list_object_versions(Bucket=BUCKET_NAME, Prefix=key)
    assert resp["ResponseMetadata"]["HTTPStatusCode"] == 200
    versions = resp["Versions"]
    assert len(versions) == 2
    delete_markers = resp["DeleteMarkers"]
    assert len(delete_markers) == 1
