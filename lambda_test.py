import unittest
import boto3
from moto import mock_dynamodb2



@mock_dynamodb2
class TestTableExists(unittest.TestCase):
    def setUp(self):
        """Create the mock database and table"""
        self.dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

        self.table = (self.dynamodb)

    # def tearDown(self):
    #     """Delete mock database and table after test is run"""
    #     self.table.delete()
    #     self.dynamodb=None

    def test_visor_increase(self):
        from lambda_function import update_visitors
        result = update_visitors(self.table)
        self.assertEqual(200, result['ResponseMetadata']['HTTPStatusCode'])

    # def test_table_exists(self):
    #     self.assertTrue(self.table) # check if we got a result
    #     self.assertIn('VisitorTable', self.table.name) # check if the table name is 'Movies'
    #     print(self.table.name)

    # def test_put_movie(self):
    #     from MoviesPutItem import put_movie
    #
    #     result = put_movie("The Big New Movie", 2015,
    #                        "Nothing happens at all.", 0, self.dynamodb)
    #
    #     self.assertEqual(200, result['ResponseMetadata']['HTTPStatusCode'])
    #
    #
    # def test_get_movie(self):
    #     from MoviesPutItem import put_movie
    #     from MoviesGetItem import get_movie
    #
    #     put_movie("The Big New Movie", 2015,
    #               "Nothing happens at all.", 0, self.dynamodb)
    #     result = get_movie("The Big New Movie", 2015, self.dynamodb)
    #
    #     self.assertEqual(2015, result['year'])
    #     self.assertEqual("The Big New Movie", result['title'])
    #     self.assertEqual("Nothing happens at all.", result['info']['plot'])
    #     self.assertEqual(0, result['info']['rating'])


if __name__ == '__main__':
    unittest.main()
    print("Everything Passes")