import boto3
import lambda_function as lf



#-----testing in AWS environment-----

def current_count():
    """
    current count of visitors in AWS environment

    :return: dict for Visitors
    """
    botoC = boto3.client('dynamodb')
    real_count = botoC.get_item(
        TableName='VisitorTable',
        Key= {
                "Site": {"S": "Resume"}
            }
    )
    print(real_count['Item']['Visitors'])
    return real_count['Item']['Visitors']


def increase_count():
    """
    increase my count by using my local lambda code

    :return: updated count
    """
    botoR = boto3.resource('dynamodb')
    table = botoR.Table('VisitorTable')

    new_count = lf.update_visitors(table)
    print('Running increase function')
    return new_count


def new_count():
    """
    get the new count of visitors after the increase code has been run

    :return: dict for Visitors
    """
    botoC = boto3.client('dynamodb')
    updated_count = botoC.get_item(
        TableName='VisitorTable',
        Key= {
            "Site": {"S": "Resume"}
        }
    )
    return updated_count['Item']['Visitors']


def test_validate_response():
    """
    assert that the new count is one greater than the old count
    then decrease the count using local lambda code
    then assert that the decreased count is equal to the original count

    :return: test results
    """
    mycurrent = current_count()
    increase_count()
    mynewcount = new_count()

    botoC = boto3.client('dynamodb')
    botoR = boto3.resource('dynamodb')
    table = botoR.Table('VisitorTable')
    lf.decrement_visitors(table)

    reverseMockItem = botoC.get_item(
        TableName='VisitorTable',
        Key= {
            "Site": {"S": "Resume"}
        }
    )
    myreverse = reverseMockItem['Item']['Visitors']

    assert trim_dict(mynewcount)-1 == trim_dict(mycurrent)
    assert trim_dict(myreverse) == trim_dict(mycurrent)


def trim_dict(mydict: dict) -> int:
    for key, value in mydict.items():
        return int(value)


if __name__ == "__main__":
    print('this is only a test, please execute with pytest')
