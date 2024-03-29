from locust import events
from locust import HttpUser, task
import locust.stats
# from locust_plugins import constant_total_ips
import os
import requests
import yaml
# from pprint import pprint as pp


locust.stats.PERCENTILES_TO_REPORT = [0.25, 0.5, 0.75,  0.9, 0.95,  0.99, 0.999, 0.9999, 1.0]
#
AUTH_SERVICE_URL = os.environ['AUTH_SERVICE_URL']
CANCEL_SERVICE_URL = os.environ['CANCEL_SERVICE_URL']
INSIDE_PAYMENT_SERVICE_URL = os.environ['INSIDE_PAYMENT_SERVICE_URL']
TT_USERNAME = os.environ['TT_USERNAME']
TT_PASSWORD = os.environ['TT_PASSWORD']
DEPLOY_TAG = os.environ['DEPLOY_TAG']
WORKER_ID = os.environ['WORKER_ID']

@events.quitting.add_listener
def _(environment, **kw):
  # for now we always return success since we will then look at the file outputs
  # See more info about using test results to define exit code here:
  # http://docs.locust.io/en/stable/running-without-web-ui.html#controlling-the-exit-code-of-the-locust-process
  environment.process_exit_code = 0

ORDER_IDS = []
if WORKER_ID != 'MASTER':
  # load order_ids yaml
  with open(f"{DEPLOY_TAG}_seed_{WORKER_ID}.yml", 'r') as f:
    ORDER_IDS = (yaml.safe_load(f) or [])
    ORDER_IDS.sort()

class TrainTicket(HttpUser):
  auth_token = None
  user_id = None
  # wait_time = constant_total_ips(RATE)

  def on_start(self):
    global ORDER_IDS

    print(f"[INFO] Number of seeds available: {len(ORDER_IDS)}")
    # login
    auth_url = f"{AUTH_SERVICE_URL}/api/v1/users/login"
    params = { "username": TT_USERNAME, "password": TT_PASSWORD, "verificationCode": "" }
    r = requests.post(auth_url, json=params)
    self.user_id = r.json()['data']['userId']
    self.auth_token = r.json()['data']['token']

  @task
  def cancel_order(self):
    global ORDER_IDS

    # build header file
    headers = { 'Authorization': 'Bearer ' + self.auth_token }
    # remove from orders - this is atomic so client threads are not an issue
    order_id = ORDER_IDS.pop()
    # cancel order
    with self.client.get(f"{CANCEL_SERVICE_URL}/api/v1/cancelservice/cancel/{order_id}/{self.user_id}", headers=headers, name=f"/api/v1/cancelservice/cancel/:order_id/:user_id", catch_response=True) as r:
      if r.json()['status'] == 1:
        r.success()
      else:
        r.failure("Cancel failed")
        return
    # then fetch the money to check if any inconsistency between drawbacks and cancelling the order
    with self.client.get(f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment/money/{order_id}", name=f"/api/v1/inside_pay_service/inside_payment/money/:order_id", headers=headers, catch_response=True) as r:
      data = (r.json()['data'] or [])
      consistent = (len([e for e in data if e['orderId'] == order_id and e['type'] == 'D' ]) != 0)
      if consistent:
        r.success()
      else:
        r.failure("Inconsistent result")