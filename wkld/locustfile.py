from locust import events
from locust import HttpUser, task
import locust.stats
from locust_plugins import constant_total_ips
import os
from pathlib import Path
import requests
import yaml


locust.stats.PERCENTILES_TO_REPORT = [0.25, 0.5, 0.75,  0.9, 0.95,  0.99, 0.999, 0.9999, 1.0]
#
AUTH_SERVICE_URL = os.environ['AUTH_SERVICE_URL']
CANCEL_SERVICE_URL = os.environ['CANCEL_SERVICE_URL']
INSIDE_PAYMENT_SERVICE_URL = os.environ['INSIDE_PAYMENT_SERVICE_URL']
TT_USERNAME = os.environ['TT_USERNAME']
TT_PASSWORD = os.environ['TT_PASSWORD']
DEPLOY_TAG = os.environ['DEPLOY_TAG']
WORKER_ID = os.environ['WORKER_ID']
RATE = int(os.environ['RATE'])

@events.quitting.add_listener
def _(environment, **kw):
  # for now we always return success since we will then look at the file outputs
  # See more info about using test results to define exit code here:
  # http://docs.locust.io/en/stable/running-without-web-ui.html#controlling-the-exit-code-of-the-locust-process
  environment.process_exit_code = 0

class TrainTicket(HttpUser):
  auth_token = None
  user_id = None
  order_ids = []
  wait_time = constant_total_ips(RATE)

  def on_start(self):
    # load order_ids yaml
    with open(f"{DEPLOY_TAG}_seed_{WORKER_ID}.yml", 'r') as f:
      self.order_ids = (yaml.safe_load(f) or {})

    # login
    auth_url = f"{AUTH_SERVICE_URL}/api/v1/users/login"
    params = { "username": TT_USERNAME, "password": TT_PASSWORD, "verificationCode": "" }
    r = requests.post(auth_url, json=params)
    self.user_id = r.json()['data']['userId']
    self.auth_token = r.json()['data']['token']

  @task
  def cancel_order(self):
    # build header file
    headers = { 'Authorization': 'Bearer ' + self.auth_token }
    # remove from orders - this is atomic so client threads are not an issue
    order_id = self.order_ids.pop()
    # cancel order
    self.client.get(f"{CANCEL_SERVICE_URL}/api/v1/cancelservice/cancel/{order_id}/{self.user_id}", headers=headers, name=f"/api/v1/cancelservice/cancel/:order_id/:user_id")
    # then fetch the money to check if any inconsistency between drawbacks and cancelling the order
    with self.client.get(f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment/money", headers=headers, catch_response=True) as r:
      consistent = len([e for e in r.json()['data'] if e['orderId'] == order_id ]) != 0
      if consistent:
        r.success()
      else:
        r.failure("Inconsistent result")