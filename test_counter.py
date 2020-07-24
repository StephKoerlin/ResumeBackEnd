import boto3
from moto import mock_dynamodb2
from counterfunction import counter_function as cf


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

    new_count = cf.update_visitors(table)
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
    cf.decrement_visitors(table)

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


#-----testing in mock environment-----

# testing against mock environment with local script
# def mock_environment():
#     mock = mock_dynamodb2()
#     mock.start()
#
#     #create mock table and add in first item
#     botoC = boto3.client('dynamodb', region_name='us-east-1')
#     botoC.create_table(
#         TableName='MockTable',
#         KeySchema=[
#             {
#             'AttributeName': 'Site',
#             'KeyType': 'HASH'
#             }
#         ],
#         AttributeDefinitions=[
#             {
#             'AttributeName': 'Site',
#             'AttributeType': 'S'
#             }
#         ],
#         BillingMode='PAY_PER_REQUEST'
#     )
#     botoC.put_item(
#         TableName='MockTable',
#         Item={
#             "Site": {"S": "Resume"},
#             "Visitors": {"N": "0"}
#         }
#     )
#
#     mock_count = botoC.get_item(
#         TableName='MockTable',
#         Key= {
#             "Site": {"S": "Resume"}
#         }
#     )
#     print(mock_count['Item']['Visitors'])
#
#     botoR = boto3.resource('dynamodb')
#     table = botoR.Table('MockTable')
#     print('Running increase function')
#     cf.update_visitors(table)
#
#     newMockItem = botoC.get_item(
#         TableName='MockTable',
#         Key= {
#             "Site": {"S": "Resume"}
#         }
#     )
#     print(newMockItem['Item']['Visitors'])
#
#     mock.stop()
#
# mock_environment()

if __name__ == "__main__":
    print('this is only a test, please execute with pytest')
