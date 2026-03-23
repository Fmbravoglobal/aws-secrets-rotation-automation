"""
Unit tests for AWS Secrets Manager Rotation Automation.
"""

import sys
import os
import json
import unittest
from unittest.mock import MagicMock, patch

sys.modules["boto3"] = MagicMock()
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.main import generate_secure_password, lambda_handler
import app.main as main_module


class TestGenerateSecurePassword(unittest.TestCase):

    def test_password_correct_length(self):
        pwd = generate_secure_password(32)
        self.assertEqual(len(pwd), 32)

    def test_password_has_lowercase(self):
        pwd = generate_secure_password(32)
        self.assertTrue(any(c.islower() for c in pwd))

    def test_password_has_uppercase(self):
        pwd = generate_secure_password(32)
        self.assertTrue(any(c.isupper() for c in pwd))

    def test_password_has_digit(self):
        pwd = generate_secure_password(32)
        self.assertTrue(any(c.isdigit() for c in pwd))

    def test_password_has_special_char(self):
        pwd = generate_secure_password(32)
        self.assertTrue(any(c in "!@#$%^&*" for c in pwd))

    def test_passwords_are_unique(self):
        passwords = {generate_secure_password(32) for _ in range(50)}
        self.assertEqual(len(passwords), 50)

    def test_custom_length(self):
        pwd = generate_secure_password(64)
        self.assertEqual(len(pwd), 64)


class TestLambdaHandler(unittest.TestCase):

    def setUp(self):
        main_module.ROTATION_ENABLED = True
        main_module.SNS_TOPIC_ARN = ""
        main_module.secrets_client = MagicMock()
        main_module.sns_client = MagicMock()

        main_module.secrets_client.get_secret_value.return_value = {
            "SecretString": json.dumps({"username": "admin", "password": "old-pass"})
        }
        main_module.secrets_client.put_secret_value.return_value = {"VersionId": "v2"}
        main_module.secrets_client.describe_secret.return_value = {
            "VersionIdsToStages": {"v1": ["AWSCURRENT"]}
        }

    def test_rotation_disabled_returns_200(self):
        main_module.ROTATION_ENABLED = False
        result = lambda_handler({"SecretId": "arn:test", "Step": "createSecret"}, {})
        self.assertEqual(result["statusCode"], 200)

    def test_set_secret_step(self):
        result = lambda_handler({"SecretId": "arn:test", "Step": "setSecret"}, {})
        self.assertEqual(result["statusCode"], 200)

    def test_test_secret_step(self):
        result = lambda_handler({"SecretId": "arn:test", "Step": "testSecret"}, {})
        self.assertEqual(result["statusCode"], 200)

    def test_finish_secret_step(self):
        result = lambda_handler({"SecretId": "arn:test", "Step": "finishSecret"}, {})
        self.assertEqual(result["statusCode"], 200)

    def test_unknown_step_returns_200(self):
        result = lambda_handler({"SecretId": "arn:test", "Step": "unknownStep"}, {})
        self.assertEqual(result["statusCode"], 200)

    def test_api_key_rotation(self):
        result = lambda_handler({
            "SecretId": "arn:test",
            "Step": "createSecret",
            "SecretType": "api_key"
        }, {})
        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertEqual(body["secret_type"], "api_key")


if __name__ == "__main__":
    unittest.main()
