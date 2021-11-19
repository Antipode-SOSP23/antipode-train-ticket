from locust import HttpUser, task
import os
from pathlib import Path
from pprint import pprint as pp
import yaml

WORKER_ID = os.environ['WORKER_ID']
#
AUTH_SERVICE_URL = os.environ['AUTH_SERVICE_URL']
CANCEL_SERVICE_URL = os.environ['CANCEL_SERVICE_URL']
INSIDE_PAYMENT_SERVICE_URL = os.environ['INSIDE_PAYMENT_SERVICE_URL']
#
USERNAME = os.environ['USERNAME']
PASSWORD = os.environ['PASSWORD']


def _load_yaml(path):
  with open(path, 'r') as f:
    return yaml.safe_load(f) or {}


class TrainTicket(HttpUser):
  auth_token = None
  user_id = None
  order_ids = []

  def on_start(self):
    # login
    url = f"{AUTH_SERVICE_URL}/api/v1/users/login"
    params = { "username": USERNAME, "password": PASSWORD, "verificationCode": "" }
    r = self.client.post(url, json=params)
    self.user_id = r.json()['data']['userId']
    self.auth_token = r.json()['data']['token']

    # load file with orders
    self.order_ids = _load_yaml(f"order-ids-{WORKER_ID}.yml")['order_ids']

  @task
  def cancel_order(self):
    # build header file
    headers = { 'Authorization': 'Bearer ' + self.auth_token }
    # remove first one always
    order_id = self.order_ids.pop(0)
    # cancel order
    self.client.get(f"{CANCEL_SERVICE_URL}/api/v1/cancelservice/cancel/{order_id}/{self.user_id}", headers=headers)
    # then fetch the money to check if any inconsistency between drawbacks and cancelling the order
    r = self.client.get(f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment/money", headers=headers)
    # 1 - True (consistent) ; 0 - False (inconsistent)
    consistent = int(len([e for e in r.json()['data'] if e['orderId'] == order_id ]) != 0)

    return r