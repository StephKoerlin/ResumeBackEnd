import boto3


def lambda_handler(event, context):
    client = boto3.resource('dynamodb')
    table = client.Table('VisitorTable')

    postCall = update_visitors(table)
    return(postCall)


def update_visitors(table):
    updateResponse = table.update_item(
        Key={
            'Site': 'Resume'
        },
        UpdateExpression='SET Visitors = Visitors + :val1',
        ExpressionAttributeValues={
            ':val1': 1
        },
        ReturnValues='UPDATED_NEW'
    )

    return updateResponse
